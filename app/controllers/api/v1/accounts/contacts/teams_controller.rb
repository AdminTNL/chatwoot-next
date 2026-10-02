class Api::V1::Accounts::Contacts::TeamsController < Api::V1::Accounts::Contacts::BaseController
  def index
    @teams = Team.where(id: @contact.conversations.where.not(team_id: nil).distinct.pluck(:team_id)).order(:name)
  end
end
