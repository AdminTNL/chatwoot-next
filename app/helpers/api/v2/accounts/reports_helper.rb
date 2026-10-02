module Api::V2::Accounts::ReportsHelper
  def generate_agents_report
    reports = V2::Reports::AgentSummaryBuilder.new(
      account: Current.account,
      params: build_params({ type: :agent }.merge(current_team_filter ? { team_id: current_team_filter.team_id } : {}))
    ).build

    accessible_agents.map do |agent|
      report = reports.find { |r| r[:id] == agent.id }
      [agent.name] + generate_readable_report_metrics(report)
    end
  end

  def generate_inboxes_report
    reports = V2::Reports::InboxSummaryBuilder.new(
      account: Current.account,
      params: build_params(type: :inbox)
    ).build

    accessible_inboxes.map do |inbox|
      report = reports.find { |r| r[:id] == inbox.id }
      [inbox.name, inbox.channel&.name] + generate_readable_report_metrics(report)
    end
  end

  def generate_teams_report
    reports = V2::Reports::TeamSummaryBuilder.new(
      account: Current.account,
      params: build_params(type: :team)
    ).build

    accessible_teams.map do |team|
      report = reports.find { |r| r[:id] == team.id }
      [team.name] + generate_readable_report_metrics(report)
    end
  end

  def generate_labels_report
    reports = V2::Reports::LabelSummaryBuilder.new(
      account: Current.account,
      params: build_params({})
    ).build

    reports = reports.select { |report| accessible_label_titles.nil? || accessible_label_titles.include?(report[:name]) }
    reports = reports.select { |report| current_team_filter.label_titles.include?(report[:name]) } if current_team_filter

    reports.map do |report|
      [report[:name]] + generate_readable_report_metrics(report)
    end
  end

  def generate_conversations_report
    builder = V2::Reports::Conversations::MetricBuilder.new(Current.account, build_params(type: :account))
    summary = builder.summary

    [generate_conversation_report_metrics(summary)]
  end

  private

  def build_params(base_params)
    base_params.merge(
      {
        since: params[:since],
        until: params[:until],
        business_hours: ActiveModel::Type::Boolean.new.cast(params[:business_hours]),
        access_scope: access_scope
      }
    )
  end

  # Row-level scoping for the CSV enumerators above: a restricted agent
  # only ever sees rows for agents/inboxes/teams/labels inside their
  # Reports::AccessScope, never the account-wide list.
  def accessible_agents
    agents = access_scope.unrestricted? ? Current.account.users : Current.account.users.where(id: access_scope.agent_ids)
    current_team_filter ? agents.where(id: current_team_filter.agent_ids) : agents
  end

  def accessible_inboxes
    inboxes = access_scope.unrestricted? ? Current.account.inboxes : Current.account.inboxes.where(id: access_scope.inbox_ids)
    current_team_filter ? inboxes.where(id: current_team_filter.inbox_ids) : inboxes
  end

  def accessible_teams
    teams = access_scope.unrestricted? ? Current.account.teams : Current.account.teams.where(id: access_scope.team_ids)
    current_team_filter ? teams.where(id: current_team_filter.team_ids) : teams
  end

  # Optional Reports::TeamFilter; the includer may not define `team_filter`.
  def current_team_filter
    respond_to?(:team_filter, true) ? team_filter : nil
  end

  def accessible_label_titles
    access_scope.label_titles
  end

  def report_builder(report_params)
    V2::ReportBuilder.new(Current.account, build_params(report_params))
  end

  def generate_readable_report_metrics(report)
    [
      report[:conversations_count],
      Reports::TimeFormatPresenter.new(report[:avg_first_response_time]).format,
      Reports::TimeFormatPresenter.new(report[:avg_resolution_time]).format,
      Reports::TimeFormatPresenter.new(report[:avg_reply_time]).format,
      report[:resolved_conversations_count]
    ]
  end

  def generate_conversation_report_metrics(summary)
    [
      summary[:conversations_count],
      summary[:incoming_messages_count],
      summary[:outgoing_messages_count],
      Reports::TimeFormatPresenter.new(summary[:avg_first_response_time]).format,
      Reports::TimeFormatPresenter.new(summary[:avg_resolution_time]).format,
      summary[:resolutions_count],
      Reports::TimeFormatPresenter.new(summary[:reply_time]).format
    ]
  end
end
