json.data do
  json.meta do
    json.mine_count @conversations_count[:mine_count]
    json.assigned_count @conversations_count[:assigned_count]
    json.unassigned_count @conversations_count[:unassigned_count]
    json.all_count @conversations_count[:all_count]
    json.unread_conversations_count @conversations_count[:unread_conversations_count]
    json.in_progress_conversations_count @conversations_count[:in_progress_conversations_count]
    json.snoozed_conversations_count @conversations_count[:snoozed_conversations_count]
    json.resolved_conversations_count @conversations_count[:resolved_conversations_count]
    json.all_conversations_count @conversations_count[:all_conversations_count]
  end
  json.payload do
    json.array! @conversations do |conversation|
      json.partial! 'api/v1/conversations/partials/conversation', formats: [:json], conversation: conversation
    end
  end
end
