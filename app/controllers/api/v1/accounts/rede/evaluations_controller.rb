class Api::V1::Accounts::Rede::EvaluationsController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :fetch_project

  def index
    @evaluations = @project.evaluations.where(contact_id: params.require(:contact_id))
                           .includes(:author_user).order(evaluated_at: :desc, id: :desc)
    @evaluations = @evaluations.where(front_id: params[:front_id]) if params[:front_id].present?
  end

  # Só insere: mudar a temperatura é registrar uma linha nova.
  def create
    @evaluation = @project.evaluations.create!(evaluation_params.merge(account: Current.account, author_user: Current.user))
    render :show
  end

  private

  def check_authorization
    super(::Rede::Evaluation)
  end

  # Fora do escopo do usuário (agente que não é do time) dá 404.
  def fetch_project
    @project = policy_scope(Current.account.rede_projects).find(params[:project_id])
  end

  def evaluation_params
    params.permit(:contact_id, :front_id, :level, :note)
  end
end
