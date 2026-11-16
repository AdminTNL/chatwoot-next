class Api::V1::Accounts::Rede::AssignmentsController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :fetch_participation
  before_action :fetch_assignment, only: [:update, :close]

  def create
    @assignment = @participation.assignments.create!(assignment_params.to_h.transform_values(&:presence).merge(account: Current.account))
    render :show
  end

  # Mudar papel, superior ou frente encerra a atuação e abre outra; devolve a nova.
  def update
    @assignment = @assignment.revise!(assignment_params)
    render :show
  end

  def close
    @assignment.close!
    render :show
  end

  private

  def check_authorization
    super(::Rede::Assignment)
  end

  def fetch_participation
    @participation = policy_scope(::Rede::Participation.where(account_id: Current.account.id)).find(params[:participation_id])
  end

  def fetch_assignment
    @assignment = @participation.assignments.find(params[:id])
  end

  def assignment_params
    params.permit(:front_id, :role_id, :superior_contact_id)
  end
end
