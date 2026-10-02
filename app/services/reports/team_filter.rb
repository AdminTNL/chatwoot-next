# frozen_string_literal: true

# Optional "only this team" filter for the overview report tables and
# their CSV exports. Each reader answers with the ids/titles of the rows
# that belong to the team, per dimension.
class Reports::TeamFilter
  attr_reader :team_id

  # Validates the requested team (default deny) and builds the filter.
  # Raises RecordNotFound (404) for a team that is not in the account, or
  # that a restricted user does not belong to.
  def self.resolve(account:, team_id:, access_scope:)
    team = account.teams.find(team_id)
    raise ActiveRecord::RecordNotFound if !access_scope.unrestricted? && access_scope.team_ids.exclude?(team.id)

    new(account: account, team_id: team.id)
  end

  def initialize(account:, team_id:)
    @account = account
    @team_id = team_id.to_i
  end

  def agent_ids
    TeamMember.where(team_id: team_id).pluck(:user_id)
  end

  def inbox_ids
    @account.inboxes.where(team_id: team_id).pluck(:id)
  end

  def label_ids
    @account.labels.where(team_id: team_id).pluck(:id)
  end

  def label_titles
    @account.labels.where(team_id: team_id).pluck(:title)
  end

  def team_ids
    [team_id]
  end
end
