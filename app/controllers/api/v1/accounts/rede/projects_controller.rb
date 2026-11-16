class Api::V1::Accounts::Rede::ProjectsController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :fetch_project, only: [:show, :update, :close, :reopen]
  before_action :load_member_team_ids

  def index
    @projects = policy_scope(Current.account.rede_projects).includes(team: [:inboxes, :team_members]).order(:name)
  end

  def show; end

  def create
    attrs = params.permit(:name, :color)
    ::Rede::Project.transaction do
      team = Current.account.teams.create!(team_params.merge(name: attrs[:name].to_s.downcase))
      @project = team.rede_project
      @project.update!(attrs)
    end
    render :show
  end

  def update
    attrs = params.permit(:name, :color)
    ::Rede::Project.transaction do
      @project.team.update!(description: params[:description]) if params.key?(:description)
      @project.update!(attrs)
    end
    render :show
  end

  def close
    @project.close!
    render :show
  end

  def reopen
    @project.reopen!
    render :show
  end

  private

  def check_authorization
    super(::Rede::Project)
  end

  def load_member_team_ids
    @member_team_ids = Current.user.team_ids.to_set
  end

  def fetch_project
    @project = policy_scope(Current.account.rede_projects).find(params[:id])
  end

  def team_params
    params.permit(:description, :icon, :icon_color)
  end
end
