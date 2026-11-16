# == Schema Information
#
# Table name: rede_projects
#
#  id         :bigint           not null, primary key
#  closed_at  :datetime
#  color      :string           not null
#  name       :string           not null
#  slug       :string           not null
#  status     :integer          default("active"), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#  team_id    :bigint           not null
#
# Indexes
#
#  index_rede_projects_on_account_id           (account_id)
#  index_rede_projects_on_account_id_and_slug  (account_id,slug) UNIQUE
#  index_rede_projects_on_team_id              (team_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (team_id => teams.id)
#
class Rede::Project < ApplicationRecord
  COLOR_PALETTE = %w[#1F93FF #E5484D #30A46C #F5A524 #8E4EC6 #00A2C7 #D6409F #6E56CF].freeze
  COLOR_FORMAT = /\A#\h{6}\z/

  belongs_to :account
  belongs_to :team, inverse_of: :rede_project

  enum status: { active: 0, closed: 1 }

  # Evita o ciclo de sincronização de nome entre projeto e time (decisão 2 da spec 001).
  attr_accessor :skip_team_name_sync

  # O slug é o id público e nunca muda depois de criado.
  attr_readonly :slug

  validates :name, :slug, presence: true
  validates :color, presence: true, format: { with: COLOR_FORMAT, allow_blank: true }
  validates :slug, uniqueness: { scope: :account_id }
  validates :team_id, uniqueness: true

  before_validation { self.name = name.strip if name }
  after_update :sync_team_name, if: :saved_change_to_name?

  def close!
    return if closed?

    update!(status: :closed, closed_at: Time.current)
  end

  def reopen!
    return if active?

    update!(status: :active, closed_at: nil)
  end

  private

  def sync_team_name
    return if skip_team_name_sync

    team.skip_rede_project_name_sync = true
    team.update!(name: name)
  ensure
    team.skip_rede_project_name_sync = false
  end
end
