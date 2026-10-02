require 'rails_helper'

RSpec.describe Ops::TemperaturaBackfill do
  let(:account) { create(:account) }
  let(:other_inbox) { create(:inbox, account: account, team: other_team) }
  let(:contact) { create(:contact, account: account, phone_number: '+5587996052123') }
  let(:rows) { [{ 'remote_jid' => '5587996052123', 'temperatura' => 'quente', 'nome' => 'Fulana' }] }
  let(:backfill) { described_class.new(rows: rows, team_id: team.id) }
  let(:team) { create(:team, account: account, name: 'chega junto') }
  let(:other_team) { create(:team, account: account) }
  let(:label_group) { create(:label_group, account: account, team: team) }
  let(:inbox) { create(:inbox, account: account, team: team) }

  before do
    create(:label, account: account, team: team, label_group: label_group, title: 'chega-junto-quente')
    create(:label, account: account, team: team, label_group: label_group, title: 'chega-junto-vapor')
  end

  describe '#report' do
    it 'casa remote_jid de 13 dígitos com contato salvo com nono dígito' do
      contact
      report = backfill.report

      expect(report).to include(found: 1, to_change: 1, not_found: 0)
      expect(report[:plan]).to eq([{ contact_id: contact.id, label: 'chega-junto-quente' }])
    end

    it 'casa remote_jid de 12 dígitos com contato salvo com nono dígito' do
      contact
      rows.first['remote_jid'] = '558796052123'

      expect(backfill.report).to include(found: 1, to_change: 1)
    end

    it 'casa contato salvo sem nono dígito a partir de remote_jid com nono dígito' do
      contact.update!(phone_number: '+558796052123')

      expect(backfill.report).to include(found: 1, to_change: 1)
    end

    it 'limpa o sufixo @s.whatsapp.net antes da busca' do
      contact
      rows.first['remote_jid'] = '5587996052123@s.whatsapp.net'

      expect(backfill.report).to include(found: 1)
    end

    it 'ignora e contabiliza linha sem remote_jid' do
      rows.first['remote_jid'] = ''

      expect(backfill.report).to include(ignored_sem_remote_jid: 1, found: 0, not_found: 0)
    end

    it 'ignora e contabiliza temperatura vazia' do
      contact
      rows.first['temperatura'] = ''

      expect(backfill.report).to include(ignored_sem_temperatura: 1, to_change: 0)
    end

    it 'ignora temperatura sem etiqueta no time, sem criar etiqueta' do
      contact
      rows.first['temperatura'] = 'gelado'

      expect { backfill.report }.not_to change(Label, :count)
      expect(backfill.report).to include(ignored_etiqueta_inexistente: 1, to_change: 0)
    end

    it 'contabiliza telefone inexistente como não encontrado' do
      expect(backfill.report).to include(not_found: 1, found: 0, to_change: 0)
    end

    it 'contabiliza como ambíguo e não aplica quando as variantes casam com dois contatos' do
      contact
      create(:contact, account: account, phone_number: '+558796052123')

      expect(backfill.report).to include(ambiguous: 1, found: 0, to_change: 0)
    end

    it 'contabiliza contato que já tem a etiqueta como já correto' do
      contact.update!(label_list: ['chega-junto-quente'])

      expect(backfill.report).to include(already_correct: 1, to_change: 0)
    end

    it 'conta conversas do time afetadas e a contagem por temperatura' do
      create(:conversation, account: account, inbox: inbox, contact: contact)
      create(:conversation, account: account, inbox: other_inbox, contact: contact)

      expect(backfill.report).to include(conversations_affected: 1, by_temperatura: { 'quente' => 1 })
    end

    it 'não altera nenhuma etiqueta' do
      conversation = create(:conversation, account: account, inbox: inbox, contact: contact)
      backfill.report

      expect(contact.reload.label_list).to eq([])
      expect(conversation.reload.label_list).to eq([])
    end
  end

  describe '#apply' do
    let(:report) { backfill.report }

    it 'deixa só a etiqueta nova no contato (exclusividade de grupo)' do
      contact.update!(label_list: ['chega-junto-vapor'])
      report
      backfill.apply(report[:plan])

      expect(contact.reload.label_list).to contain_exactly('chega-junto-quente')
    end

    it 'mantém etiqueta de outro time intacta' do
      other_label = create(:label, account: account, team: other_team, title: 'outro-time-x')
      contact.update!(label_list: [other_label.title])
      report
      backfill.apply(report[:plan])

      expect(contact.reload.label_list).to contain_exactly(other_label.title, 'chega-junto-quente')
    end

    it 'propaga só para conversas do time e não gera mensagem de atividade' do
      conversation = create(:conversation, account: account, inbox: inbox, contact: contact)
      other_conversation = create(:conversation, account: account, inbox: other_inbox, contact: contact)
      report

      expect { backfill.apply(report[:plan]) }.not_to change(Message, :count)
      expect(conversation.reload.label_list).to contain_exactly('chega-junto-quente')
      expect(other_conversation.reload.label_list).to eq([])
    end

    it 'retorna os totais de contatos e conversas alterados' do
      create(:conversation, account: account, inbox: inbox, contact: contact)
      report

      expect(backfill.apply(report[:plan])).to eq(contacts: 1, conversations: 1)
    end

    it 'reporta zero alterações na segunda execução' do
      contact
      report
      backfill.apply(report[:plan])

      second = described_class.new(rows: rows, team_id: team.id).report
      expect(second).to include(to_change: 0, already_correct: 1)
    end
  end

  describe '.rollback' do
    it 'restaura o estado anterior do contato e das conversas do backup' do
      contact.update!(label_list: ['chega-junto-vapor'])
      conversation = create(:conversation, account: account, inbox: inbox, contact: contact)
      conversation.update!(label_list: ['chega-junto-vapor'])
      plan = backfill.report[:plan]
      backup = JSON.parse(JSON.generate(backfill.backup_data(plan)))

      backfill.apply(plan)
      expect(contact.reload.label_list).to contain_exactly('chega-junto-quente')

      expect(described_class.rollback(backup)).to eq(contacts: 1, conversations: 1)
      expect(contact.reload.label_list).to contain_exactly('chega-junto-vapor')
      expect(conversation.reload.label_list).to contain_exactly('chega-junto-vapor')
    end
  end

  describe '.from_csv' do
    it 'lê o CSV ignorando colunas extras' do
      contact
      file = Tempfile.new(['temperatura', '.csv'])
      file.write("id,remote_jid,temperatura,nome,extra\n1,5587996052123,quente,Fulana,x\n")
      file.close

      expect(described_class.from_csv(file.path, team_id: team.id).report).to include(total: 1, found: 1)
    ensure
      file.unlink
    end
  end
end
