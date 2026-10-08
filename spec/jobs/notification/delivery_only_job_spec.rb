require 'rails_helper'

RSpec.describe Notification::DeliveryOnlyJob do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:push_service) { instance_double(Notification::PushNotificationService, perform: true) }
  let(:email_service) { instance_double(Notification::EmailNotificationService, perform: true) }
  let(:params) do
    { user_id: user.id, account_id: account.id, conversation_id: conversation.id, notification_type: 'conversation_creation' }
  end

  before do
    allow(Notification::PushNotificationService).to receive(:new).and_return(push_service)
    allow(Notification::EmailNotificationService).to receive(:new).and_return(email_service)
    setting = user.notification_settings.find_by(account_id: account.id)
    setting.selected_push_flags = [:push_conversation_creation]
    setting.selected_email_flags = []
    setting.save!
  end

  it 'delivers push with an unsaved notification and skips email without the flag' do
    expect { described_class.perform_now(**params) }.not_to(change(Notification, :count))

    expect(Notification::PushNotificationService).to have_received(:new) do |args|
      expect(args[:notification]).to be_new_record
      expect(args[:notification].primary_actor).to eq(conversation)
    end
    expect(Notification::EmailNotificationService).not_to have_received(:new)
  end

  it 'also delivers email when the email flag is on' do
    setting = user.notification_settings.find_by(account_id: account.id)
    setting.selected_email_flags = [:email_conversation_creation]
    setting.save!

    described_class.perform_now(**params)

    expect(email_service).to have_received(:perform)
  end

  it 'exits silently when the conversation no longer exists' do
    conversation.destroy!

    expect { described_class.perform_now(**params) }.not_to raise_error
    expect(Notification::PushNotificationService).not_to have_received(:new)
  end
end
