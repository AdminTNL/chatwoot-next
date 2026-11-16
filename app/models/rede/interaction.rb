# == Schema Information
#
# Table name: rede_interactions
#
#  id             :bigint           not null, primary key
#  answered       :boolean
#  kind           :integer          not null
#  occurred_at    :datetime         not null
#  summary        :text             not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  account_id     :bigint           not null
#  author_user_id :integer
#  contact_id     :integer          not null
#  front_id       :bigint
#  project_id     :bigint           not null
#
# Indexes
#
#  index_rede_interactions_on_account_id                   (account_id)
#  index_rede_interactions_on_author_user_id               (author_user_id)
#  index_rede_interactions_on_contact_project_occurred_at  (contact_id,project_id,occurred_at)
#  index_rede_interactions_on_front_id                     (front_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (author_user_id => users.id) ON DELETE => nullify
#  fk_rails_...  (contact_id => contacts.id)
#  fk_rails_...  (front_id => rede_fronts.id)
#  fk_rails_...  (project_id => rede_projects.id)
#
class Rede::Interaction < ApplicationRecord
  EDIT_WINDOW = 24.hours

  belongs_to :account
  belongs_to :contact
  belongs_to :project, class_name: 'Rede::Project', inverse_of: :interactions
  belongs_to :front, class_name: 'Rede::Front', optional: true
  belongs_to :author_user, class_name: 'User', optional: true

  enum :kind, { call: 0, note: 1 }, validate: true

  validates :summary, presence: true
  validates :occurred_at, presence: true
  validates :answered, inclusion: { in: [true, false] }, if: :call?
  validate :records_belong_to_account
  validate :contact_participates_in_project, if: -> { new_record? || will_save_change_to_contact_id? || will_save_change_to_project_id? }
  validate :front_belongs_to_project, if: -> { front_id.present? && (new_record? || will_save_change_to_front_id?) }
  validate :occurred_at_not_in_future, if: -> { new_record? || will_save_change_to_occurred_at? }
  validate :within_edit_window, on: :update

  before_validation { self.occurred_at ||= Time.current }
  before_validation { self.answered = nil if note? }

  after_create_commit { Rede::LastContact::Touch.new(interaction: self).perform }

  private

  def records_belong_to_account
    errors.add(:contact, :invalid) if contact && contact.account_id != account_id
    errors.add(:project, :invalid) if project && project.account_id != account_id
    errors.add(:front, :invalid) if front && front.account_id != account_id
  end

  def contact_participates_in_project
    return if contact.nil? || project.nil?

    return if Rede::Participation.exists?(contact_id: contact_id, project_id: project_id)

    errors.add(:contact, I18n.t('errors.rede.interaction.not_participating'))
  end

  def front_belongs_to_project
    errors.add(:front, I18n.t('errors.rede.interaction.front_other_project')) if front && front.project_id != project_id
  end

  def occurred_at_not_in_future
    errors.add(:occurred_at, I18n.t('errors.rede.interaction.future_occurred_at')) if occurred_at.present? && occurred_at > Time.current
  end

  def within_edit_window
    errors.add(:base, I18n.t('errors.rede.interaction.edit_window_expired')) if created_at < EDIT_WINDOW.ago
  end
end
