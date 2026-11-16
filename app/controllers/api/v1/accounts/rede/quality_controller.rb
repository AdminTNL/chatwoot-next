class Api::V1::Accounts::Rede::QualityController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :fetch_project

  def index
    @duplicates = ::Rede::Quality::Duplicates.new(project: @project).perform
    @incompletes = ::Rede::Quality::Incompletes.new(project: @project).perform
    @resolved_this_month = ::Rede::QualityResolution.where(project_id: @project.id).resolved_in_month_of(Current.account).count
  end

  def dismiss
    contact_a, contact_b = fetch_pair(params.require(:contact_a_id), params.require(:contact_b_id))
    @resolution = find_or_create_dismissal(contact_a, contact_b)
    render :resolution
  end

  def merge
    base, mergee = fetch_pair(params.require(:base_contact_id), params.require(:mergee_contact_id))
    ActiveRecord::Base.transaction do
      ContactMergeAction.new(account: Current.account, base_contact: base, mergee_contact: mergee).perform
      @resolution = resolutions.create!(kind: :merged, contact_a_id: base.id, contact_b_id: mergee.id, resolved_by_user_id: Current.user.id)
    end
    render :resolution
  end

  private

  def check_authorization
    authorize [:rede, :quality]
  end

  def fetch_project
    @project = Current.account.rede_projects.find(params.require(:project_id))
  end

  def resolutions
    ::Rede::QualityResolution.where(account_id: Current.account.id, project_id: @project.id)
  end

  # Os dois contatos são da conta, diferentes e participam do projeto.
  def fetch_pair(first_id, second_id)
    first = Current.account.contacts.find(first_id)
    second = Current.account.contacts.find(second_id)
    raise_pair_error(:same_contact) if first.id == second.id
    raise_pair_error(:not_participating) unless @project.participations.where(contact_id: [first.id, second.id]).count == 2
    [first, second]
  end

  def raise_pair_error(key)
    resolution = ::Rede::QualityResolution.new
    resolution.errors.add(:base, I18n.t("errors.rede.quality.#{key}"))
    raise ActiveRecord::RecordInvalid, resolution
  end

  def find_or_create_dismissal(contact_a, contact_b)
    low, high = [contact_a.id, contact_b.id].sort
    existing = -> { resolutions.dismissed.find_by(contact_a_id: low, contact_b_id: high) }
    existing.call || resolutions.create!(kind: :dismissed, contact_a_id: low, contact_b_id: high, resolved_by_user_id: Current.user.id)
  rescue ActiveRecord::RecordNotUnique
    existing.call
  end
end
