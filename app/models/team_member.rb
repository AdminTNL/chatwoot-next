# == Schema Information
#
# Table name: team_members
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  team_id    :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_team_members_on_team_id              (team_id)
#  index_team_members_on_team_id_and_user_id  (team_id,user_id) UNIQUE
#  index_team_members_on_user_id              (user_id)
#
class TeamMember < ApplicationRecord
  belongs_to :user
  belongs_to :team
  validates :user_id, uniqueness: { scope: :team_id }

  after_commit :invalidate_filtered_unread_count_visibility, on: [:create, :destroy]

  after_commit :refresh_account_cache_keys, on: [:create, :destroy]

  private

  def refresh_account_cache_keys
    Team.find_by(id: team_id)&.account&.update_cache_keys(%w[team inbox label])
  end

  def invalidate_filtered_unread_count_visibility
    ::Conversations::UnreadCounts::FilteredCountInvalidator.new(team&.account).user_visibility_changed!(user_id: user_id)
  end
end

TeamMember.include_mod_with('Audit::TeamMember')
