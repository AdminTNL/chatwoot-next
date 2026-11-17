class Api::V1::Accounts::Rede::PeopleController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def index
    result = ::Rede::People::Query.new(account: Current.account, user: Current.user, params: query_params).perform
    @rows = result.rows
    @meta = { count: result.count, page: result.page, per_page: result.per_page }
  end

  def filters
    @projects = ::Rede::AccessScope.new(account: Current.account, user: Current.user, account_user: Current.account_user)
                                   .restrict_projects(Current.account.rede_projects.active).includes(:fronts, :team).order(:name)
    @responsibles = responsibles_for(@projects)
  end

  def show
    @profile = ::Rede::People::Profile.new(account: Current.account, user: Current.user, contact: contact).perform
  end

  def timeline
    result = ::Rede::People::Timeline.new(account: Current.account, user: Current.user, contact: contact, params: timeline_params).perform
    @events = result.events
    @meta = { limit: result.limit, next_cursor: result.next_cursor }
  rescue ::Rede::People::Timeline::InvalidParams => e
    render_could_not_create_error(e.message)
  end

  private

  def contact
    Current.account.contacts.find(params[:id])
  end

  def timeline_params
    params.permit(:project_id, :from, :to, :before, :limit, types: [])
  end

  def check_authorization
    super(:'rede/person')
  end

  def query_params
    params.permit(:q, :city, :no_contact_days, :sort, :page, :per_page, :include_closed, :has_front, :front_pending,
                  project_ids: [], front_ids: [], temperatures: [], responsible_ids: [])
  end

  # Membros dos times dos projetos e administradores da conta.
  def responsibles_for(projects)
    admin_ids = Current.account.account_users.administrator.select(:user_id)
    member_ids = TeamMember.where(team_id: projects.map(&:team_id)).select(:user_id)
    User.where(id: admin_ids).or(User.where(id: member_ids)).order(:name)
  end
end
