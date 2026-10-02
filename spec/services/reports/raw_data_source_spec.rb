require 'rails_helper'

RSpec.describe Reports::RawDataSource do
  let(:account) { create(:account) }
  let(:team_a) { create(:team, account: account) }
  let(:team_b) { create(:team, account: account) }
  let(:inbox_a) { create(:inbox, account: account, team: team_a) }
  let(:inbox_b) { create(:inbox, account: account, team: team_b) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:administrator) { create(:user, :administrator, account: account) }
  let(:current_time) { Time.current }

  let(:access_scope) do
    account_user = account.account_users.find_by(user: agent)
    Reports::AccessScope.new(account: account, user: agent, account_user: account_user)
  end

  let(:unrestricted_access_scope) do
    account_user = account.account_users.find_by(user: administrator)
    Reports::AccessScope.new(account: account, user: administrator, account_user: account_user)
  end

  def build_source(dimension_type: 'inbox', dimension_id: nil, access_scope: nil, team_id: nil)
    context = {
      account: account,
      metric: nil,
      dimension_type: dimension_type,
      dimension_id: dimension_id,
      scope: nil,
      range: (current_time - 1.day)..(current_time + 1.day),
      group_by: 'day',
      timezone_offset: nil,
      business_hours: false,
      access_scope: access_scope
    }
    context[:team_id] = team_id if team_id
    Reports::DataSource.for(**context)
  end

  before do
    team_a.add_members([agent.id])

    @conversation_a = create(:conversation, account: account, inbox: inbox_a, created_at: current_time)
    @conversation_b = create(:conversation, account: account, inbox: inbox_b, created_at: current_time)

    create(:reporting_event, name: 'conversation_resolved', account: account,
                             conversation: @conversation_a, inbox: inbox_a, created_at: current_time)
    create(:reporting_event, name: 'conversation_resolved', account: account,
                             conversation: @conversation_b, inbox: inbox_b, created_at: current_time)
  end

  describe '#summary' do
    context 'when no access_scope is given (backward compatibility)' do
      it 'summarizes every inbox in the account, exactly like before access scoping existed' do
        results = build_source.summary

        expect(results[inbox_a.id][:conversations_count]).to eq(1)
        expect(results[inbox_b.id][:conversations_count]).to eq(1)
      end
    end

    context 'when the access_scope is unrestricted (admin)' do
      it 'summarizes every inbox, with no regression versus the unscoped behaviour' do
        results = build_source(access_scope: unrestricted_access_scope).summary

        expect(results[inbox_a.id][:conversations_count]).to eq(1)
        expect(results[inbox_b.id][:conversations_count]).to eq(1)
      end
    end

    context 'when the access_scope is restricted to a subset of inboxes' do
      it 'only includes the accessible inboxes in the base dataset, even though the summary breaks down by inbox' do
        results = build_source(access_scope: access_scope).summary

        expect(results.keys).to contain_exactly(inbox_a.id)
        expect(results[inbox_a.id][:conversations_count]).to eq(1)
        expect(results[inbox_a.id][:resolved_conversations_count]).to eq(1)
      end
    end

    context 'when summarizing by agent, the base dataset is still restricted to accessible inboxes' do
      it 'only counts reporting events whose inbox is accessible, regardless of the agent dimension' do
        results = build_source(dimension_type: 'agent', access_scope: access_scope).summary

        # Only the resolution event in inbox_a (accessible) is counted; the one in
        # inbox_b (inaccessible) must not leak into the agent-dimension summary.
        expect(results.values.sum { |row| row[:resolved_conversations_count] }).to eq(1)
      end
    end

    context 'when the restricted agent has no accessible inboxes' do
      it 'returns an empty summary instead of raising or leaking account-wide data' do
        lone_agent = create(:user, account: account, role: :agent)
        lone_account_user = account.account_users.find_by(user: lone_agent)
        lone_scope = Reports::AccessScope.new(account: account, user: lone_agent, account_user: lone_account_user)

        results = build_source(access_scope: lone_scope).summary

        expect(results).to eq({})
      end
    end
  end

  describe '#summary with team_id' do
    before do
      team_b.add_members([agent.id])
      conv_a2 = create(:conversation, account: account, inbox: inbox_a, assignee: agent, created_at: current_time)
      conv_b2 = create(:conversation, account: account, inbox: inbox_b, assignee: agent, created_at: current_time)
      { conv_a2 => [inbox_a, 100, 10, 20], conv_b2 => [inbox_b, 300, 50, 60] }.each do |conversation, (inbox, resolution, first, reply)|
        { 'conversation_resolved' => resolution, 'first_response' => first, 'reply_time' => reply, 'agent_participation' => 0 }.each do |name, value|
          create(:reporting_event, name: name, account: account, conversation: conversation, inbox: inbox,
                                   user: agent, value: value, created_at: current_time)
        end
      end
    end

    it 'sums both teams for the agent without team_id' do
      row = build_source(dimension_type: 'agent').summary[agent.id]

      expect(row[:conversations_count]).to eq(2)
      expect(row[:resolved_conversations_count]).to eq(2)
      expect(row[:participated_conversations_count]).to eq(2)
      expect(row[:avg_resolution_time].to_f).to eq(200.0)
      expect(row[:avg_first_response_time].to_f).to eq(30.0)
      expect(row[:avg_reply_time].to_f).to eq(40.0)
    end

    it 'considers only the given team conversations for the agent with team_id' do
      row = build_source(dimension_type: 'agent', team_id: team_a.id).summary[agent.id]

      expect(row[:conversations_count]).to eq(1)
      expect(row[:resolved_conversations_count]).to eq(1)
      expect(row[:participated_conversations_count]).to eq(1)
      expect(row[:avg_resolution_time].to_f).to eq(100.0)
      expect(row[:avg_first_response_time].to_f).to eq(10.0)
      expect(row[:avg_reply_time].to_f).to eq(20.0)
    end

    it 'returns an empty summary without errors for a team with no conversations' do
      empty_team = create(:team, account: account)

      expect(build_source(dimension_type: 'agent', team_id: empty_team.id).summary).to eq({})
    end

    it 'keeps the inbox and team dimensions unchanged without team_id' do
      expect(build_source(dimension_type: 'inbox').summary.keys).to contain_exactly(inbox_a.id, inbox_b.id)
      expect(build_source(dimension_type: 'team').summary.keys).to contain_exactly(team_a.id, team_b.id)
    end

    it 'works with the team dimension without ambiguous columns' do
      results = build_source(dimension_type: 'team', team_id: team_a.id).summary

      expect(results.keys).to contain_exactly(team_a.id)
      expect(results[team_a.id][:resolved_conversations_count]).to eq(2)
    end
  end
end
