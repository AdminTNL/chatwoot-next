class ReportPolicy < ApplicationPolicy
  # Every account_user (administrator or agent) may view reports now.
  # Administrators and agents with the `report_manage` custom-role
  # permission see account-wide data; every other agent is limited by
  # Reports::AccessScope to the inboxes/labels/teams/agents they can
  # access. That data-level restriction is what enforces the real
  # boundary here, not this policy.
  def view?
    @account_user.present?
  end
end

ReportPolicy.prepend_mod_with('ReportPolicy')
