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

  def build_source(dimension_type: 'inbox', dimension_id: nil, access_scope: nil)
    Reports::DataSource.for(
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
    )
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
end
