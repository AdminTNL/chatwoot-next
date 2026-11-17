# Par de contatos já resolvido na qualidade dos dados, por projeto.
# `contact_a_id` e `contact_b_id` não têm FK: no merge, o contato absorvido deixa de existir.
# == Schema Information
#
# Table name: rede_quality_resolutions
#
#  id                  :bigint           not null, primary key
#  kind                :integer          not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :bigint           not null
#  contact_a_id        :integer          not null
#  contact_b_id        :integer          not null
#  project_id          :bigint           not null
#  resolved_by_user_id :integer
#
# Indexes
#
#  index_rede_quality_resolutions_dismissed_pair             (project_id,contact_a_id,contact_b_id) UNIQUE WHERE (kind = 1)
#  index_rede_quality_resolutions_on_account_id              (account_id)
#  index_rede_quality_resolutions_on_project_and_created_at  (project_id,created_at)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (project_id => rede_projects.id)
#
class Rede::QualityResolution < ApplicationRecord
  belongs_to :account
  belongs_to :project, class_name: 'Rede::Project', inverse_of: :quality_resolutions

  enum :kind, { merged: 0, dismissed: 1 }, validate: true

  validates :contact_a_id, :contact_b_id, presence: true
  validate :distinct_contacts
  validate :project_in_account

  # O par é sempre guardado ordenado (a < b).
  before_validation :order_pair

  # Resoluções do mês corrente no fuso da conta.
  scope :resolved_in_month_of, lambda { |account, now = Time.current|
    zone = ActiveSupport::TimeZone[account.reporting_timezone.to_s] || Time.zone
    month = now.in_time_zone(zone)
    where(created_at: month.all_month)
  }

  private

  def order_pair
    return if contact_a_id.blank? || contact_b_id.blank? || contact_a_id <= contact_b_id

    self.contact_a_id, self.contact_b_id = contact_b_id, contact_a_id
  end

  def distinct_contacts
    errors.add(:contact_b_id, :invalid) if contact_a_id.present? && contact_a_id == contact_b_id
  end

  def project_in_account
    errors.add(:project, :invalid) if project && project.account_id != account_id
  end
end
