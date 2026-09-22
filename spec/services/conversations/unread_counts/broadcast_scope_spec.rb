require 'rails_helper'

RSpec.describe Conversations::UnreadCounts::BroadcastScope do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }

  describe '#perform' do
    context 'when the conversation is present' do
      it 'returns the account and the directly assigned inbox members' do
        agent = create(:user, account: account, role: :agent)
        create(:inbox_member, inbox: inbox, user: agent)
        event = Events::Base.new('conversation.unread_count_changed', Time.zone.now, conversation: conversation)

        returned_account, members = described_class.new(event).perform

        expect(returned_account).to eq(account)
        expect(members).to contain_exactly(agent)
      end

      it 'includes agents with access via the inbox team, even without direct inbox membership' do
        team = create(:team, account: account)
        inbox.update(team: team)
        team_agent = create(:user, account: account, role: :agent)
        create(:team_member, team: team, user: team_agent)
        event = Events::Base.new('conversation.unread_count_changed', Time.zone.now, conversation: conversation)

        _, members = described_class.new(event).perform

        expect(members).to contain_exactly(team_agent)
      end
    end

    context 'when the conversation is deleted' do
      it 'returns the account and inbox members for the deleted conversation data' do
        agent = create(:user, account: account, role: :agent)
        create(:inbox_member, inbox: inbox, user: agent)
        event = Events::Base.new(
          'conversation.unread_count_changed',
          Time.zone.now,
          conversation: nil,
          conversation_data: { account_id: account.id, inbox_id: inbox.id }
        )

        returned_account, members = described_class.new(event).perform

        expect(returned_account).to eq(account)
        expect(members).to contain_exactly(agent)
      end
    end
  end
end
