class Labels::ContactInheritanceService
  pattr_initialize [:conversation_id!]

  def perform
    conversation = Conversation.find_by(id: conversation_id)
    return if conversation.blank? || conversation.team_id.blank?

    contact = conversation.contact
    return if contact.blank?

    account = conversation.account
    team_titles = account.labels.where(team_id: conversation.team_id).pluck(:title)
    inherited_labels = contact.label_list & team_titles
    return if inherited_labels.blank?

    Labels::TaggingWriter.new(account: account)
                         .apply(record: conversation, added_labels: inherited_labels, removed_labels: [])
  end
end
