json.meta do
  json.unread_conversations_count @conversations_count[:unread_conversations_count]
  json.in_progress_conversations_count @conversations_count[:in_progress_conversations_count]
  json.snoozed_conversations_count @conversations_count[:snoozed_conversations_count]
  json.resolved_conversations_count @conversations_count[:resolved_conversations_count]
  json.all_conversations_count @conversations_count[:all_conversations_count]
end
