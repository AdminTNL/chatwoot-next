require 'csv'

# Lógica do backfill das etiquetas de temperatura do Chega Junto (spec 029).
# Sem I/O interativo: devolve dados; quem imprime e pede confirmação é o .rake.
class Ops::TemperaturaBackfill
  TEAM_ID = 1
  BRAZIL_DDI = '55'.freeze

  attr_reader :team_id

  def self.from_csv(path, **)
    rows = CSV.read(path, headers: true, encoding: 'bom|utf-8').map(&:to_h)
    new(rows: rows, **)
  end

  def self.rollback(backup)
    contacts = 0
    conversations = 0

    backup.each do |entry|
      contact = Contact.find_by(id: entry['contact_id'])
      next if contact.blank?

      restore(contact, entry['contact_labels_before'])
      contacts += 1

      entry['conversations'].each do |conversation_entry|
        conversation = Conversation.find_by(id: conversation_entry['id'])
        next if conversation.blank?

        restore(conversation, conversation_entry['labels_before'])
        conversations += 1
      end
    end

    { contacts: contacts, conversations: conversations }
  end

  def self.restore(record, labels_before)
    current = record.reload.label_list
    Labels::TaggingWriter.new(account: record.account)
                         .apply(record: record, added_labels: labels_before - current, removed_labels: current - labels_before)
  end

  def initialize(rows:, team_id: TEAM_ID)
    @rows = rows
    @team_id = team_id
    @team_label_titles = Label.where(team_id: team_id).pluck(:title)
  end

  def report
    stats = { total: @rows.size, ignored_sem_remote_jid: 0, ignored_sem_temperatura: 0, ignored_etiqueta_inexistente: 0,
              found: 0, not_found: 0, ambiguous: 0, already_correct: 0, by_temperatura: Hash.new(0) }
    plan = {}

    @rows.each { |row| classify(row, stats, plan) }

    plan = plan.values
    stats.merge(
      by_temperatura: stats[:by_temperatura].to_h,
      to_change: plan.size,
      conversations_affected: plan.sum { |entry| team_conversations(entry[:contact_id]).count },
      plan: plan
    )
  end

  def self.report_lines(report)
    [
      "Linhas lidas: #{report[:total]}",
      "Ignoradas sem remote_jid: #{report[:ignored_sem_remote_jid]}",
      "Ignoradas sem temperatura: #{report[:ignored_sem_temperatura]}",
      "Ignoradas por etiqueta inexistente no time: #{report[:ignored_etiqueta_inexistente]}",
      "Contatos encontrados: #{report[:found]}",
      "Contatos não encontrados: #{report[:not_found]}",
      "Casamentos ambíguos (não aplicados): #{report[:ambiguous]}",
      "Contatos que já têm a etiqueta correta: #{report[:already_correct]}",
      "Contatos a alterar: #{report[:to_change]}",
      "Conversas do time afetadas: #{report[:conversations_affected]}",
      "Por temperatura: #{report[:by_temperatura].map { |temperatura, count| "#{temperatura}=#{count}" }.join(', ')}"
    ]
  end

  def backup_data(plan)
    plan.map do |entry|
      contact = Contact.find(entry[:contact_id])
      {
        contact_id: contact.id,
        label: entry[:label],
        contact_labels_before: contact.label_list,
        conversations: team_conversations(contact.id).map { |conversation| { id: conversation.id, labels_before: conversation.label_list } }
      }
    end
  end

  def apply(plan)
    conversations = 0

    plan.each do |entry|
      contact = Contact.find(entry[:contact_id])
      conversations += team_conversations(contact.id).count

      Labels::TaggingWriter.new(account: contact.account).apply(record: contact, added_labels: [entry[:label]], removed_labels: [])
      Labels::ContactPropagationService.new(contact_id: contact.id, team_id: team_id, added_labels: [entry[:label]], removed_labels: []).perform
    end

    { contacts: plan.size, conversations: conversations }
  end

  private

  def classify(row, stats, plan)
    jid = row['remote_jid'].to_s.strip
    temperatura = row['temperatura'].to_s.strip.downcase
    return stats[:ignored_sem_remote_jid] += 1 if jid.empty?
    return stats[:ignored_sem_temperatura] += 1 if temperatura.empty?

    label = "chega-junto-#{temperatura}"
    return stats[:ignored_etiqueta_inexistente] += 1 unless @team_label_titles.include?(label)

    stats[:by_temperatura][temperatura] += 1
    classify_contact(Contact.where(phone_number: phone_variants(jid)).pluck(:id).uniq, label, stats, plan)
  end

  def classify_contact(contact_ids, label, stats, plan)
    return stats[:not_found] += 1 if contact_ids.empty?
    return stats[:ambiguous] += 1 if contact_ids.size > 1

    stats[:found] += 1
    contact_id = contact_ids.first
    return stats[:already_correct] += 1 if Contact.find(contact_id).label_list.include?(label)

    plan[contact_id] = { contact_id: contact_id, label: label }
  end

  # Com e sem o nono dígito brasileiro, sempre com "+" e DDI 55.
  def phone_variants(jid)
    digits = jid.split('@').first.gsub(/\D/, '')
    return ["+#{digits}"] unless digits.start_with?(BRAZIL_DDI)

    ddd = digits[2, 2]
    local = digits[4..]
    case local.length
    when 9 then ["+#{digits}", "+#{BRAZIL_DDI}#{ddd}#{local[1..]}"]
    when 8 then ["+#{digits}", "+#{BRAZIL_DDI}#{ddd}9#{local}"]
    else ["+#{digits}"]
    end
  end

  def team_conversations(contact_id)
    Conversation.where(contact_id: contact_id, team_id: team_id)
  end
end
