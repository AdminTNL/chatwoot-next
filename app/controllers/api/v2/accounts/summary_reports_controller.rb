class Api::V2::Accounts::SummaryReportsController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :prepare_builder_params, only: [:agent, :team, :inbox, :label, :channel]

  def agent
    render_report_with(V2::Reports::AgentSummaryBuilder, type: :agent)
  end

  def team
    render_report_with(V2::Reports::TeamSummaryBuilder, type: :team)
  end

  def inbox
    render_report_with(V2::Reports::InboxSummaryBuilder, type: :inbox)
  end

  def label
    render_report_with(V2::Reports::LabelSummaryBuilder, type: :label)
  end

  def channel
    return render_could_not_create_error(I18n.t('errors.reports.date_range_too_long')) if date_range_too_long?

    render_report_with(V2::Reports::ChannelSummaryBuilder)
  end

  private

  def check_authorization
    authorize :report, :view?
  end

  def prepare_builder_params
    @builder_params = {
      since: permitted_params[:since],
      until: permitted_params[:until],
      business_hours: ActiveModel::Type::Boolean.new.cast(permitted_params[:business_hours])
    }
  end

  # Mirrors Api::V2::Accounts::ReportsHelper#accessible_agents/inboxes/teams
  # and #accessible_label_titles, which already scope the CSV export of
  # these same reports. Kept here instead of in the builders so they stay
  # unaware of access scoping, same as the CSV path.
  DIMENSION_ID_READERS = {
    agent: :agent_ids,
    team: :team_ids,
    inbox: :inbox_ids,
    label: :label_ids
  }.freeze

  def render_report_with(builder_class, type: nil)
    builder_params = type.present? ? @builder_params.merge(type: type) : @builder_params
    builder = builder_class.new(account: Current.account, params: builder_params)
    render json: filter_by_access_scope(builder.build, type)
  end

  def filter_by_access_scope(report, type)
    return report if access_scope.unrestricted?

    reader = DIMENSION_ID_READERS[type]
    return report unless reader

    accessible_ids = access_scope.public_send(reader)
    report.select { |row| accessible_ids.include?(row[:id]) }
  end

  def access_scope
    @access_scope ||= Reports::AccessScope.new(account: Current.account, user: Current.user, account_user: Current.account_user)
  end

  def permitted_params
    params.permit(:since, :until, :business_hours)
  end

  def date_range_too_long?
    return false if permitted_params[:since].blank? || permitted_params[:until].blank?

    since_time = Time.zone.at(permitted_params[:since].to_i)
    until_time = Time.zone.at(permitted_params[:until].to_i)
    (until_time - since_time) > 6.months
  end
end
