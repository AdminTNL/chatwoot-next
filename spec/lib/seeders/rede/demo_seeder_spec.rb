require 'rails_helper'

RSpec.describe Seeders::Rede::DemoSeeder do
  let(:account) { create(:account) }
  let(:out) { StringIO.new }

  def seed(reset: false)
    described_class.new(account: account, reset: reset, out: out).perform!
  end

  def project(slug)
    account.rede_projects.find_by!(slug: slug)
  end

  def demo_contacts
    account.contacts.where("additional_attributes->>'seed' = 'rede_demo'")
  end

  def normalized(contact)
    Rede::Phone.variants(Rede::Phone.normalize(contact.phone_number)).max_by(&:length)
  end

  def normalized_numbers(proj)
    proj.participations.includes(:contact).map { |item| normalized(item.contact) }
  end

  describe 'trava de produção' do
    before { allow(Rails.env).to receive(:production?).and_return(true) }

    it 'recusa rodar em produção sem ENABLE_ACCOUNT_SEEDING=true' do
      stub_const('ENV', ENV.to_hash.except('ENABLE_ACCOUNT_SEEDING'))

      expect { seed }.to raise_error(described_class::Refused, /ENABLE_ACCOUNT_SEEDING/)
      expect(account.rede_projects.count).to eq(0)
    end

    it 'recusa com valor diferente de true' do
      stub_const('ENV', ENV.to_hash.merge('ENABLE_ACCOUNT_SEEDING' => 'yes'))

      expect { seed }.to raise_error(described_class::Refused)
      expect(account.rede_projects.count).to eq(0)
    end

    it 'roda em produção quando a trava está ligada' do
      stub_const('ENV', ENV.to_hash.merge('ENABLE_ACCOUNT_SEEDING' => 'true'))

      expect { seed }.not_to raise_error
      expect(account.rede_projects.where('slug LIKE ?', 'mobiliza-demo-%').count).to eq(2)
    end
  end

  describe 'dados criados' do
    before { seed }

    it 'cria dois projetos, as frentes e uma caixa API por time' do
      pe = project('mobiliza-demo-pe')
      pa = project('mobiliza-demo-pa')

      expect(pe.fronts.order(:name).pluck(:name, :has_temperature)).to eq([['Campo', true], ['Digital', true], ['Formação', false]])
      expect(pa.fronts.count).to eq(0)
      [pe, pa].each do |item|
        inboxes = account.inboxes.where(team_id: item.team_id)
        expect(inboxes.count).to eq(1)
        expect(inboxes.first.channel).to be_a(Channel::Api)
      end
    end

    it 'cria os três agentes com os vínculos corretos' do
      pe = project('mobiliza-demo-pe').team
      pa = project('mobiliza-demo-pa').team
      user = ->(email) { User.find_by!(email: email) }

      expect(pe.members).to include(user.call('agente.pe@demo.local'), user.call('agente.ambos@demo.local'))
      expect(pe.members).not_to include(user.call('agente.pa@demo.local'))
      expect(pa.members).to include(user.call('agente.pa@demo.local'), user.call('agente.ambos@demo.local'))
      expect(pa.members).not_to include(user.call('agente.pe@demo.local'))
      expect(account.users).to include(user.call('agente.pe@demo.local'))
      expect(out.string).to include('agente.pe@demo.local').and include('agente.ambos@demo.local')
    end

    it 'cria cerca de 30 contatos fictícios marcados, com telefones +55819 e +55919' do
      expect(demo_contacts.count).to be_between(28, 36)
      phones = demo_contacts.pluck(:phone_number).compact
      expect(phones.grep(/\A\+55819/)).not_to be_empty
      expect(phones.grep(/\A\+55919/)).not_to be_empty
    end

    it 'cria conversas com mensagens recebidas e enviadas nos últimos 60 dias' do
      expect(account.conversations.count).to be >= 10
      dates = account.messages.pluck(:created_at)
      expect(dates.min).to be >= 61.days.ago
      expect(dates.max).to be <= Time.current
      expect(account.messages.incoming.count).to be > 0
      expect(account.messages.outgoing.where(private: false).count).to be > 0
      expect(account.messages.where(private: true).count).to be > 0
    end

    it 'deixa participações com mais de 7 dias sem contato e outras recentes' do
      pe = project('mobiliza-demo-pe')

      expect(pe.participations.where('last_contact_at >= ?', 7.days.ago).count).to be > 0
      expect(pe.participations.where('last_contact_at < ?', 7.days.ago).count).to be > 0
    end

    it 'cria temperaturas com histórico (uma pessoa com três mudanças), atuações, superior e indicação' do
      counts = Rede::Evaluation.where(account: account).group(:contact_id, :project_id, :front_id).count.values
      expect(counts.max).to be >= 3
      expect(Rede::Assignment.where(account: account).where.not(superior_contact_id: nil)).to exist
      expect(Rede::Participation.where(account: account).where.not(referred_by_contact_id: nil)).to exist
    end

    it 'cria ligações atendidas, não atendidas e notas' do
      scope = Rede::Interaction.where(account: account)

      expect(scope.call.where(answered: true)).to exist
      expect(scope.call.where(answered: false)).to exist
      expect(scope.note).to exist
    end

    it 'cobre os casos-chave de pessoas' do
      pe = project('mobiliza-demo-pe')
      pa = project('mobiliza-demo-pa')
      people = pe.participations.includes(:assignments).to_a
      formacao = pe.fronts.find_by!(name: 'Formação')

      two_fronts = people.select { |item| item.assignments.active.where.not(front_id: nil).count == 2 }
      expect(two_fronts.map(&:contact_id) & pa.participations.pluck(:contact_id)).not_to be_empty
      expect(people.select { |item| item.assignments.active.empty? }).not_to be_empty
      expect(people.select { |item| item.assignments.active.pluck(:front_id) == [formacao.id] }).not_to be_empty
      expect(demo_contacts.count { |item| item.additional_attributes['city'].blank? }).to be >= 2
      expect(demo_contacts.where(name: '')).to exist
    end

    it 'cria um duplicado no mesmo projeto e um par com o mesmo número entre projetos que não é duplicado' do
      pe = project('mobiliza-demo-pe')
      pa = project('mobiliza-demo-pa')

      expect(Rede::Quality::Duplicates.new(project: pe).perform.size).to eq(1)
      expect(Rede::Quality::Duplicates.new(project: pa).perform).to be_empty
      expect(normalized_numbers(pe) & normalized_numbers(pa)).not_to be_empty
    end

    it 'a temperatura da Ana no Campo tem ao menos 3 mudanças reais' do
      ana = demo_contacts.find_by!(name: 'Ana Beatriz Moura')
      campo = project('mobiliza-demo-pe').fronts.find_by!(name: 'Campo')
      levels = Rede::Evaluation.where(contact: ana, front: campo).order(:evaluated_at).pluck(:level)

      expect(levels.size).to be >= 3
      expect(levels.each_cons(2).map { |a, b| a != b }).to all(be(true))
    end

    it 'a nota privada recente não conta como contato' do
      note = account.messages.where(private: true).order(created_at: :desc).first
      conversation = note.conversation
      last_incoming = account.messages.incoming.where(private: false, conversation: conversation).maximum(:created_at)
      proj = Rede::Project.find_by!(team_id: conversation.team_id)

      expect(note.created_at).to be > 2.days.ago
      expect(last_incoming).to be < note.created_at
      expect(Rede::Participation.find_by!(contact: conversation.contact, project: proj).last_contact_at).to be_within(1.second).of(last_incoming)
    end
  end

  describe 'idempotência e RESET' do
    it 'recusa rodar de novo sem RESET, sem duplicar' do
      seed
      contacts = demo_contacts.count
      projects = account.rede_projects.count

      expect { seed }.to raise_error(described_class::Refused, /RESET=true/)
      expect(demo_contacts.count).to eq(contacts)
      expect(account.rede_projects.count).to eq(projects)
    end

    it 'RESET apaga só os dados marcados e recria' do
      other_team = create(:team, account: account, name: 'Time Real')
      real = create(:contact, account: account, name: 'Pessoa Real', phone_number: '+5511999990000')
      Rede::Participations::Create.new(account: account, project: other_team.rede_project, params: { contact_id: real.id }).perform
      seed
      before_ids = demo_contacts.ids

      seed(reset: true)

      expect(Contact.where(id: before_ids)).to be_empty
      expect(demo_contacts.count).to be_between(28, 36)
      expect(Contact.exists?(real.id)).to be(true)
      expect(Rede::Project.exists?(other_team.rede_project.id)).to be(true)
      expect(Rede::Participation.where(contact: real).count).to eq(1)
      expect(account.rede_projects.where('slug LIKE ?', 'mobiliza-demo-%').count).to eq(2)
    end

    it 'RESET preserva time real parecido e conversa de contato real numa caixa demo' do
      seed
      real_team = create(:team, account: account, name: 'Mobiliza Demo Recife')
      real = create(:contact, account: account, name: 'Pessoa Real', phone_number: '+5511999990001')
      inbox = account.inboxes.find_by!(name: 'Mobiliza Demo PE API')
      conversation = create(:conversation, account: account, inbox: inbox, contact: real,
                                           contact_inbox: create(:contact_inbox, contact: real, inbox: inbox))

      seed(reset: true)

      expect(Team.exists?(real_team.id)).to be(true)
      expect(Rede::Project.exists?(real_team.rede_project.id)).to be(true)
      expect(Conversation.exists?(conversation.id)).to be(true)
      expect(account.rede_projects.where(slug: %w[mobiliza-demo-pe mobiliza-demo-pa]).count).to eq(2)
    end

    it 'recusa, sem sugerir RESET, projeto demo sem sinal do seeder (nem com RESET apaga)' do
      team = create(:team, account: account, name: 'mobiliza demo pe')

      expect { seed }.to raise_error(described_class::Refused) { |error| expect(error.message).not_to include('RESET') }
      expect { seed(reset: true) }.to raise_error(described_class::Refused)
      expect(Team.exists?(team.id)).to be(true)
    end

    it 'reaproveita agentes que já existem em outra conta' do
      user = create(:user, email: 'agente.pe@demo.local', account: create(:account))

      expect { seed }.to change(User, :count).by(2)
      expect(account.users).to include(user)
    end

    it 'recusa com mensagem clara quando já existe um time com o nome do demo' do
      create(:team, account: account, name: 'mobiliza demo pe')
      account.rede_projects.update_all(slug: 'outro') # rubocop:disable Rails/SkipsModelValidations

      expect { seed }.to raise_error(described_class::Refused, /mobiliza demo pe/)
    end
  end

  it 'é determinístico no formato dos dados entre duas execuções' do
    shape = lambda do
      [demo_contacts.count, account.conversations.count, account.messages.count,
       Rede::Evaluation.where(account: account).count, Rede::Interaction.where(account: account).count]
    end
    seed
    first = shape.call
    seed(reset: true)

    expect(shape.call).to eq(first)
  end
end
