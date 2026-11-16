class Api::V1::Accounts::Rede::ParticipationsController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def create
    project = policy_scope(Current.account.rede_projects).find(params[:project_id])
    @participation = ::Rede::Participations::Create.new(account: Current.account, project: project, params: create_params).perform
    render :show
  rescue ::Rede::Participations::Create::AlreadyParticipating => e
    @participation = e.participation
    @error = I18n.t('errors.rede.participation.already_exists')
    render :show, status: :unprocessable_entity
  end

  def update
    @participation = policy_scope(::Rede::Participation.where(account_id: Current.account.id)).find(params[:id])
    @participation.update!(update_params)
    render :show
  end

  private

  def check_authorization
    super(::Rede::Participation)
  end

  def create_params
    params.permit(:contact_id, contact: [:name, :phone_number], assignment: [:front_id, :role_id, :superior_contact_id])
  end

  def update_params
    params.permit(:responsible_user_id, :next_step, :referred_by_contact_id, :referred_by_text, :status)
  end
end
