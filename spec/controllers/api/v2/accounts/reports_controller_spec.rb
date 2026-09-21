require 'rails_helper'

RSpec.describe Api::V2::Accounts::ReportsController, type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account) }

  describe 'GET /api/v2/accounts/{account.id}/reports' do
    context 'when authenticated and authorized' do
      before do
        # Create conversations across 24 hours at different times
        base_time = Time.utc(2024, 1, 14, 23, 0) # Start at 23:00 to span 2 days

        # Create conversations every 4 hours across 24 hours
        6.times do |i|
          time = base_time + (i * 4).hours
          travel_to time do
            conversation = create(:conversation, account: account, inbox: inbox, assignee: agent)
            create(:message, account: account, conversation: conversation, message_type: :outgoing)
          end
        end
      end

      it 'timezone_offset affects data grouping and timestamps correctly' do
        travel_to Time.utc(2024, 1, 15, 12, 0) do
          Time.use_zone('UTC') do
            base_time = Time.utc(2024, 1, 14, 23, 0) # Start at 23:00 to span 2 days
            base_params = {
              metric: 'conversations_count',
              type: 'account',
              since: (base_time - 1.day).to_i.to_s,
              until: (base_time + 2.days).to_i.to_s,
              group_by: 'day'
            }

            responses = [0, -8, 9].map do |offset|
              get "/api/v2/accounts/#{account.id}/reports",
                  params: base_params.merge(timezone_offset: offset),
                  headers: admin.create_new_auth_token, as: :json
              response.parsed_body
            end

            data_entries = responses.map { |r| r.select { |e| e['value'] > 0 } }
            totals = responses.map { |r| r.sum { |e| e['value'] } }
            timestamps = responses.map { |r| r.map { |e| e['timestamp'] } }

            # Data conservation and redistribution
            expect(totals.uniq).to eq([6])
            expect(data_entries[0].map { |e| e['value'] }).to eq([1, 5])
            expect(data_entries[1].map { |e| e['value'] }).to eq([3, 3])
            expect(data_entries[2].map { |e| e['value'] }).to eq([4, 2])

            # Timestamp differences
            expect(timestamps.uniq.size).to eq(3)
            timestamps[0].zip(timestamps[1]).each { |utc, pst| expect(utc - pst).to eq(-28_800) }
          end
        end
      end

      describe 'timezone_offset does not affect summary report totals' do
        let(:base_time) { Time.utc(2024, 1, 15, 12, 0) }
        let(:summary_params) do
          {
            type: 'account',
            since: (base_time - 1.day).to_i.to_s,
            until: (base_time + 1.day).to_i.to_s
          }
        end

        let(:jst_params) do
          # For JST: User wants "Jan 15 JST" which translates to:
          # Jan 14 15:00 UTC to Jan 15 15:00 UTC (event NOT included)
          {
            type: 'account',
            since: (Time.utc(2024, 1, 15, 0, 0) - 9.hours).to_i.to_s, # Jan 14 15:00 UTC
            until: (Time.utc(2024, 1, 16, 0, 0) - 9.hours).to_i.to_s  # Jan 15 15:00 UTC
          }
        end
        let(:utc_params) do
          # For UTC: Jan 15 00:00 UTC to Jan 16 00:00 UTC (event included)
          {
            type: 'account',
            since: Time.utc(2024, 1, 15, 0, 0).to_i.to_s,
            until: Time.utc(2024, 1, 16, 0, 0).to_i.to_s
          }
        end

        it 'returns identical conversation counts across timezones' do
          Time.use_zone('UTC') do
            summaries = [-8, 0, 9].map do |offset|
              get "/api/v2/accounts/#{account.id}/reports/summary",
                  params: summary_params.merge(timezone_offset: offset),
                  headers: admin.create_new_auth_token, as: :json
              response.parsed_body
            end

            conversation_counts = summaries.map { |s| s['conversations_count'] }
            expect(conversation_counts.uniq).to eq([6])
          end
        end

        it 'returns identical message counts across timezones' do
          Time.use_zone('UTC') do
            get "/api/v2/accounts/#{account.id}/reports/summary",
                params: summary_params.merge(timezone_offset: 0),
                headers: admin.create_new_auth_token, as: :json
            utc_summary = response.parsed_body

            get "/api/v2/accounts/#{account.id}/reports/summary",
                params: summary_params.merge(timezone_offset: -8),
                headers: admin.create_new_auth_token, as: :json
            pst_summary = response.parsed_body

            expect(utc_summary['incoming_messages_count']).to eq(pst_summary['incoming_messages_count'])
            expect(utc_summary['outgoing_messages_count']).to eq(pst_summary['outgoing_messages_count'])
          end
        end

        it 'returns consistent resolution counts across timezones' do
          Time.use_zone('UTC') do
            get "/api/v2/accounts/#{account.id}/reports/summary",
                params: summary_params.merge(timezone_offset: 0),
                headers: admin.create_new_auth_token, as: :json
            utc_summary = response.parsed_body

            get "/api/v2/accounts/#{account.id}/reports/summary",
                params: summary_params.merge(timezone_offset: 9),
                headers: admin.create_new_auth_token, as: :json
            jst_summary = response.parsed_body

            expect(utc_summary['resolutions_count']).to eq(jst_summary['resolutions_count'])
          end
        end

        it 'returns consistent previous period data across timezones' do
          Time.use_zone('UTC') do
            get "/api/v2/accounts/#{account.id}/reports/summary",
                params: summary_params.merge(timezone_offset: 0),
                headers: admin.create_new_auth_token, as: :json
            utc_summary = response.parsed_body

            get "/api/v2/accounts/#{account.id}/reports/summary",
                params: summary_params.merge(timezone_offset: -8),
                headers: admin.create_new_auth_token, as: :json
            pst_summary = response.parsed_body

            expect(utc_summary['previous']['conversations_count']).to eq(pst_summary['previous']['conversations_count']) if utc_summary['previous']
          end
        end

        it 'summary reports work when frontend sends correct timezone boundaries' do
          Time.use_zone('UTC') do
            # Create a resolution event right at timezone boundary
            boundary_time = Time.utc(2024, 1, 15, 23, 30) # 11:30 PM UTC on Jan 15
            gravatar_url = 'https://www.gravatar.com'
            stub_request(:get, /#{gravatar_url}.*/).to_return(status: 404)

            travel_to boundary_time do
              perform_enqueued_jobs do
                conversation = create(:conversation, account: account, inbox: inbox, assignee: agent)
                conversation.resolved!
              end
            end

            get "/api/v2/accounts/#{account.id}/reports/summary",
                params: jst_params.merge(timezone_offset: 9),
                headers: admin.create_new_auth_token, as: :json
            jst_summary = response.parsed_body

            get "/api/v2/accounts/#{account.id}/reports/summary",
                params: utc_params.merge(timezone_offset: 0),
                headers: admin.create_new_auth_token, as: :json
            utc_summary = response.parsed_body

            expect(jst_summary['resolutions_count']).to eq(0)
            expect(utc_summary['resolutions_count']).to eq(1)
          end
        end
      end
    end

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        get "/api/v2/accounts/#{account.id}/reports"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as an agent with no accessible inboxes' do
      it 'returns success with zeroed out data, not an error' do
        get "/api/v2/accounts/#{account.id}/reports",
            params: {
              metric: 'conversations_count',
              type: 'account',
              since: 1.week.ago.to_i.to_s,
              until: Time.current.to_i.to_s,
              group_by: 'day'
            },
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body.sum { |e| e['value'] }).to eq(0)
      end
    end
  end

  describe 'team-scoped access to reports' do
    let!(:team_a) { create(:team, account: account) }
    let!(:team_b) { create(:team, account: account) }
    let!(:inbox_a) { create(:inbox, account: account, team: team_a) }
    let!(:inbox_b) { create(:inbox, account: account, team: team_b) }
    let!(:agent_a) { create(:user, account: account, role: :agent) }
    let!(:label_a) { create(:label, account: account, team: team_a, title: 'team-a-label') }
    let!(:label_b) { create(:label, account: account, team: team_b, title: 'team-b-label') }

    let(:current_time) { Time.zone.parse('2026-05-20 12:00') }
    let(:since_param) { (current_time - 1.week).to_i.to_s }
    let(:until_param) { current_time.to_i.to_s }

    before do
      travel_to current_time

      team_a.add_members([agent_a.id])

      conversation_a = create(:conversation, account: account, inbox: inbox_a, created_at: current_time - 1.day)
      conversation_b = create(:conversation, account: account, inbox: inbox_b, created_at: current_time - 1.day)

      conversation_a.label_list.add(label_a.title)
      conversation_a.save!
      conversation_b.label_list.add(label_b.title)
      conversation_b.save!
    end

    it "sums only the agent's own team inboxes for an account-type report, not the whole account" do
      get "/api/v2/accounts/#{account.id}/reports",
          params: {
            metric: 'conversations_count', type: 'account', since: since_param, until: until_param, group_by: 'day'
          },
          headers: agent_a.create_new_auth_token, as: :json

      agent_total = response.parsed_body.sum { |e| e['value'] }

      get "/api/v2/accounts/#{account.id}/reports",
          params: {
            metric: 'conversations_count', type: 'account', since: since_param, until: until_param, group_by: 'day'
          },
          headers: admin.create_new_auth_token, as: :json

      admin_total = response.parsed_body.sum { |e| e['value'] }

      expect(agent_total).to eq(1)
      expect(admin_total).to eq(2)
    end

    it 'returns success for an inbox the agent can access' do
      get "/api/v2/accounts/#{account.id}/reports",
          params: {
            metric: 'conversations_count', type: 'inbox', id: inbox_a.id, since: since_param, until: until_param, group_by: 'day'
          },
          headers: agent_a.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
    end

    it 'returns not_found for an inbox of another team' do
      get "/api/v2/accounts/#{account.id}/reports",
          params: {
            metric: 'conversations_count', type: 'inbox', id: inbox_b.id, since: since_param, until: until_param, group_by: 'day'
          },
          headers: agent_a.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'returns not_found for a label of another team' do
      get "/api/v2/accounts/#{account.id}/reports",
          params: {
            metric: 'conversations_count', type: 'label', id: label_b.id, since: since_param, until: until_param, group_by: 'day'
          },
          headers: agent_a.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'returns not_found for a team the agent is not a member of' do
      get "/api/v2/accounts/#{account.id}/reports",
          params: {
            metric: 'conversations_count', type: 'team', id: team_b.id, since: since_param, until: until_param, group_by: 'day'
          },
          headers: agent_a.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'returns success for an agent with direct inbox_member access but no team' do
      lone_agent = create(:user, account: account, role: :agent)
      create(:inbox_member, inbox: inbox_a, user: lone_agent)

      get "/api/v2/accounts/#{account.id}/reports",
          params: {
            metric: 'conversations_count', type: 'inbox', id: inbox_a.id, since: since_param, until: until_param, group_by: 'day'
          },
          headers: lone_agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
    end
  end

  describe 'GET /api/v2/accounts/{account.id}/reports/inbox_label_matrix' do
    let!(:inbox_one) { create(:inbox, account: account, name: 'Email Support') }
    let!(:label_one) { create(:label, account: account, title: 'bug') }

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        get "/api/v2/accounts/#{account.id}/reports/inbox_label_matrix"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as agent with no accessible inboxes' do
      it 'returns success with an empty matrix, not unauthorized' do
        get "/api/v2/accounts/#{account.id}/reports/inbox_label_matrix",
            headers: agent.create_new_auth_token, as: :json

        expect(response).to have_http_status(:success)
        body = response.parsed_body
        # label_one is a global (team-less) label, so it stays visible per
        # LabelPolicy::Scope even though the agent has no accessible inbox -
        # but with no accessible inbox at all, the matrix itself has no rows.
        expect(body['inboxes']).to eq([])
        expect(body['labels']).to eq([{ 'id' => label_one.id, 'title' => 'bug' }])
        expect(body['matrix']).to eq([])
      end
    end

    context 'when authenticated as agent with accessible inboxes' do
      let!(:team) { create(:team, account: account) }
      let!(:other_team) { create(:team, account: account) }

      before do
        inbox_one.update!(team: team)
        team.add_members([agent.id])

        c1 = create(:conversation, account: account, inbox: inbox_one, created_at: 2.days.ago)
        c1.update(label_list: [label_one.title])
      end

      it 'only includes inboxes and labels the agent can access' do
        other_inbox = create(:inbox, account: account, name: 'Other Inbox', team: other_team)
        other_label = create(:label, account: account, title: 'other-label', team: other_team)
        c2 = create(:conversation, account: account, inbox: other_inbox, created_at: 1.day.ago)
        c2.update(label_list: [other_label.title])

        get "/api/v2/accounts/#{account.id}/reports/inbox_label_matrix",
            params: { since: 1.week.ago.to_i.to_s, until: Time.current.to_i.to_s },
            headers: agent.create_new_auth_token, as: :json

        expect(response).to have_http_status(:success)
        body = response.parsed_body
        expect(body['inboxes'].pluck('id')).to eq([inbox_one.id])
        expect(body['labels'].pluck('id')).to eq([label_one.id])
        expect(body['matrix']).to eq([[1]])
      end
    end

    context 'when authenticated as admin' do
      before do
        c1 = create(:conversation, account: account, inbox: inbox_one, created_at: 2.days.ago)
        c1.update(label_list: [label_one.title])
      end

      it 'returns the inbox label matrix' do
        get "/api/v2/accounts/#{account.id}/reports/inbox_label_matrix",
            params: { since: 1.week.ago.to_i.to_s, until: Time.current.to_i.to_s },
            headers: admin.create_new_auth_token, as: :json

        expect(response).to have_http_status(:success)

        body = response.parsed_body
        expect(body['inboxes']).to be_an(Array)
        expect(body['labels']).to be_an(Array)
        expect(body['matrix']).to be_an(Array)
      end

      it 'filters by inbox_ids and label_ids' do
        get "/api/v2/accounts/#{account.id}/reports/inbox_label_matrix",
            params: { inbox_ids: [inbox_one.id], label_ids: [label_one.id] },
            headers: admin.create_new_auth_token, as: :json

        expect(response).to have_http_status(:success)

        body = response.parsed_body
        expect(body['inboxes'].length).to eq(1)
        expect(body['labels'].length).to eq(1)
      end
    end
  end

  describe 'GET /api/v2/accounts/{account.id}/reports/first_response_time_distribution' do
    let!(:web_widget_inbox) { create(:inbox, account: account, channel: create(:channel_widget, account: account)) }

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        get "/api/v2/accounts/#{account.id}/reports/first_response_time_distribution"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as agent' do
      it 'returns unauthorized' do
        get "/api/v2/accounts/#{account.id}/reports/first_response_time_distribution",
            headers: agent.create_new_auth_token, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as admin' do
      before do
        create(:reporting_event, account: account, inbox: web_widget_inbox, name: 'first_response',
                                 value: 1_800, created_at: 2.days.ago)
      end

      it 'returns the first response time distribution' do
        get "/api/v2/accounts/#{account.id}/reports/first_response_time_distribution",
            params: { since: 1.week.ago.to_i.to_s, until: Time.current.to_i.to_s },
            headers: admin.create_new_auth_token, as: :json

        expect(response).to have_http_status(:success)

        body = response.parsed_body
        expect(body).to be_a(Hash)
        expect(body['Channel::WebWidget']).to include('0-1h', '1-4h', '4-8h', '8-24h', '24h+')
      end

      it 'returns correct counts in buckets' do
        get "/api/v2/accounts/#{account.id}/reports/first_response_time_distribution",
            params: { since: 1.week.ago.to_i.to_s, until: Time.current.to_i.to_s },
            headers: admin.create_new_auth_token, as: :json

        body = response.parsed_body
        expect(body['Channel::WebWidget']['0-1h']).to eq(1)
      end
    end
  end

  describe 'GET /api/v2/accounts/{account.id}/reports/outgoing_messages_count' do
    let(:since_epoch) { 1.week.ago.to_i.to_s }
    let(:until_epoch) { 1.day.from_now.to_i.to_s }

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        get "/api/v2/accounts/#{account.id}/reports/outgoing_messages_count",
            params: { group_by: 'agent', since: since_epoch, until: until_epoch }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as agent with no accessible inboxes' do
      it 'returns success with an empty result, not unauthorized' do
        get "/api/v2/accounts/#{account.id}/reports/outgoing_messages_count",
            params: { group_by: 'agent', since: since_epoch, until: until_epoch },
            headers: agent.create_new_auth_token, as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body).to eq([])
      end
    end

    context 'when authenticated as agent with accessible inboxes' do
      let!(:team) { create(:team, account: account) }
      let(:other_inbox) { create(:inbox, account: account) }

      before do
        inbox.update!(team: team)
        team.add_members([agent.id])

        conv_in_scope = create(:conversation, account: account, inbox: inbox, assignee: agent)
        conv_out_of_scope = create(:conversation, account: account, inbox: other_inbox, assignee: agent)

        create(:message, account: account, conversation: conv_in_scope, inbox: inbox, message_type: :outgoing, sender: agent)
        create(:message, account: account, conversation: conv_out_of_scope, inbox: other_inbox, message_type: :outgoing, sender: agent)
      end

      it 'only counts messages in the inboxes the agent can access' do
        get "/api/v2/accounts/#{account.id}/reports/outgoing_messages_count",
            params: { group_by: 'agent', since: since_epoch, until: until_epoch },
            headers: agent.create_new_auth_token, as: :json

        expect(response).to have_http_status(:success)
        data = response.parsed_body
        agent_entry = data.find { |e| e['id'] == agent.id }
        expect(agent_entry['outgoing_messages_count']).to eq(1)
      end
    end

    context 'when authenticated as admin' do
      let(:agent2) { create(:user, account: account, role: :agent) }
      let(:team) { create(:team, account: account) }
      let(:inbox2) { create(:inbox, account: account) }
      let(:team_inbox) { create(:inbox, account: account, team: team) }

      # Separate conversations for agent and team grouping because
      # model callbacks clear assignee_id when team is set.
      before do
        conv_agent = create(:conversation, account: account, inbox: inbox, assignee: agent)
        conv_agent2 = create(:conversation, account: account, inbox: inbox2, assignee: agent2)
        conv_team = create(:conversation, account: account, inbox: team_inbox)

        create_list(:message, 3, account: account, conversation: conv_agent, inbox: inbox, message_type: :outgoing, sender: agent)
        create_list(:message, 2, account: account, conversation: conv_agent2, inbox: inbox2, message_type: :outgoing, sender: agent2)
        create_list(:message, 4, account: account, conversation: conv_team, inbox: team_inbox, message_type: :outgoing)
        # incoming message should not be counted
        create(:message, account: account, conversation: conv_agent, inbox: inbox, message_type: :incoming)
      end

      it 'returns unprocessable_entity for invalid group_by' do
        get "/api/v2/accounts/#{account.id}/reports/outgoing_messages_count",
            params: { group_by: 'invalid', since: since_epoch, until: until_epoch },
            headers: admin.create_new_auth_token, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns outgoing message counts grouped by agent' do
        get "/api/v2/accounts/#{account.id}/reports/outgoing_messages_count",
            params: { group_by: 'agent', since: since_epoch, until: until_epoch },
            headers: admin.create_new_auth_token, as: :json

        expect(response).to have_http_status(:success)
        data = response.parsed_body
        expect(data).to be_an(Array)

        agent_entry = data.find { |e| e['id'] == agent.id }
        agent2_entry = data.find { |e| e['id'] == agent2.id }
        expect(agent_entry['outgoing_messages_count']).to eq(3)
        expect(agent2_entry['outgoing_messages_count']).to eq(2)
      end

      it 'returns outgoing message counts grouped by team' do
        get "/api/v2/accounts/#{account.id}/reports/outgoing_messages_count",
            params: { group_by: 'team', since: since_epoch, until: until_epoch },
            headers: admin.create_new_auth_token, as: :json

        expect(response).to have_http_status(:success)
        data = response.parsed_body
        expect(data).to be_an(Array)
        expect(data.length).to eq(1)
        expect(data.first['id']).to eq(team.id)
        expect(data.first['outgoing_messages_count']).to eq(4)
      end

      it 'returns outgoing message counts grouped by inbox' do
        get "/api/v2/accounts/#{account.id}/reports/outgoing_messages_count",
            params: { group_by: 'inbox', since: since_epoch, until: until_epoch },
            headers: admin.create_new_auth_token, as: :json

        expect(response).to have_http_status(:success)
        data = response.parsed_body
        expect(data).to be_an(Array)

        inbox_entry = data.find { |e| e['id'] == inbox.id }
        inbox2_entry = data.find { |e| e['id'] == inbox2.id }
        expect(inbox_entry['outgoing_messages_count']).to eq(3)
        expect(inbox2_entry['outgoing_messages_count']).to eq(2)
      end

      it 'returns outgoing message counts grouped by label' do
        label = create(:label, account: account, title: 'support')
        conversation = account.conversations.first
        conversation.label_list.add('support')
        conversation.save!

        get "/api/v2/accounts/#{account.id}/reports/outgoing_messages_count",
            params: { group_by: 'label', since: since_epoch, until: until_epoch },
            headers: admin.create_new_auth_token, as: :json

        expect(response).to have_http_status(:success)
        data = response.parsed_body
        expect(data).to be_an(Array)
        expect(data.length).to eq(1)
        expect(data.first['id']).to eq(label.id)
        expect(data.first['name']).to eq('support')
      end

      it 'excludes bot messages when grouped by agent' do
        bot = create(:agent_bot)
        bot_conversation = create(:conversation, account: account, inbox: inbox)
        create(:message, account: account, conversation: bot_conversation, inbox: inbox,
                         message_type: :outgoing, sender: bot)

        get "/api/v2/accounts/#{account.id}/reports/outgoing_messages_count",
            params: { group_by: 'agent', since: since_epoch, until: until_epoch },
            headers: admin.create_new_auth_token, as: :json

        data = response.parsed_body
        agent_entry = data.find { |e| e['id'] == agent.id }
        # 3 from before block; bot message excluded (sender_type != 'User')
        expect(agent_entry['outgoing_messages_count']).to eq(3)
      end
    end
  end

  describe 'CSV exports row-level scoping' do
    let!(:team_a) { create(:team, account: account) }
    let!(:team_b) { create(:team, account: account) }
    let!(:inbox_a) { create(:inbox, account: account, team: team_a, name: 'Team A Inbox') }
    let!(:inbox_b) { create(:inbox, account: account, team: team_b, name: 'Team B Inbox') }
    let!(:agent_a) { create(:user, account: account, role: :agent) }
    let!(:agent_b) { create(:user, account: account, role: :agent) }

    let(:since_param) { 1.week.ago.to_i.to_s }
    let(:until_param) { Time.current.to_i.to_s }

    before do
      team_a.add_members([agent_a.id])
      team_b.add_members([agent_b.id])

      create(:conversation, account: account, inbox: inbox_a, assignee: agent_a)
      create(:conversation, account: account, inbox: inbox_b, assignee: agent_b)
    end

    it 'only lists accessible inboxes in the inboxes CSV for a restricted agent' do
      get "/api/v2/accounts/#{account.id}/reports/inboxes",
          params: { since: since_param, until: until_param },
          headers: agent_a.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.body).to include(inbox_a.name)
      expect(response.body).not_to include(inbox_b.name)
    end

    it 'only lists accessible agents in the agents CSV for a restricted agent' do
      get "/api/v2/accounts/#{account.id}/reports/agents",
          params: { since: since_param, until: until_param },
          headers: agent_a.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.body).to include(agent_a.name)
      expect(response.body).not_to include(agent_b.name)
    end

    it 'only lists the accessible team in the teams CSV for a restricted agent' do
      get "/api/v2/accounts/#{account.id}/reports/teams",
          params: { since: since_param, until: until_param },
          headers: agent_a.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.body).to include(team_a.name)
      expect(response.body).not_to include(team_b.name)
    end

    it 'only lists accessible labels in the labels CSV for a restricted agent' do
      label_a = create(:label, account: account, team: team_a, title: 'team-a-label')
      label_b = create(:label, account: account, team: team_b, title: 'team-b-label')

      get "/api/v2/accounts/#{account.id}/reports/labels",
          params: { since: since_param, until: until_param },
          headers: agent_a.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.body).to include(label_a.title)
      expect(response.body).not_to include(label_b.title)
    end

    it 'lists every inbox in the inboxes CSV for an admin (non-regression)' do
      get "/api/v2/accounts/#{account.id}/reports/inboxes",
          params: { since: since_param, until: until_param },
          headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.body).to include(inbox_a.name)
      expect(response.body).to include(inbox_b.name)
    end
  end
end
