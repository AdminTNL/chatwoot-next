class V2::Reports::OutgoingMessagesCountBuilder
  include DateRangeHelper
  attr_reader :account, :params

  def initialize(account, params)
    @account = account
    @params = params
  end

  def build
    send("build_by_#{params[:group_by]}")
  end

  private

  def access_scope
    params[:access_scope] || Reports::AccessScope::Null.instance
  end

  def base_messages
    messages = account.messages.outgoing.unscope(:order).where(created_at: range)
    return messages if access_scope.unrestricted?

    messages.where(inbox_id: access_scope.inbox_ids)
  end

  def build_by_agent
    counts = base_messages
             .where(sender_type: 'User')
             .where.not(sender_id: nil)
             .group(:sender_id)
             .count

    agents = account.users
    agents = agents.where(id: access_scope.agent_ids) unless access_scope.unrestricted?
    user_names = agents.where(id: counts.keys).index_by(&:id)

    user_names.map do |user_id, user|
      { id: user_id, name: user.name, outgoing_messages_count: counts[user_id] || 0 }
    end
  end

  def build_by_team
    counts = base_messages
             .joins('INNER JOIN conversations ON messages.conversation_id = conversations.id')
             .where.not(conversations: { team_id: nil })
             .group('conversations.team_id')
             .count

    teams = account.teams
    teams = teams.where(id: access_scope.team_ids) unless access_scope.unrestricted?
    team_names = teams.where(id: counts.keys).index_by(&:id)

    team_names.map do |team_id, team|
      { id: team_id, name: team.name, outgoing_messages_count: counts[team_id] || 0 }
    end
  end

  def build_by_inbox
    counts = base_messages
             .group(:inbox_id)
             .count

    inboxes = account.inboxes
    inboxes = inboxes.where(id: access_scope.inbox_ids) unless access_scope.unrestricted?
    inbox_names = inboxes.where(id: counts.keys).index_by(&:id)

    inbox_names.map do |inbox_id, inbox|
      { id: inbox_id, name: inbox.name, outgoing_messages_count: counts[inbox_id] || 0 }
    end
  end

  def build_by_label
    counts = base_messages
             .joins('INNER JOIN conversations ON messages.conversation_id = conversations.id')
             .joins("INNER JOIN taggings ON taggings.taggable_id = conversations.id
                     AND taggings.taggable_type = 'Conversation' AND taggings.context = 'labels'")
             .joins('INNER JOIN tags ON tags.id = taggings.tag_id')
             .group('tags.name')
             .count

    labels = account.labels
    labels = labels.where(id: access_scope.label_ids) unless access_scope.unrestricted?
    label_by_title = labels.where(title: counts.keys).index_by(&:title)

    label_by_title.map do |label_name, label|
      { id: label.id, name: label_name, outgoing_messages_count: counts[label_name] || 0 }
    end
  end
end
