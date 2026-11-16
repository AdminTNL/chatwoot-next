class Api::V1::Accounts::Rede::InteractionsController < Api::V1::Accounts::BaseController
  before_action :check_authorization, only: [:index, :create]

  def index
    @interactions = policy_scope(interactions_in_account).includes(:author_user).order(occurred_at: :desc, id: :desc)
    @interactions = @interactions.where(contact_id: params.require(:contact_id))
    @interactions = @interactions.where(project_id: scoped_project(params[:project_id]).id) if params[:project_id].present?
  end

  def create
    project = scoped_project(params[:project_id])
    contact = Current.account.contacts.find(params[:contact_id])
    @interaction = interactions_in_account.create!(
      create_params.merge(account: Current.account, project: project, contact: contact, author_user: Current.user)
    )
    render :show
  end

  def update
    @interaction = policy_scope(interactions_in_account).find(params[:id])
    authorize @interaction
    @interaction.update!(update_params)
    render :show
  end

  private

  def check_authorization
    super(::Rede::Interaction)
  end

  def interactions_in_account
    ::Rede::Interaction.where(account_id: Current.account.id)
  end

  def scoped_project(id)
    policy_scope(Current.account.rede_projects).find(id)
  end

  def create_params
    params.permit(:front_id, :kind, :answered, :summary, :occurred_at)
  end

  def update_params
    params.permit(:summary, :answered)
  end
end
