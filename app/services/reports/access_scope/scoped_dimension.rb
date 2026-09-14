# frozen_string_literal: true

# Thin decorator around an object that responds to `conversations`,
# `messages` and `reporting_events` (Account, Inbox, User, Label or
# Team), narrowing those three associations to a set of inbox ids.
# Everything else is delegated to the wrapped object untouched.
class Reports::AccessScope::ScopedDimension
  def initialize(target, inbox_ids)
    @target = target
    @inbox_ids = inbox_ids
  end

  def conversations
    @target.conversations.where(inbox_id: @inbox_ids)
  end

  def messages
    @target.messages.where(inbox_id: @inbox_ids)
  end

  def reporting_events
    @target.reporting_events.where(inbox_id: @inbox_ids)
  end

  def method_missing(name, *, &)
    @target.public_send(name, *, &)
  end

  def respond_to_missing?(name, include_private = false)
    @target.respond_to?(name, include_private) || super
  end
end
