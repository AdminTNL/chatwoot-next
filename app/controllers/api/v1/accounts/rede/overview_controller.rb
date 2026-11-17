class Api::V1::Accounts::Rede::OverviewController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def show
    @overview = ::Rede::Overview::Summary.new(account: Current.account, user: Current.user, project_id: params[:project_id]).perform
  end

  private

  def check_authorization
    super(:'rede/overview')
  end
end
