class Api::V1::Accounts::Rede::FrontsController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :fetch_project
  before_action :fetch_front, only: [:update, :close, :reopen]

  def index
    @fronts = @project.ordered_fronts
  end

  def create
    @front = @project.fronts.create!(front_params.merge(account: Current.account))
    render :show
  end

  def update
    @front.update!(front_params)
    render :show
  end

  def close
    @front.close!
    render :show
  end

  def reopen
    @front.reopen!
    render :show
  end

  private

  def check_authorization
    super(::Rede::Front)
  end

  def fetch_project
    @project = policy_scope(Current.account.rede_projects).find(params[:project_id])
  end

  def fetch_front
    @front = @project.fronts.find(params[:id])
  end

  def front_params
    params.permit(:name, :has_temperature)
  end
end
