class ReportingEventListener < BaseListener
  include ReportingEventHelper

  def conversation_resolved(event)
    conversation = extract_conversation_and_account(event)[0]
    event_end_time = event.timestamp
    time_to_resolve = event_end_time.to_i - conversation.created_at.to_i

    # Must be computed before the conversation_resolved event below is saved, otherwise the
    # lookback in cycle_start_for would find that very event (its event_end_time also satisfies
    # <= event_end_time) and use it as the "previous" resolution, collapsing the cycle to zero width.
    cycle_start = cycle_start_for(conversation, event_end_time)

    reporting_event = ReportingEvent.new(
      name: 'conversation_resolved',
      value: time_to_resolve,
      value_in_business_hours: business_hours(conversation.inbox, conversation.created_at, event_end_time),
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      user_id: resolved_by_user_id(event, conversation),
      conversation_id: conversation.id,
      event_start_time: conversation.created_at,
      event_end_time: event_end_time
    )

    create_bot_resolved_event(conversation, reporting_event)
    reporting_event.save!
    safe_rollup(reporting_event)

    create_agent_participation_events(conversation, cycle_start, event_end_time)
  end

  def first_reply_created(event)
    message = extract_message_and_account(event)[0]
    conversation = message.conversation
    first_response_time = message.created_at.to_i - last_non_human_activity(conversation).to_i

    reporting_event = ReportingEvent.new(
      name: 'first_response',
      value: first_response_time,
      value_in_business_hours: business_hours(conversation.inbox, last_non_human_activity(conversation),
                                              message.created_at),
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      user_id: message.sender_id,
      conversation_id: conversation.id,
      event_start_time: last_non_human_activity(conversation),
      event_end_time: message.created_at
    )

    reporting_event.save!
    safe_rollup(reporting_event)
  end

  def reply_created(event)
    message = extract_message_and_account(event)[0]
    conversation = message.conversation
    waiting_since = event.data[:waiting_since]

    return if waiting_since.blank?

    # When waiting_since is nil, set reply_time to 0
    reply_time = message.created_at.to_i - waiting_since.to_i

    reporting_event = ReportingEvent.new(
      name: 'reply_time',
      value: reply_time,
      value_in_business_hours: business_hours(conversation.inbox, waiting_since, message.created_at),
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      user_id: message.sender_id,
      conversation_id: conversation.id,
      event_start_time: waiting_since,
      event_end_time: message.created_at
    )
    reporting_event.save!
    safe_rollup(reporting_event)
  end

  def conversation_bot_handoff(event)
    conversation = extract_conversation_and_account(event)[0]
    event_end_time = event.timestamp

    # Best-effort guard: raw report reads count bot handoffs with DISTINCT conversation_id,
    # while rollup counts assume one conversation_bot_handoff event per conversation.
    # That uniqueness is not currently enforced at the database level.
    bot_handoff_event = ReportingEvent.find_by(conversation_id: conversation.id, name: 'conversation_bot_handoff')
    return if bot_handoff_event.present?

    time_to_handoff = event_end_time.to_i - conversation.created_at.to_i

    reporting_event = ReportingEvent.new(
      name: 'conversation_bot_handoff',
      value: time_to_handoff,
      value_in_business_hours: business_hours(conversation.inbox, conversation.created_at, event_end_time),
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      user_id: conversation.assignee_id,
      conversation_id: conversation.id,
      event_start_time: conversation.created_at,
      event_end_time: event_end_time
    )
    reporting_event.save!
    safe_rollup(reporting_event)
  end

  def conversation_captain_inference_resolved(event)
    create_captain_inference_event(event, 'conversation_captain_inference_resolved')
  end

  def conversation_captain_inference_handoff(event)
    create_captain_inference_event(event, 'conversation_captain_inference_handoff')
  end

  def conversation_opened(event)
    conversation = extract_conversation_and_account(event)[0]
    event_end_time = event.timestamp

    last_resolved_event = last_resolved_event_for(conversation, event_end_time)

    # For first-time openings, value is 0
    # For reopenings, calculate time since resolution
    if last_resolved_event
      time_since_resolved = event_end_time.to_i - last_resolved_event.event_end_time.to_i
      business_hours_value = business_hours(conversation.inbox, last_resolved_event.event_end_time, event_end_time)
      start_time = last_resolved_event.event_end_time
    else
      time_since_resolved = 0
      business_hours_value = 0
      start_time = conversation.created_at
    end

    create_conversation_opened_event(conversation, time_since_resolved, business_hours_value, start_time, event_end_time)
  end

  private

  # Who actually resolved the conversation, not who it happens to be assigned to.
  # Falls back through the chain below when no human agent is identifiable on the
  # event itself (automation, auto-close, bot/Captain resolutions, etc.):
  #   event.data[:current_user] (only if a User) -> event.data[:performed_by] (only if a User) -> conversation.assignee_id -> nil
  #
  # Note: this reads event.data[:performed_by], not a live Current.executed_by call.
  # This listener runs inside EventDispatcherJob, off the request thread that set
  # Current.executed_by, so re-reading Current here would not see that value (same
  # thread-boundary reasoning as event.data[:current_user] above). performed_by is
  # already captured into the payload in Conversation#dispatcher_dispatch, so we reuse it.
  def resolved_by_user_id(event, conversation)
    current_user = event.data[:current_user]
    return current_user.id if current_user.is_a?(User)

    executed_by = event.data[:performed_by]
    return executed_by.id if executed_by.is_a?(User)

    conversation.assignee_id
  end

  # Most recent conversation_resolved event for this conversation at or before event_end_time,
  # i.e. the resolution that closed the previous care cycle. nil means there isn't one yet
  # (this is the conversation's first cycle). Shared lookback between conversation_opened and
  # conversation_resolved (via cycle_start_for).
  def last_resolved_event_for(conversation, event_end_time)
    ReportingEvent.where(
      conversation_id: conversation.id,
      name: 'conversation_resolved'
    ).where('event_end_time <= ?', event_end_time).order(event_end_time: :desc).first
  end

  # Start of the current care cycle: the event_end_time of the previous conversation_resolved
  # event, or conversation.created_at when this is the first cycle.
  def cycle_start_for(conversation, event_end_time)
    last_resolved_event_for(conversation, event_end_time)&.event_end_time || conversation.created_at
  end

  # One agent_participation event per distinct agent who sent at least one real outgoing
  # message (not a private note, not a bot/Captain message) during the care cycle that just
  # ended. A message that started as an AI suggestion counts as the sending agent's own message
  # once approved and sent, no special-casing needed since it is still sender_type: 'User'.
  def create_agent_participation_events(conversation, cycle_start, event_end_time)
    agent_ids = conversation.messages
                            .where(message_type: :outgoing, private: false, sender_type: 'User')
                            .where(created_at: cycle_start..event_end_time)
                            .unscope(:order).distinct.pluck(:sender_id)

    agent_ids.each do |sender_id|
      ReportingEvent.create!(name: 'agent_participation', value: 0, account_id: conversation.account_id,
                             inbox_id: conversation.inbox_id, user_id: sender_id, conversation_id: conversation.id)
    end
  end

  def create_conversation_opened_event(conversation, time_since_resolved, business_hours_value, start_time, event_end_time)
    reporting_event = ReportingEvent.new(
      name: 'conversation_opened',
      value: time_since_resolved,
      value_in_business_hours: business_hours_value,
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      user_id: conversation.assignee_id,
      conversation_id: conversation.id,
      event_start_time: start_time,
      event_end_time: event_end_time
    )
    reporting_event.save!
  end

  def create_captain_inference_event(event, event_name)
    conversation = extract_conversation_and_account(event)[0]
    time_to_event = event.timestamp.to_i - conversation.created_at.to_i

    ReportingEvent.create!(
      name: event_name,
      value: time_to_event,
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      user_id: conversation.assignee_id,
      conversation_id: conversation.id,
      event_start_time: conversation.created_at,
      event_end_time: event.timestamp
    )
  end

  def create_bot_resolved_event(conversation, reporting_event)
    return unless conversation.inbox.active_bot?
    # We don't want to create a bot_resolved event if there is user interaction on the conversation
    return if conversation.messages.exists?(message_type: :outgoing, sender_type: 'User')

    bot_resolved_event = reporting_event.dup
    bot_resolved_event.name = 'conversation_bot_resolved'
    bot_resolved_event.save!
    safe_rollup(bot_resolved_event)
  end

  def safe_rollup(reporting_event)
    # Rollups are derived from the raw reporting event. If a transient rollup write
    # failure bubbles out here, Sidekiq retries the dispatcher job and can insert the
    # same raw event again. That can temporarily under-report rollups, but the source
    # event is preserved and rollup data can be rebuilt or re-applied later.
    ReportingEvents::RollupService.perform(reporting_event)
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: reporting_event.account).capture_exception
  end
end
