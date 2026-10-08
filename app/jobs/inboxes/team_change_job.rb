class Inboxes::TeamChangeJob < ApplicationJob
  queue_as :default

  # rubocop:disable Rails/SkipsModelValidations
  def perform(inbox_id:, previous_team_id:, new_team_id:) # rubocop:disable Lint/UnusedMethodArgument
    inbox = Inbox.find_by(id: inbox_id)
    return if inbox.blank?

    @inbox = inbox
    @account = inbox.account
    @previous_team = previous_team_id.present? ? @account.teams.find_by(id: previous_team_id) : nil
    @new_team = inbox.team_id.present? ? @account.teams.find_by(id: inbox.team_id) : nil

    migrate_conversations
    clear_assignees_without_access
    remove_previous_team_labels(previous_team_id)
    cleanup_notifications
    invalidate_caches
  end

  private

  def inbox_conversations
    @account.conversations.where(inbox_id: @inbox.id)
  end

  def migrate_conversations
    scope = inbox_conversations
    scope = @new_team.present? ? scope.where(team_id: nil).or(scope.where.not(team_id: @new_team.id)) : scope.where.not(team_id: nil)
    scope.in_batches { |batch| batch.update_all(team_id: @new_team&.id, updated_at: Time.current) }
  end

  def clear_assignees_without_access
    allowed_ids = (new_team_member_ids + @account.administrators.pluck(:id)).uniq
    inbox_conversations.where.not(assignee_id: nil).where.not(assignee_id: allowed_ids).in_batches do |batch|
      batch.update_all(assignee_id: nil, updated_at: Time.current)
    end
  end

  def remove_previous_team_labels(previous_team_id)
    return if previous_team_id.blank?

    titles = @account.labels.where(team_id: previous_team_id).pluck(:title)
    return if titles.blank?

    writer = Labels::TaggingWriter.new(account: @account)
    conversation_ids = inbox_conversations.tagged_with(titles, any: true).pluck(:id).uniq
    @account.conversations.where(id: conversation_ids).find_each do |conversation|
      writer.apply(record: conversation, added_labels: [], removed_labels: titles)
    end
  end

  def cleanup_notifications
    return if previous_team_member_ids.blank?

    Notifications::AccessCleanupService.new(account: @account, user_ids: previous_team_member_ids).perform
  end

  def invalidate_caches
    Conversations::UnreadCounts::Store.clear_account!(@account.id)
    invalidator = Conversations::UnreadCounts::FilteredCountInvalidator.new(@account)
    invalidator.conversation_changed!
    invalidator.users_visibility_changed!(user_ids: (previous_team_member_ids + new_team_member_ids).uniq)
    @account.update_cache_keys(%w[inbox label])
  end

  def previous_team_member_ids
    @previous_team_member_ids ||= @previous_team.present? ? @previous_team.members.pluck(:id) : []
  end

  def new_team_member_ids
    @new_team_member_ids ||= @new_team.present? ? @new_team.members.pluck(:id) : []
  end
  # rubocop:enable Rails/SkipsModelValidations
end
