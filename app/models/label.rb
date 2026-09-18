# == Schema Information
#
# Table name: labels
#
#  id              :bigint           not null, primary key
#  color           :string           default("#1f93ff"), not null
#  description     :text
#  show_on_sidebar :boolean
#  title           :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint
#  label_group_id  :bigint
#  team_id         :bigint
#
# Indexes
#
#  index_labels_on_account_id            (account_id)
#  index_labels_on_label_group_id        (label_group_id)
#  index_labels_on_team_id               (team_id)
#  index_labels_on_title_and_account_id  (title,account_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (label_group_id => label_groups.id)
#  fk_rails_...  (team_id => teams.id)
#
class Label < ApplicationRecord
  include RegexHelper
  include AccountCacheRevalidator

  belongs_to :account
  belongs_to :team
  belongs_to :label_group, optional: true

  validates :title,
            presence: { message: I18n.t('errors.validations.presence') },
            format: { with: UNICODE_CHARACTER_NUMBER_HYPHEN_UNDERSCORE },
            uniqueness: { scope: :account_id }
  validate :team_belongs_to_same_account
  validate :label_group_belongs_to_same_team

  after_update_commit :update_associated_models
  default_scope { order(:title) }

  before_validation do
    self.title = title.downcase if attribute_present?('title')
  end
  before_validation :apply_team_prefix_to_title

  def conversations
    account.conversations.tagged_with(title)
  end

  def messages
    account.messages.where(conversation_id: conversations.pluck(:id))
  end

  def reporting_events
    account.reporting_events.where(conversation_id: conversations.pluck(:id))
  end

  private

  def update_associated_models
    return unless title_previously_changed?

    Labels::UpdateJob.perform_later(title, title_previously_was, account_id)
  end

  def team_belongs_to_same_account
    return if team.blank?

    errors.add(:team, :invalid) if team.account_id != account_id
  end

  def label_group_belongs_to_same_team
    return if label_group.blank?

    errors.add(:label_group, :invalid) if label_group.team_id != team_id
  end

  # Prefixes the title with the team's slug (e.g. "suporte-quente"),
  # removing the previous team's prefix first when the team changed.
  def apply_team_prefix_to_title
    return if team.blank?

    current_title = strip_previous_team_prefix(title.to_s)
    return if current_title.blank?

    prefix = "#{team.label_prefix}-"
    current_title = "#{prefix}#{current_title}" unless current_title.start_with?(prefix)

    self.title = current_title
  end

  # Removes the previous team's prefix from the title when the team changed.
  # If the previous team no longer exists, the title is returned untouched.
  def strip_previous_team_prefix(current_title)
    return current_title unless team_id_changed? && team_id_was.present?

    previous_team = Team.find_by(id: team_id_was)
    return current_title if previous_team.blank?

    previous_prefix = "#{previous_team.label_prefix}-"
    return current_title unless current_title.start_with?(previous_prefix)

    current_title.delete_prefix(previous_prefix)
  end
end
