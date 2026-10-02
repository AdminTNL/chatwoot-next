require 'rails_helper'

RSpec.describe V2::Reports::AgentSummaryBuilder do
  let(:account) { create(:account) }
  let(:user1) { create(:user, account: account, role: :agent) }
  let(:user2) { create(:user, account: account, role: :agent) }

  let(:params) do
    {
      business_hours: business_hours,
      since: 1.week.ago.beginning_of_day,
      until: Time.current.end_of_day
    }
  end
  let(:builder) { described_class.new(account: account, params: params) }

  describe '#build' do
    context 'when there is team data' do
      before do
        c1 = create(:conversation, account: account, assignee: user1, created_at: Time.current)
        c2 = create(:conversation, account: account, assignee: user2, created_at: Time.current)
        create(
          :reporting_event,
          account: account,
          conversation: c2,
          user: user2,
          name: 'conversation_resolved',
          value: 50,
          value_in_business_hours: 40,
          created_at: Time.current
        )
        create(
          :reporting_event,
          account: account,
          conversation: c1,
          user: user1,
          name: 'first_response',
          value: 20,
          value_in_business_hours: 10,
          created_at: Time.current
        )
        create(
          :reporting_event,
          account: account,
          conversation: c1,
          user: user1,
          name: 'reply_time',
          value: 30,
          value_in_business_hours: 15,
          created_at: Time.current
        )
        create(
          :reporting_event,
          account: account,
          conversation: c1,
          user: user1,
          name: 'reply_time',
          value: 40,
          value_in_business_hours: 25,
          created_at: Time.current
        )
      end

      context 'when business hours is disabled' do
        let(:business_hours) { false }

        it 'returns the correct team stats' do
          report = builder.build

          expect(report).to eq(
            [
              {
                id: user1.id,
                conversations_count: 1,
                resolved_conversations_count: 0,
                avg_resolution_time: nil,
                avg_first_response_time: 20.0,
                avg_reply_time: 35.0,
                participated_conversations_count: 0
              },
              {
                id: user2.id,
                conversations_count: 1,
                resolved_conversations_count: 1,
                avg_resolution_time: 50.0,
                avg_first_response_time: nil,
                avg_reply_time: nil,
                participated_conversations_count: 0
              }
            ]
          )
        end
      end

      context 'when business hours is enabled' do
        let(:business_hours) { true }

        it 'uses business hours values' do
          report = builder.build

          expect(report).to eq(
            [
              {
                id: user1.id,
                conversations_count: 1,
                resolved_conversations_count: 0,
                avg_resolution_time: nil,
                avg_first_response_time: 10.0,
                avg_reply_time: 20.0,
                participated_conversations_count: 0
              },
              {
                id: user2.id,
                conversations_count: 1,
                resolved_conversations_count: 1,
                avg_resolution_time: 40.0,
                avg_first_response_time: nil,
                avg_reply_time: nil,
                participated_conversations_count: 0
              }
            ]
          )
        end
      end
    end

    context 'when there is no team data' do
      let!(:new_user) { create(:user, account: account, role: :agent) }
      let(:business_hours) { false }

      it 'returns zero values' do
        report = builder.build

        expect(report).to include(
          {
            id: new_user.id,
            conversations_count: 0,
            resolved_conversations_count: 0,
            avg_resolution_time: nil,
            avg_first_response_time: nil,
            avg_reply_time: nil,
            participated_conversations_count: 0
          }
        )
      end
    end

    context 'when there is agent participation data' do
      let(:business_hours) { false }

      it 'counts participated conversations, deduplicating by conversation for the same agent' do
        c1 = create(:conversation, account: account, assignee: user1, created_at: Time.current)
        c2 = create(:conversation, account: account, assignee: user1, created_at: Time.current)

        # Same agent, same conversation, two separate care cycles (e.g. reopened and resolved
        # again) - must still count as a single participated conversation.
        create(:reporting_event, account: account, conversation: c1, user: user1, name: 'agent_participation', value: 0, created_at: Time.current)
        create(:reporting_event, account: account, conversation: c1, user: user1, name: 'agent_participation', value: 0, created_at: Time.current)

        # Different conversation, same agent - counts as a second participated conversation.
        create(:reporting_event, account: account, conversation: c2, user: user1, name: 'agent_participation', value: 0, created_at: Time.current)

        report = builder.build
        user1_stats = report.find { |stat| stat[:id] == user1.id }

        expect(user1_stats[:participated_conversations_count]).to eq 2
      end
    end

    context 'when filtering by team_id' do
      let(:business_hours) { false }
      let(:team_a) { create(:team, account: account) }
      let(:team_b) { create(:team, account: account) }
      let(:inbox_a) { create(:inbox, account: account, team: team_a) }
      let(:inbox_b) { create(:inbox, account: account, team: team_b) }

      before do
        team_a.add_members([user1.id])
        team_b.add_members([user1.id])
        ca = create(:conversation, account: account, inbox: inbox_a, assignee: user1, created_at: Time.current)
        cb = create(:conversation, account: account, inbox: inbox_b, assignee: user1, created_at: Time.current)
        create(:reporting_event, account: account, conversation: ca, inbox: inbox_a, user: user1,
                                 name: 'conversation_resolved', value: 10, created_at: Time.current)
        create(:reporting_event, account: account, conversation: cb, inbox: inbox_b, user: user1,
                                 name: 'conversation_resolved', value: 30, created_at: Time.current)
      end

      it 'sums both teams without team_id' do
        stats = builder.build.find { |s| s[:id] == user1.id }

        expect(stats[:conversations_count]).to eq 2
        expect(stats[:resolved_conversations_count]).to eq 2
        expect(stats[:avg_resolution_time].to_f).to eq 20.0
      end

      it 'only considers the team conversations with team_id' do
        team_builder = described_class.new(account: account, params: params.merge(team_id: team_a.id))
        stats = team_builder.build.find { |s| s[:id] == user1.id }

        expect(stats[:conversations_count]).to eq 1
        expect(stats[:resolved_conversations_count]).to eq 1
        expect(stats[:avg_resolution_time].to_f).to eq 10.0
      end
    end
  end
end
