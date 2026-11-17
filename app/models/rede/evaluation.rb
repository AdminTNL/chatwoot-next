# == Schema Information
#
# Table name: rede_evaluations
#
#  id             :bigint           not null, primary key
#  dimension      :string           default("temperatura"), not null
#  evaluated_at   :datetime         not null
#  level          :integer
#  note           :text
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
#  index_rede_evaluations_on_account_id                (account_id)
#  index_rede_evaluations_on_author_user_id            (author_user_id)
#  index_rede_evaluations_on_context_and_evaluated_at  (contact_id,project_id,front_id,evaluated_at)
#  index_rede_evaluations_on_front_id                  (front_id)
#  index_rede_evaluations_on_project_id                (project_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (author_user_id => users.id) ON DELETE => nullify
#  fk_rails_...  (contact_id => contacts.id)
#  fk_rails_...  (front_id => rede_fronts.id)
#  fk_rails_...  (project_id => rede_projects.id)
#
# Cada mudança de temperatura é uma linha nova; a atual é a mais recente do contexto (ver Rede::Evaluations::Current).
# `level` nulo é o registro de que a temperatura foi retirada ("sem temperatura").
class Rede::Evaluation < ApplicationRecord
  DIMENSIONS = %w[temperatura].freeze

  belongs_to :account
  belongs_to :contact
  belongs_to :project, class_name: 'Rede::Project', inverse_of: :evaluations
  belongs_to :front, class_name: 'Rede::Front', optional: true
  belongs_to :author_user, class_name: 'User', optional: true

  enum :level, { frio: 0, morno: 1, quente: 2, vapor: 3 }, validate: { allow_nil: true }

  validates :dimension, inclusion: { in: DIMENSIONS }
  validates :evaluated_at, presence: true
  validate :records_belong_to_account
  validate :person_participates_in_project, on: :create
  validate :front_matches_project, on: :create

  before_validation { self.evaluated_at ||= Time.current }

  # Insert-only: corrigir é registrar outra linha. (Não usar readonly?, que quebraria o dependent: :destroy.)
  before_update { raise ActiveRecord::ReadOnlyRecord }

  private

  def records_belong_to_account
    errors.add(:contact, :invalid) if contact && contact.account_id != account_id
    errors.add(:project, :invalid) if project && project.account_id != account_id
  end

  def participation
    @participation ||= Rede::Participation.active.find_by(contact_id: contact_id, project_id: project_id)
  end

  def person_participates_in_project
    return if contact.nil? || project.nil?

    errors.add(:contact, I18n.t('errors.rede.evaluation.not_participating')) if participation.nil?
  end

  def front_matches_project
    return if project.nil?

    if project.has_fronts?
      front_required_rules
    elsif front_id.present?
      errors.add(:front, I18n.t('errors.rede.evaluation.front_must_be_blank'))
    end
  end

  def front_required_rules
    return errors.add(:front, :blank) if front_id.blank?
    return errors.add(:front, :invalid) if front.nil? || front.project_id != project_id

    message = front_rejection
    errors.add(:front, message) if message
  end

  def front_rejection
    return I18n.t('errors.rede.evaluation.front_closed') unless front.active?
    return I18n.t('errors.rede.evaluation.front_without_temperature') unless front.has_temperature?

    I18n.t('errors.rede.evaluation.assignment_required') unless active_assignment_in_front?
  end

  def active_assignment_in_front?
    participation.present? && participation.assignments.active.exists?(front_id: front_id)
  end
end
