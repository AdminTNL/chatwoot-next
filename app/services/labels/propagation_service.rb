class Labels::PropagationService
  pattr_initialize [:conversation_id!, :added_labels!, :removed_labels!]

  def perform
    conversation = Conversation.find_by(id: conversation_id)
    return if conversation.blank? || conversation.team_id.blank?

    contact = conversation.contact
    return if contact.blank?

    account = conversation.account

    sibling_conversations(conversation, contact).find_each do |sibling|
      apply_changes_to(sibling, account)
    end

    apply_changes_to(contact, account)
  end

  private

  def sibling_conversations(conversation, contact)
    contact.conversations.where(team_id: conversation.team_id).where.not(id: conversation.id)
  end

  # Applies removed_labels then added_labels to a single target record (a sibling
  # Conversation or the Contact). See Labels::TaggingWriter for how the change is
  # written without triggering callbacks on the target (avoiding a propagation loop).
  def apply_changes_to(record, account)
    Labels::TaggingWriter.new(account: account)
                         .apply(record: record, added_labels: added_labels, removed_labels: removed_labels)
  end
end
