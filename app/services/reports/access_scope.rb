# frozen_string_literal: true

# Single shared point of "who can see what" for reports.
#
# Every report query point (timeseries, drilldown, summary tables, the
# inbox x label matrix, CSV exports, live reports) is expected to consult
# this object instead of re-deriving the access rules on its own.
#
# `unrestricted?` is true for administrators and for agents with the
# `report_manage` custom-role permission: they keep seeing the whole
# account, exactly like before this feature existed.
#
# For everyone else ("restricted" users), every id-returning method
# answers with the ids the user is allowed to see; `nil` is used
# throughout to mean "no restriction" so unrestricted callers (the hot,
# high volume path) never need to materialize the full id list for the
# account.
class Reports::AccessScope
  def initialize(account:, user:, account_user:)
    @account = account
    @user = user
    @account_user = account_user
  end

  def unrestricted?
    return @unrestricted if defined?(@unrestricted)

    @unrestricted = @account_user.administrator? ||
                    @account_user.custom_role&.permissions&.include?('report_manage') || false
  end

  # Ids of the inboxes this user can see reports for. `nil` means "all
  # inboxes in the account" (unrestricted).
  def inbox_ids
    return nil if unrestricted?

    @inbox_ids ||= @user.accessible_inboxes(@account).ids
  end

  # Ids of the labels this user can see reports for. `nil` means "all
  # labels in the account" (unrestricted).
  def label_ids
    return nil if unrestricted?

    @label_ids ||= accessible_labels.ids
  end

  def label_titles
    return nil if unrestricted?

    @label_titles ||= accessible_labels.pluck(:title)
  end

  # Ids of the teams this user belongs to. `nil` means "all teams in the
  # account" (unrestricted).
  def team_ids
    return nil if unrestricted?

    @team_ids ||= @user.teams.where(account_id: @account.id).ids
  end

  # Ids of the agents this user can see agent-dimension reports for:
  # themselves, plus anyone who shares at least one accessible inbox or
  # one team with them. `nil` means "every agent in the account"
  # (unrestricted).
  def agent_ids
    return nil if unrestricted?

    @agent_ids ||= compute_agent_ids
  end

  DIMENSION_ID_READERS = {
    'inbox' => :inbox_ids,
    'label' => :label_ids,
    'team' => :team_ids,
    'agent' => :agent_ids
  }.freeze

  # Default-deny check for a requested report dimension (`type`/`id`
  # params). `type: :account` is always permitted (its own dataset is
  # restricted separately, via `restrict`); every other dimension must
  # resolve to an id inside the accessible set for this user.
  def permits_dimension?(type, id)
    return true if unrestricted?
    return true if type.to_s == 'account'
    return false if id.blank?

    reader = DIMENSION_ID_READERS[type.to_s]
    return false unless reader

    public_send(reader).include?(id.to_i)
  end

  # Wraps a dimension target (the account itself, an inbox, an agent, a
  # label or a team) so that `.conversations` / `.messages` /
  # `.reporting_events` called on it only ever return rows whose
  # `inbox_id` is in the accessible set. This is what applies the scope
  # to the *base dataset*, regardless of which dimension the caller
  # picked - a scope check on the requested dimension alone is not
  # enough (e.g. an "account" report from a restricted agent must not
  # sum every inbox in the account).
  #
  # Unrestricted users get the target back untouched (no query overhead).
  def restrict(target)
    return target if unrestricted?

    ScopedDimension.new(target, inbox_ids)
  end

  private

  def accessible_labels
    LabelPolicy::Scope.new(user_context, @account.labels).resolve
  end

  def user_context
    { user: @user, account: @account, account_user: @account_user }
  end

  def compute_agent_ids
    via_inbox = InboxMember.where(inbox_id: inbox_ids).distinct.pluck(:user_id)
    via_team = TeamMember.where(team_id: team_ids).distinct.pluck(:user_id)

    (via_inbox + via_team + [@user.id]).uniq
  end
end
