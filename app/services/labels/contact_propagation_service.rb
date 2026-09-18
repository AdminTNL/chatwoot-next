class Labels::ContactPropagationService
  pattr_initialize [:contact_id!, :team_id!, :added_labels!, :removed_labels!]

  def perform
    contact = Contact.find_by(id: contact_id)
    return if contact.blank?

    account = contact.account

    contact.conversations.where(team_id: team_id).find_each do |conversation|
      Labels::TaggingWriter.new(account: account)
                           .apply(record: conversation, added_labels: added_labels, removed_labels: removed_labels)
    end
  end
end
