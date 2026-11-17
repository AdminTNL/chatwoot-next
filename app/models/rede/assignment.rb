# == Schema Information
#
# Table name: rede_assignments
#
#  id                  :bigint           not null, primary key
#  ended_at            :datetime
#  started_at          :datetime         not null
#  status              :integer          default("active"), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :bigint           not null
#  front_id            :bigint
#  participation_id    :bigint           not null
#  role_id             :bigint
#  superior_contact_id :integer
#
# Indexes
#
#  index_rede_assignments_on_account_id                      (account_id)
#  index_rede_assignments_on_active_participation_and_front  (participation_id, COALESCE(front_id, (0)::bigint)) UNIQUE WHERE (status = 0)
#  index_rede_assignments_on_front_id                        (front_id)
#  index_rede_assignments_on_participation_id_and_status     (participation_id,status)
#  index_rede_assignments_on_role_id                         (role_id)
#  index_rede_assignments_on_superior_contact_id             (superior_contact_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (front_id => rede_fronts.id)
#  fk_rails_...  (participation_id => rede_participations.id)
#  fk_rails_...  (role_id => rede_roles.id)
#  fk_rails_...  (superior_contact_id => contacts.id) ON DELETE => nullify
#
class Rede::Assignment < ApplicationRecord
  REVISABLE_ATTRIBUTES = %w[front_id role_id superior_contact_id].freeze

  belongs_to :account
  belongs_to :participation, class_name: 'Rede::Participation', inverse_of: :assignments
  belongs_to :front, class_name: 'Rede::Front', optional: true
  belongs_to :role, class_name: 'Rede::Role', optional: true
  belongs_to :superior_contact, class_name: 'Contact', optional: true

  enum status: { active: 0, closed: 1 }

  validates :started_at, presence: true
  validates :front_id, uniqueness: { scope: :participation_id, conditions: -> { active } },
                       if: :active?
  validate :references_exist
  validate :front_belongs_to_project, if: -> { front_id.present? && (new_record? || will_save_change_to_front_id?) }
  validate :same_account
  validate :superior_is_another_person

  before_validation { self.started_at ||= Time.current }

  def close!
    return if closed?

    update!(status: :closed, ended_at: Time.current)
  end

  # Mudar papel, superior ou frente encerra esta linha e abre outra (o histórico são as linhas).
  # Devolve a atuação nova, ou a própria se nada mudou.
  def revise!(attrs)
    changes = attrs.to_h.stringify_keys.slice(*REVISABLE_ATTRIBUTES).transform_values(&:presence)
    unless active?
      errors.add(:base, 'is closed')
      raise ActiveRecord::RecordInvalid, self
    end
    return self if changes.all? { |key, value| self[key].to_s == value.to_s }

    self.class.transaction do
      close!
      participation.assignments.create!(
        { account_id: account_id, front_id: front_id, role_id: role_id, superior_contact_id: superior_contact_id }.merge(changes.symbolize_keys)
      )
    end
  end

  private

  def references_exist
    errors.add(:front, :invalid) if front_id.present? && front.nil?
    errors.add(:role, :invalid) if role_id.present? && role.nil?
    errors.add(:superior_contact, :invalid) if superior_contact_id.present? && superior_contact.nil?
  end

  def front_belongs_to_project
    return if front.nil? || participation.nil?

    errors.add(:front, 'must belong to the project of the participation') if front.project_id != participation.project_id
    errors.add(:front, 'must be active') unless front.active?
  end

  def same_account
    errors.add(:participation, :invalid) if participation && participation.account_id != account_id
    errors.add(:role, :invalid) if role && role.account_id != account_id
    errors.add(:superior_contact, :invalid) if superior_contact && superior_contact.account_id != account_id
  end

  def superior_is_another_person
    return if superior_contact_id.blank? || participation.nil?

    errors.add(:superior_contact, 'cannot be the person themselves') if superior_contact_id == participation.contact_id
  end
end
