class V2::Reports::Timeseries::BaseTimeseriesBuilder
  include TimezoneHelper
  include DateRangeHelper

  DEFAULT_GROUP_BY = 'day'.freeze

  pattr_initialize :account, :params

  def scope
    ensure_dimension_permitted!

    case dimension_type.to_sym
    when :account
      access_scope.restrict(account)
    when :inbox
      access_scope.restrict(inbox)
    when :agent
      access_scope.restrict(user)
    when :label
      access_scope.restrict(label)
    when :team
      access_scope.restrict(team)
    end
  end

  def data_source
    @data_source ||= Reports::DataSource.for(
      account: account,
      metric: params[:metric],
      dimension_type: dimension_type,
      dimension_id: params[:id],
      scope: scope,
      range: range,
      group_by: group_by,
      timezone_offset: params[:timezone_offset],
      business_hours: params[:business_hours]
    )
  end

  def inbox
    @inbox ||= account.inboxes.find(params[:id])
  end

  def user
    @user ||= account.users.find(params[:id])
  end

  def label
    @label ||= account.labels.find(params[:id])
  end

  def team
    @team ||= account.teams.find(params[:id])
  end

  def group_by
    @group_by ||= %w[day week month year hour].include?(params[:group_by]) ? params[:group_by] : DEFAULT_GROUP_BY
  end

  def timezone
    @timezone ||= timezone_name_from_offset(params[:timezone_offset])
  end

  private

  def access_scope
    params[:access_scope] || Reports::AccessScope::Null.instance
  end

  def ensure_dimension_permitted!
    return if access_scope.unrestricted?
    raise ActiveRecord::RecordNotFound unless access_scope.permits_dimension?(dimension_type, params[:id])
  end

  def dimension_type
    (params[:type].presence || 'account').to_s
  end
end
