# frozen_string_literal: true

# Single shared point of "which contacts can this user see" — the
# contacts equivalent of `Reports::AccessScope` (spec 10).
#
# A contact has no direct link to a team or an inbox: the only path is
# indirect, through its conversations (`conversation.inbox_id`). This
# service reuses `User#accessible_inboxes(account)` (spec 7) — which
# already combines direct `inbox_members` and inboxes inherited via team
# membership — to answer "does this agent have at least one conversation
# with this contact in an inbox they can access".
#
# `unrestricted?` is true for administrators: they keep seeing every
# contact in the account, exactly like before this feature existed.
class Contacts::AccessScope
  def initialize(account:, user:, account_user: nil)
    @account = account
    @user = user
    @account_user = account_user || @account.account_users.find_by(user_id: @user.id)
  end

  def unrestricted?
    return @unrestricted if defined?(@unrestricted)

    @unrestricted = @account_user&.administrator? || false
  end

  # Ids of the inboxes this user can see contacts through. `nil` means
  # "every inbox in the account" (unrestricted).
  def inbox_ids
    return nil if unrestricted?

    @inbox_ids ||= @user.accessible_inboxes(@account).ids
  end

  # Restricts `contacts_relation` to contacts with at least one
  # conversation in an accessible inbox. Returns the relation unchanged
  # for unrestricted (administrator) users.
  #
  # Uses a `where(id: ...select(:contact_id))` subquery rather than a
  # join, so a contact with conversations in more than one accessible
  # inbox is never duplicated and `.total_count`/pagination downstream
  # stay correct.
  def restrict(contacts_relation)
    return contacts_relation if unrestricted?

    contacts_relation.where(id: Conversation.where(inbox_id: inbox_ids).select(:contact_id))
  end
end
