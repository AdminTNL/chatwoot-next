# == Schema Information
#
# Table name: label_groups
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#  team_id    :bigint           not null
#
# Indexes
#
#  index_label_groups_on_account_id        (account_id)
#  index_label_groups_on_team_id           (team_id)
#  index_label_groups_on_team_id_and_name  (team_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (team_id => teams.id)
#
class LabelGroup < ApplicationRecord
  belongs_to :account
  belongs_to :team
  has_many :labels, dependent: :nullify

  validates :name,
            presence: { message: I18n.t('errors.validations.presence') },
            uniqueness: { scope: :team_id }
  validate :team_belongs_to_same_account

  before_validation do
    self.name = name.strip.downcase if attribute_present?('name')
  end

  private

  def team_belongs_to_same_account
    return if team.blank?

    errors.add(:team, :invalid) if team.account_id != account_id
  end
end
