require 'rails_helper'

RSpec.describe Conversations::PermissionFilterService do
  let(:account) { create(:account) }
  let!(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let!(:another_conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let!(:inbox) { create(:inbox, account: account) }

  # This inbox_member is used to establish the agent's access to the inbox
  before { create(:inbox_member, user: agent, inbox: inbox) }

  describe '#perform' do
    context 'when user is an administrator' do
      it 'returns all conversations' do
        result = described_class.new(
          account.conversations,
          admin,
          account
        ).perform

        expect(result).to include(conversation)
        expect(result).to include(another_conversation)
        expect(result.count).to eq(2)
      end
    end

    context 'when user is an agent' do
      it 'returns all conversations with no further filtering' do
        inbox_ids = agent.inboxes.where(account_id: account.id).pluck(:id)

        # The base implementation returns all conversations
        # expecting the caller to filter by assigned inboxes
        result = described_class.new(
          account.conversations.where(inbox_id: inbox_ids),
          agent,
          account
        ).perform

        expect(result).to include(conversation)
        expect(result).to include(another_conversation)
        expect(result.count).to eq(2)
      end
    end

    context 'when the agent has no inbox_members row but belongs to the inbox team' do
      let(:team) { create(:team, account: account) }
      let(:team_only_agent) { create(:user, account: account, role: :agent) }

      before do
        create(:team_member, user: team_only_agent, team: team)
        inbox.update!(team: team)
      end

      it 'includes conversations of that inbox, including ones created before the team association (retroactive)' do
        result = described_class.new(
          account.conversations,
          team_only_agent,
          account
        ).perform

        expect(result).to include(conversation)
        expect(result).to include(another_conversation)
      end
    end

    context 'when the agent belongs to a team that does not own the inbox' do
      let(:other_team) { create(:team, account: account) }
      let(:outsider_agent) { create(:user, account: account, role: :agent) }

      before { create(:team_member, user: outsider_agent, team: other_team) }

      it 'excludes conversations of the inbox' do
        result = described_class.new(
          account.conversations,
          outsider_agent,
          account
        ).perform

        expect(result).not_to include(conversation)
        expect(result).not_to include(another_conversation)
      end
    end
  end
end
