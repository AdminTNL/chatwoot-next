class Api::V1::Accounts::Rede::RolesController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def index
    @roles = Current.account.rede_roles.order(:name)
  end

  private

  def check_authorization
    super(::Rede::Role)
  end
end
