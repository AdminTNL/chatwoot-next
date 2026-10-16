require 'rails_helper'

RSpec.describe ConversationFinder do
  describe '#perform_meta_only' do
    let(:account) { create(:account) }
    let(:agent) { create(:user, account: account, role: :agent) }
    let(:other_agent) { create(:user, account: account, role: :agent) }
    let(:team) { create(:team, account: account) }
    let(:inbox) { create(:inbox, account: account, team: team) }

    before do
      Current.account = account
      create(:team_member, user: agent, team: team)
      account.account_users.find_by(user: agent).update!(
        role: :agent,
        custom_role: create(:custom_role, account: account, permissions: %w[conversation_participating_manage])
      )
    end

    it 'counts participant-filtered conversations once when assigned conversations have multiple participants' do
      assigned_conversation = create(:conversation, account: account, inbox: inbox, assignee: agent)
      participating_conversation = create(:conversation, account: account, inbox: inbox, assignee: other_agent)
      create(:conversation, account: account, inbox: inbox, assignee: other_agent)

      2.times do
        participant = create(:user, account: account, role: :agent)
        create(:team_member, user: participant, team: team)
        create(:conversation_participant, account: account, conversation: assigned_conversation, user: participant)
      end
      create(:conversation_participant, account: account, conversation: participating_conversation, user: agent)

      result = described_class.new(agent, { status: 'open' }).perform_meta_only

      expect(result[:count]).to eq({
                                     unread_conversations_count: 0,
                                     in_progress_conversations_count: 2,
                                     snoozed_conversations_count: 0,
                                     resolved_conversations_count: 0,
                                     all_conversations_count: 2
                                   })
    end
  end
end
