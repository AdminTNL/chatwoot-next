require 'rails_helper'

RSpec.describe 'Summary Reports API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:default_timezone) { ActiveSupport::TimeZone[0]&.name }
  let(:start_of_today) { Time.current.in_time_zone(default_timezone).beginning_of_day.to_i }
  let(:end_of_today) { Time.current.in_time_zone(default_timezone).end_of_day.to_i }

  describe 'GET /api/v2/accounts/:account_id/summary_reports/agent' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v2/accounts/#{account.id}/summary_reports/agent"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:params) do
        {
          since: start_of_today.to_s,
          until: end_of_today.to_s,
          business_hours: true
        }
      end

      it 'returns success for agents, scoped to what they can access' do
        get "/api/v2/accounts/#{account.id}/summary_reports/agent",
            params: params,
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
      end

      it 'calls V2::Reports::AgentSummaryBuilder with the right params if the user is an admin' do
        agent_summary_builder = double
        allow(V2::Reports::AgentSummaryBuilder).to receive(:new).and_return(agent_summary_builder)
        allow(agent_summary_builder).to receive(:build).and_return([{ id: 1, conversations_count: 110 }])

        get "/api/v2/accounts/#{account.id}/summary_reports/agent",
            params: params,
            headers: admin.create_new_auth_token,
            as: :json

        expect(V2::Reports::AgentSummaryBuilder).to have_received(:new).with(
          account: account,
          params: params.merge(type: :agent)
        )
        expect(agent_summary_builder).to have_received(:build)

        expect(response).to have_http_status(:success)
        json_response = response.parsed_body

        expect(json_response.length).to eq(1)
        expect(json_response.first['id']).to eq(1)
        expect(json_response.first['conversations_count']).to eq(110)
        expect(json_response.first['avg_reply_time']).to be_nil
      end
    end
  end

  describe 'GET /api/v2/accounts/:account_id/summary_reports/inbox' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v2/accounts/#{account.id}/summary_reports/inbox"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:params) do
        {
          since: start_of_today.to_s,
          until: end_of_today.to_s,
          business_hours: true
        }
      end

      it 'returns success for agents, scoped to what they can access' do
        get "/api/v2/accounts/#{account.id}/summary_reports/inbox",
            params: params,
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
      end

      it 'calls V2::Reports::InboxSummaryBuilder with the right params if the user is an admin' do
        inbox_summary_builder = double
        allow(V2::Reports::InboxSummaryBuilder).to receive(:new).and_return(inbox_summary_builder)
        allow(inbox_summary_builder).to receive(:build).and_return([{ id: 1, conversations_count: 110 }])

        get "/api/v2/accounts/#{account.id}/summary_reports/inbox",
            params: params,
            headers: admin.create_new_auth_token,
            as: :json

        expect(V2::Reports::InboxSummaryBuilder).to have_received(:new).with(
          account: account,
          params: params.merge(type: :inbox)
        )
        expect(inbox_summary_builder).to have_received(:build)

        expect(response).to have_http_status(:success)
        json_response = response.parsed_body

        expect(json_response.length).to eq(1)
        expect(json_response.first['id']).to eq(1)
        expect(json_response.first['conversations_count']).to eq(110)
        expect(json_response.first['avg_reply_time']).to be_nil
      end
    end
  end

  describe 'GET /api/v2/accounts/:account_id/summary_reports/team' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v2/accounts/#{account.id}/summary_reports/team"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:params) do
        {
          since: start_of_today.to_s,
          until: end_of_today.to_s,
          business_hours: true
        }
      end

      it 'returns success for agents, scoped to what they can access' do
        get "/api/v2/accounts/#{account.id}/summary_reports/team",
            params: params,
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
      end

      it 'calls V2::Reports::TeamSummaryBuilder with the right params if the user is an admin' do
        team_summary_builder = double
        allow(V2::Reports::TeamSummaryBuilder).to receive(:new).and_return(team_summary_builder)
        allow(team_summary_builder).to receive(:build).and_return([{ id: 1, conversations_count: 110 }])

        get "/api/v2/accounts/#{account.id}/summary_reports/team",
            params: params,
            headers: admin.create_new_auth_token,
            as: :json

        expect(V2::Reports::TeamSummaryBuilder).to have_received(:new).with(
          account: account,
          params: params.merge(type: :team)
        )
        expect(team_summary_builder).to have_received(:build)

        expect(response).to have_http_status(:success)
        json_response = response.parsed_body

        expect(json_response.length).to eq(1)
        expect(json_response.first['id']).to eq(1)
        expect(json_response.first['conversations_count']).to eq(110)
        expect(json_response.first['avg_reply_time']).to be_nil
      end
    end
  end

  describe 'GET /api/v2/accounts/:account_id/summary_reports/channel' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v2/accounts/#{account.id}/summary_reports/channel"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:params) do
        {
          since: start_of_today.to_s,
          until: end_of_today.to_s
        }
      end

      it 'returns success for agents' do
        get "/api/v2/accounts/#{account.id}/summary_reports/channel",
            params: params,
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
      end

      it 'calls V2::Reports::ChannelSummaryBuilder with the right params if the user is an admin' do
        channel_summary_builder = double
        allow(V2::Reports::ChannelSummaryBuilder).to receive(:new).and_return(channel_summary_builder)
        allow(channel_summary_builder).to receive(:build)
          .and_return({
                        'Channel::WebWidget' => { open: 5, resolved: 10, pending: 2, snoozed: 1, total: 18 }
                      })

        get "/api/v2/accounts/#{account.id}/summary_reports/channel",
            params: params,
            headers: admin.create_new_auth_token,
            as: :json

        expect(V2::Reports::ChannelSummaryBuilder).to have_received(:new).with(
          account: account,
          params: hash_including(since: start_of_today.to_s, until: end_of_today.to_s)
        )
        expect(channel_summary_builder).to have_received(:build)

        expect(response).to have_http_status(:success)
        json_response = response.parsed_body

        expect(json_response['Channel::WebWidget']['open']).to eq(5)
        expect(json_response['Channel::WebWidget']['total']).to eq(18)
      end

      it 'returns unprocessable_entity when date range exceeds 6 months' do
        get "/api/v2/accounts/#{account.id}/summary_reports/channel",
            params: { since: 1.year.ago.to_i.to_s, until: Time.current.to_i.to_s },
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to eq(I18n.t('errors.reports.date_range_too_long'))
      end
    end
  end

  describe 'row-level scoping for restricted agents' do
    let!(:team_a) { create(:team, account: account) }
    let!(:team_b) { create(:team, account: account) }
    let!(:inbox_a) { create(:inbox, account: account, team: team_a, name: 'Team A Inbox') }
    let!(:inbox_b) { create(:inbox, account: account, team: team_b, name: 'Team B Inbox') }
    let!(:agent_a) { create(:user, account: account, role: :agent) }
    let!(:agent_b) { create(:user, account: account, role: :agent) }

    let(:params) { { since: 1.week.ago.to_i.to_s, until: Time.current.to_i.to_s } }

    before do
      team_a.add_members([agent_a.id])
      team_b.add_members([agent_b.id])

      create(:conversation, account: account, inbox: inbox_a, assignee: agent_a)
      create(:conversation, account: account, inbox: inbox_b, assignee: agent_b)
    end

    it 'only includes accessible agents for a restricted agent' do
      get "/api/v2/accounts/#{account.id}/summary_reports/agent",
          params: params, headers: agent_a.create_new_auth_token, as: :json

      ids = response.parsed_body.pluck('id')
      expect(ids).to include(agent_a.id)
      expect(ids).not_to include(agent_b.id)
    end

    it 'only includes accessible teams for a restricted agent' do
      get "/api/v2/accounts/#{account.id}/summary_reports/team",
          params: params, headers: agent_a.create_new_auth_token, as: :json

      ids = response.parsed_body.pluck('id')
      expect(ids).to include(team_a.id)
      expect(ids).not_to include(team_b.id)
    end

    it 'only includes accessible inboxes for a restricted agent' do
      get "/api/v2/accounts/#{account.id}/summary_reports/inbox",
          params: params, headers: agent_a.create_new_auth_token, as: :json

      ids = response.parsed_body.pluck('id')
      expect(ids).to include(inbox_a.id)
      expect(ids).not_to include(inbox_b.id)
    end

    it 'only includes accessible labels for a restricted agent' do
      label_a = create(:label, account: account, team: team_a, title: 'team-a-label')
      label_b = create(:label, account: account, team: team_b, title: 'team-b-label')

      get "/api/v2/accounts/#{account.id}/summary_reports/label",
          params: params, headers: agent_a.create_new_auth_token, as: :json

      names = response.parsed_body.pluck('name')
      expect(names).to include(label_a.title)
      expect(names).not_to include(label_b.title)
    end

    it 'includes every agent for an admin (non-regression)' do
      get "/api/v2/accounts/#{account.id}/summary_reports/agent",
          params: params, headers: admin.create_new_auth_token, as: :json

      ids = response.parsed_body.pluck('id')
      expect(ids).to include(agent_a.id, agent_b.id)
    end
  end
end
