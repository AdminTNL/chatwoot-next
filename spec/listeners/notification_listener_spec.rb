require 'rails_helper'
describe NotificationListener do
  let(:listener) { described_class.instance }
  let!(:account) { create(:account) }
  let!(:user) { create(:user, account: account) }
  let!(:first_agent) { create(:user, account: account) }
  let!(:inbox) { create(:inbox, account: account) }
  let!(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: user) }

  describe 'message_created' do
    let(:event_name) { :'message.created' }

    before do
      notification_setting = first_agent.notification_settings.find_by(account_id: account.id)
      notification_setting.selected_email_flags = [:email_conversation_mention]
      notification_setting.selected_push_flags = []
      notification_setting.save!
    end

    it 'will call mention service' do
      mention_service = instance_double(Messages::MentionService)
      allow(Messages::MentionService).to receive(:new).and_return(mention_service)
      allow(mention_service).to receive(:perform)

      create(:inbox_member, user: first_agent, inbox: inbox)
      conversation.reload

      message = build(
        :message,
        conversation: conversation,
        account: account,
        content: "hi [#{first_agent.name}](mention://user/#{first_agent.id}/#{first_agent.name})",
        private: true
      )

      expect(mention_service).to receive(:perform)
      event = Events::Base.new(event_name, Time.zone.now, message: message)
      listener.message_created(event)
    end

    it 'will call new message notification service' do
      notification_service = instance_double(Messages::NewMessageNotificationService)
      allow(Messages::NewMessageNotificationService).to receive(:new).and_return(notification_service)
      allow(notification_service).to receive(:perform)

      create(:inbox_member, user: first_agent, inbox: inbox)
      conversation.reload

      message = build(
        :message,
        conversation: conversation,
        account: account,
        content: 'hi',
        private: true
      )

      expect(notification_service).to receive(:perform)
      event = Events::Base.new(event_name, Time.zone.now, message: message)
      listener.message_created(event)
    end

    context 'when message content is empty' do
      it 'will be processed correctly' do
        builder = double
        allow(NotificationBuilder).to receive(:new).and_return(builder)
        allow(builder).to receive(:perform)

        create(:inbox_member, user: first_agent, inbox: inbox)
        conversation.reload

        message = build(
          :message,
          conversation: conversation,
          account: account,
          content: nil,
          private: true
        )

        event = Events::Base.new(event_name, Time.zone.now, message: message)
        # want to validate message_created doesnt throw an error
        expect { listener.message_created(event) }.not_to raise_error
      end
    end
  end

  # integration tests to ensure that the order mention service and new message notification service are called in the correct order
  describe 'message_created - mentions, participation & assignment integration' do
    let(:event_name) { :'message.created' }

    it 'will not create duplicate new message notification for the same user for mentions participation & assignment' do
      create(:inbox_member, user: first_agent, inbox: inbox)
      conversation.update(assignee: first_agent)

      message = build(
        :message,
        conversation: conversation,
        account: account,
        content: "hi [#{first_agent.name}](mention://user/#{first_agent.id}/#{first_agent.name})",
        private: true
      )
      event = Events::Base.new(event_name, Time.zone.now, message: message)
      listener.message_created(event)

      expect(first_agent.notifications.count).to eq(1)
      expect(first_agent.notifications.first.notification_type).to eq('conversation_mention')
    end

    it 'will create a mention notification when a user is mentioned in a private note' do
      create(:inbox_member, user: first_agent, inbox: inbox)

      message = build(
        :message,
        conversation: conversation,
        account: account,
        content: "hey [#{first_agent.name}](mention://user/#{first_agent.id}/#{first_agent.name})",
        private: true
      )
      event = Events::Base.new(event_name, Time.zone.now, message: message)
      listener.message_created(event)

      expect(first_agent.notifications.count).to eq(1)
      expect(first_agent.notifications.first.notification_type).to eq('conversation_mention')
    end

    it 'will not create new message notifications for private messages without mentions' do
      create(:inbox_member, user: first_agent, inbox: inbox)
      conversation.update(assignee: first_agent)
      # participants is created by async job. so creating it directly for testcase
      conversation.conversation_participants.first_or_create(user: first_agent)

      message = build(
        :message,
        conversation: conversation,
        account: account,
        content: 'hi',
        private: true
      )

      event = Events::Base.new(event_name, Time.zone.now, message: message)
      listener.message_created(event)

      expect(conversation.conversation_participants.map(&:user)).to include(first_agent)
      expect(first_agent.notifications.count).to eq(0)
    end
  end

  shared_examples 'conversation delivery' do |listener_method, event_name|
    let(:team) { create(:team, account: account) }
    let(:team_inbox) { create(:inbox, account: account, team: team) }
    let(:team_conversation) { create(:conversation, account: account, inbox: team_inbox) }
    let(:team_agents) { create_list(:user, 3, account: account) }
    let(:event) { Events::Base.new(event_name, Time.zone.now, conversation: team_conversation) }

    def enable_push(agent)
      setting = agent.notification_settings.find_by(account_id: account.id)
      setting.selected_push_flags = [:push_conversation_creation]
      setting.selected_email_flags = []
      setting.save!
    end

    before do
      team_agents.each { |agent| create(:team_member, team: team, user: agent) }
      team_conversation
    end

    it 'does not persist notifications and enqueues delivery only for subscribed team members' do
      enable_push(team_agents.first)

      expect { listener.public_send(listener_method, event) }
        .to have_enqueued_job(Notification::DeliveryOnlyJob).once
                                                            .with(user_id: team_agents.first.id, account_id: account.id,
                                                                  conversation_id: team_conversation.id,
                                                                  notification_type: 'conversation_creation')
      expect(Notification.where(notification_type: :conversation_creation).count).to eq(0)
    end

    it 'does not notify members of another team nor administrators outside the team' do
      other_team_agent = create(:user, account: account)
      create(:team_member, team: create(:team, account: account), user: other_team_agent)
      admin = create(:user, account: account, role: :administrator)
      [other_team_agent, admin].each { |agent| enable_push(agent) }

      expect { listener.public_send(listener_method, event) }.not_to have_enqueued_job(Notification::DeliveryOnlyJob)
    end

    it 'still notifies agents with legacy inbox membership' do
      legacy_agent = create(:user, account: account)
      create(:inbox_member, user: legacy_agent, inbox: team_inbox)
      enable_push(legacy_agent)

      expect { listener.public_send(listener_method, event) }
        .to have_enqueued_job(Notification::DeliveryOnlyJob).with(hash_including(user_id: legacy_agent.id))
    end

    it 'keeps an unread mention untouched' do
      agent = team_agents.first
      enable_push(agent)
      mention = create(:notification, account: account, user: agent, notification_type: :conversation_mention,
                                      primary_actor: team_conversation)

      perform_enqueued_jobs { listener.public_send(listener_method, event) }

      expect(Notification.exists?(mention.id)).to be(true)
    end
  end

  describe 'conversation_created' do
    include ActiveJob::TestHelper

    it_behaves_like 'conversation delivery', :conversation_created, :'conversation.created'
  end

  describe 'conversation_bot_handoff' do
    include ActiveJob::TestHelper

    it_behaves_like 'conversation delivery', :conversation_bot_handoff, :'conversation.bot_handoff'
  end

  describe 'assignee_changed' do
    let(:event_name) { :'conversation.assignee_changed' }

    it 'does not create any notification' do
      create(:inbox_member, user: user, inbox: inbox)
      event = Events::Base.new(event_name, Time.zone.now, conversation: conversation, data: { notifiable_assignee_change: true })

      expect { listener.assignee_changed(event) }.not_to(change(Notification, :count))
    end
  end
end
