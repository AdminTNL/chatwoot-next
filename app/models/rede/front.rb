# == Schema Information
#
# Table name: rede_fronts
#
#  id              :bigint           not null, primary key
#  closed_at       :datetime
#  has_temperature :boolean          default(TRUE), not null
#  name            :string           not null
#  status          :integer          default("active"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  project_id      :bigint           not null
#  public_id       :uuid             not null
#
# Indexes
#
#  index_rede_fronts_on_account_id                 (account_id)
#  index_rede_fronts_on_project_id                 (project_id)
#  index_rede_fronts_on_project_id_and_lower_name  (project_id, lower((name)::text)) UNIQUE
#  index_rede_fronts_on_public_id                  (public_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (project_id => rede_projects.id)
#
class Rede::Front < ApplicationRecord
  belongs_to :account
  belongs_to :project, class_name: 'Rede::Project', inverse_of: :fronts

  enum status: { active: 0, closed: 1 }

  # O public_id é o id que ferramentas externas guardam e nunca muda depois de criado.
  attr_readonly :public_id

  validates :name, presence: true, uniqueness: { scope: :project_id, case_sensitive: false }
  validates :has_temperature, inclusion: { in: [true, false] }

  before_validation { self.name = name.strip if name }

  def close!
    return if closed?

    update!(status: :closed, closed_at: Time.current)
  end

  def reopen!
    return if active?

    update!(status: :active, closed_at: nil)
  end
end
