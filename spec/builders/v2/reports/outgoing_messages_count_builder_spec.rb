require 'rails_helper'

RSpec.describe V2::Reports::OutgoingMessagesCountBuilder do
  let(:account) { create(:account) }
  let(:team_a) { create(:team, account: account) }
  let(:team_b) { create(:team, account: account) }
  let(:inbox_a) { create(:inbox, account: account, team: team_a) }
  let(:inbox_b) { create(:inbox, account: account, team: team_b) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:since_epoch) { 1.week.ago.to_i.to_s }
  let(:until_epoch) { 1.day.from_now.to_i.to_s }

  let(:access_scope) do
    Reports::AccessScope.new(account: account, user: agent, account_user: account.account_users.find_by(user: agent))
  end

  def build_params(group_by, extra = {})
    { group_by: group_by, since: since_epoch, until: until_epoch, access_scope: access_scope }.merge(extra)
  end

  before do
    team_a.add_members([agent.id])

    conv_a = create(:conversation, account: account, inbox: inbox_a, assignee: agent)
    conv_b = create(:conversation, account: account, inbox: inbox_b, assignee: agent)

    create(:message, account: account, conversation: conv_a, inbox: inbox_a, message_type: :outgoing, sender: agent)
    create(:message, account: account, conversation: conv_b, inbox: inbox_b, message_type: :outgoing, sender: agent)
  end

  describe '#build' do
    it 'only counts outgoing messages for agents grouped within accessible inboxes' do
      builder = described_class.new(account, build_params('agent'))
      data = builder.build

      agent_entry = data.find { |e| e[:id] == agent.id }
      expect(agent_entry[:outgoing_messages_count]).to eq(1)
    end

    it 'only lists accessible inboxes when grouping by inbox' do
      builder = described_class.new(account, build_params('inbox'))
      data = builder.build

      expect(data.pluck(:id)).to eq([inbox_a.id])
    end

    context 'when no access_scope is given (backward compatibility)' do
      it 'counts messages account-wide, exactly like before access scoping existed' do
        builder = described_class.new(account, { group_by: 'agent', since: since_epoch, until: until_epoch })
        data = builder.build

        agent_entry = data.find { |e| e[:id] == agent.id }
        expect(agent_entry[:outgoing_messages_count]).to eq(2)
      end
    end

    context 'when the access_scope is unrestricted (administrator)' do
      let(:administrator) { create(:user, :administrator, account: account) }
      let(:access_scope) do
        Reports::AccessScope.new(account: account, user: administrator, account_user: account.account_users.find_by(user: administrator))
      end

      it 'counts messages account-wide, with no regression versus the unscoped behaviour' do
        builder = described_class.new(account, build_params('agent'))
        data = builder.build

        agent_entry = data.find { |e| e[:id] == agent.id }
        expect(agent_entry[:outgoing_messages_count]).to eq(2)
      end
    end

    context 'when the agent has no accessible inboxes at all' do
      let(:lone_agent) { create(:user, account: account, role: :agent) }
      let(:access_scope) do
        Reports::AccessScope.new(account: account, user: lone_agent, account_user: account.account_users.find_by(user: lone_agent))
      end

      it 'returns an empty result instead of raising or leaking account-wide data' do
        builder = described_class.new(account, build_params('agent'))
        expect(builder.build).to eq([])
      end
    end
  end
end
