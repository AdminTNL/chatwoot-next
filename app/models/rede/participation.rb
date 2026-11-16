# == Schema Information
#
# Table name: rede_participations
#
#  id                     :bigint           not null, primary key
#  joined_at              :datetime         not null
#  next_step              :text
#  origin                 :integer          default("manual"), not null
#  referred_by_text       :string
#  status                 :integer          default("active"), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  account_id             :bigint           not null
#  contact_id             :integer          not null
#  project_id             :bigint           not null
#  referred_by_contact_id :integer
#  responsible_user_id    :integer
#
# Indexes
#
#  index_rede_participations_on_account_id                 (account_id)
#  index_rede_participations_on_contact_id_and_project_id  (contact_id,project_id) UNIQUE
#  index_rede_participations_on_project_id_and_status      (project_id,status)
#  index_rede_participations_on_referred_by_contact_id     (referred_by_contact_id)
#  index_rede_participations_on_responsible_user_id        (responsible_user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (contact_id => contacts.id)
#  fk_rails_...  (project_id => rede_projects.id)
#  fk_rails_...  (referred_by_contact_id => contacts.id) ON DELETE => nullify
#  fk_rails_...  (responsible_user_id => users.id) ON DELETE => nullify
#
class Rede::Participation < ApplicationRecord
  belongs_to :account
  belongs_to :contact
  belongs_to :project, class_name: 'Rede::Project', inverse_of: :participations
  belongs_to :responsible_user, class_name: 'User', optional: true
  belongs_to :referred_by_contact, class_name: 'Contact', optional: true
  has_many :assignments, class_name: 'Rede::Assignment', dependent: :destroy, inverse_of: :participation

  # O prefixo evita colisão com `import` do activerecord-import.
  enum origin: { manual: 0, import: 1, integration: 2, form: 3 }, _prefix: :origin
  enum :status, { active: 0, closed: 1 }, validate: true

  validates :contact_id, uniqueness: { scope: :project_id }
  validates :joined_at, presence: true
  validate :records_belong_to_account
  validate :project_accepts_new_participation, on: :create
  validate :responsible_is_project_agent, if: -> { responsible_user_id.present? && (new_record? || will_save_change_to_responsible_user_id?) }
  validate :single_referral_source

  before_validation { self.joined_at ||= Time.current }

  private

  def records_belong_to_account
    errors.add(:contact, :invalid) if contact && contact.account_id != account_id
    errors.add(:project, :invalid) if project && project.account_id != account_id
    errors.add(:referred_by_contact, :invalid) if referred_by_contact && referred_by_contact.account_id != account_id
  end

  def project_accepts_new_participation
    errors.add(:project, 'is closed') if project&.closed?
  end

  def responsible_is_project_agent
    return if responsible_user.nil? || project.nil?
    return if project.team.team_members.exists?(user_id: responsible_user_id)
    return if account.account_users.administrator.exists?(user_id: responsible_user_id)

    errors.add(:responsible_user, 'must be a member of the project or an administrator')
  end

  def single_referral_source
    errors.add(:referred_by_text, 'cannot be combined with a referring contact') if referred_by_contact_id.present? && referred_by_text.present?
    errors.add(:referred_by_contact, 'cannot be the person themselves') if referred_by_contact_id.present? && referred_by_contact_id == contact_id
  end
end
