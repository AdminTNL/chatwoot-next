# Leitura externa dos projetos. Não herda de Api::BaseController: sem sessão, sem cookies e sem Current.user.
class Api::Rede::V1::ProjectsController < ActionController::API
  before_action :authenticate_api_token!

  def index
    @projects = @api_token.account.rede_projects.includes(:fronts).order(Arel.sql('LOWER(rede_projects.name)'), :id).to_a
    fresh_when(etag: [@api_token.account_id, @projects, @projects.flat_map { |project| project.fronts.sort_by(&:id) }])
  end

  private

  def authenticate_api_token!
    @api_token = ::Rede::ApiToken.authenticate(bearer_token)
    return render json: { error: 'invalid_token' }, status: :unauthorized if @api_token.nil? || !@api_token.account.active?

    render json: { error: 'forbidden' }, status: :forbidden unless @api_token.scope?(::Rede::ApiToken::SCOPE_PROJECTS_READ)
  end

  def bearer_token
    scheme, value = request.authorization.to_s.split(' ', 2)
    value.to_s.strip if scheme.to_s.casecmp?('bearer')
  end
end
