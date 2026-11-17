class Api::V1::Accounts::Rede::ApiTokensController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :fetch_api_token, only: [:revoke]

  def index
    @api_tokens = Current.account.rede_api_tokens.order(:created_at, :id)
  end

  def create
    @api_token, @plain_token = ::Rede::ApiToken.generate!(account: Current.account, name: params[:name], user: Current.user)
  end

  def revoke
    @api_token.revoke!
    render :show
  end

  private

  def check_authorization
    super(::Rede::ApiToken)
  end

  def fetch_api_token
    @api_token = Current.account.rede_api_tokens.find(params[:id])
  end
end
