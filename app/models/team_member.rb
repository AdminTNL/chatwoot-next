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

  after_destroy_commit :enqueue_access_cleanup

  private

  # Com Team#destroy (destroy_async) o time já não existe quando o membro é apagado;
  # sem account_id disponível, a limpeza é ignorada.
  def enqueue_access_cleanup
    account_id = Team.find_by(id: team_id)&.account_id
    return if account_id.blank?

    Notification::AccessCleanupJob.perform_later(account_id, [user_id])
  end

  def refresh_account_cache_keys
    Team.find_by(id: team_id)&.account&.update_cache_keys(%w[team inbox label])
  end

  def invalidate_filtered_unread_count_visibility
    ::Conversations::UnreadCounts::FilteredCountInvalidator.new(team&.account).user_visibility_changed!(user_id: user_id)
  end
end

TeamMember.include_mod_with('Audit::TeamMember')
