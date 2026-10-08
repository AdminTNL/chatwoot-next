require 'rails_helper'

RSpec.describe Notifications::ObsoleteCleanupService do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account) }
  let(:team) { create(:team, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: create(:inbox, account: account, team: team)) }

  def notify(type, user: agent, conv: conversation)
    create(:notification, user: user, account: account, primary_actor: conv, notification_type: type)
  end

  before { create(:team_member, team: team, user: agent) }

  it 'deletes types 1, 2 and 3 and keeps 4 to 8 with access' do
    removed = %w[conversation_creation conversation_assignment assigned_conversation_new_message].map { |t| notify(t) }
    kept = %w[conversation_mention participating_conversation_new_message sla_missed_first_response
              sla_missed_next_response sla_missed_resolution].map { |t| notify(t) }

    described_class.new.perform

    expect(Notification.where(id: removed.map(&:id))).to be_empty
    expect(Notification.where(id: kept.map(&:id)).count).to eq(5)
  end

  it 'deletes mention and participation notifications without access' do
    outsider = create(:user, account: account)
    mention = notify('conversation_mention', user: outsider)
    participation = notify('participating_conversation_new_message', user: outsider)

    described_class.new.perform

    expect(Notification.where(id: [mention.id, participation.id])).to be_empty
  end

  it 'spares administrators without team or inbox membership' do
    admin = create(:user, account: account, role: :administrator)
    n = notify('conversation_mention', user: admin)

    described_class.new.perform

    expect(Notification.exists?(n.id)).to be(true)
  end

  it 'clears assignment bits from notification flags' do
    s1 = agent.notification_settings.find_by(account_id: account.id)
    s1.update_columns(push_flags: 2, email_flags: 2) # rubocop:disable Rails/SkipsModelValidations
    other = create(:user, account: account).notification_settings.find_by(account_id: account.id)
    other.update_columns(push_flags: 2 | 8, email_flags: 4 | 8) # rubocop:disable Rails/SkipsModelValidations

    described_class.new.perform

    expect(s1.reload.push_flags).to eq(0)
    expect(s1.email_flags).to eq(0)
    expect(other.reload.push_flags).to eq(8)
    expect(other.email_flags).to eq(8)
  end
end
