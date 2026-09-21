require 'rails_helper'

RSpec.describe 'Api::V2::Accounts::LiveReports', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let!(:team) { create(:team, account: account) }
  let(:team_member) { create(:team_member, team: team, user: admin) }

  describe 'GET /api/v2/accounts/{account.id}/live_reports/conversation_metrics' do
    context 'when unauthenticated' do
      it 'returns unauthorized' do
        get "/api/v2/accounts/#{account.id}/live_reports/conversation_metrics"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as an agent with no accessible inboxes' do
      it 'returns success with zeroed out metrics, not unauthorized' do
        create(:conversation, :with_assignee, account: account, status: :open)

        get "/api/v2/accounts/#{account.id}/live_reports/conversation_metrics",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        response_data = response.parsed_body
        expect(response_data['open']).to eq(0)
      end
    end

    context 'when authenticated as an agent scoped to a team inbox' do
      it 'only counts conversations in the accessible inbox' do
        scoped_inbox = create(:inbox, account: account, team: team)
        other_inbox = create(:inbox, account: account)
        team.add_members([agent.id])

        create(:conversation, :with_assignee, account: account, inbox: scoped_inbox, status: :open)
        create(:conversation, :with_assignee, account: account, inbox: other_inbox, status: :open)

        get "/api/v2/accounts/#{account.id}/live_reports/conversation_metrics",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body['open']).to eq(1)
      end
    end

    context 'when authenticated and authorized' do
      before do
        create(:conversation, :with_assignee, account: account, status: :open)
        create(:conversation, account: account, status: :open)
        create(:conversation, :with_assignee, account: account, status: :pending)
        create(:conversation, :with_assignee, account: account, status: :open) do |conversation|
          create(:message, account: account, conversation: conversation, message_type: :outgoing)
        end
      end

      it 'returns conversation metrics' do
        get "/api/v2/accounts/#{account.id}/live_reports/conversation_metrics",
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)

        response_data = response.parsed_body
        expect(response_data['open']).to eq(3)
        expect(response_data['unattended']).to eq(2)
        expect(response_data['unassigned']).to eq(1)
        expect(response_data['pending']).to eq(1)
      end

      context 'with team_id parameter' do
        let(:team_inbox) { create(:inbox, account: account, team: team) }

        before do
          create(:conversation, account: account, status: :open, inbox: team_inbox)
          create(:conversation, account: account, status: :open)
        end

        it 'returns metrics filtered by team' do
          get "/api/v2/accounts/#{account.id}/live_reports/conversation_metrics",
              params: { team_id: team.id },
              headers: admin.create_new_auth_token,
              as: :json

          expect(response).to have_http_status(:success)

          response_data = response.parsed_body
          expect(response_data['open']).to eq(1)
          expect(response_data['unattended']).to eq(1)
          expect(response_data['unassigned']).to eq(1)
          expect(response_data['pending']).to eq(0)
        end
      end
    end
  end

  describe 'GET /api/v2/accounts/{account.id}/live_reports/grouped_conversation_metrics' do
    context 'when unauthenticated' do
      it 'returns unauthorized' do
        get "/api/v2/accounts/#{account.id}/live_reports/grouped_conversation_metrics",
            params: { group_by: 'team_id' }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as an agent with no accessible inboxes' do
      it 'returns success with an empty grouped result, not unauthorized' do
        create(:conversation, account: account, status: :open, team_id: team.id)

        get "/api/v2/accounts/#{account.id}/live_reports/grouped_conversation_metrics",
            params: { group_by: 'team_id' },
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body).to eq([])
      end
    end

    context 'with invalid group_by parameter' do
      it 'returns unprocessable_entity error' do
        get "/api/v2/accounts/#{account.id}/live_reports/grouped_conversation_metrics",
            params: { group_by: 'invalid_param' },
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to eq('invalid group_by')
      end
    end

    context 'when grouped by team_id' do
      let(:assignee1) { create(:user, account: account) }
      let(:team_inbox) { create(:inbox, account: account, team: team) }

      before do
        create(:conversation, account: account, status: :open, inbox: team_inbox)
        create(:conversation, account: account, status: :open, inbox: team_inbox)
        create(:conversation, account: account, status: :open, inbox: team_inbox) do |conversation|
          create(:message, account: account, conversation: conversation, message_type: :outgoing)
        end

        create(:conversation, account: account, status: :open, assignee_id: assignee1.id)
        create(:conversation, account: account, status: :open) do |conversation|
          create(:message, account: account, conversation: conversation, message_type: :outgoing)
        end
      end

      it 'returns metrics grouped by team' do
        get "/api/v2/accounts/#{account.id}/live_reports/grouped_conversation_metrics",
            params: { group_by: 'team_id' },
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)

        response_data = response.parsed_body
        expect(response_data.size).to eq(2)
        expect(response_data).to include(
          { 'team_id' => nil, 'open' => 2, 'unattended' => 1, 'unassigned' => 1 }
        )
        expect(response_data).to include(
          { 'team_id' => team.id, 'open' => 3, 'unattended' => 2, 'unassigned' => 3 }
        )
      end
    end

    context 'when filtering by assignee_id' do
      let(:assignee1) { create(:user, account: account) }

      before do
        create(:conversation, assignee_id: agent.id, account: account, status: :open)
        create(:conversation, account: account, status: :open)
        create(:conversation, assignee_id: agent.id, account: account, status: :open) do |conversation|
          create(:message, account: account, conversation: conversation, message_type: :outgoing)
        end
      end

      it 'returns metrics grouped by assignee' do
        get "/api/v2/accounts/#{account.id}/live_reports/grouped_conversation_metrics",
            params: { group_by: 'assignee_id' },
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)

        response_data = response.parsed_body
        expect(response_data.size).to eq 2
        expect(response_data).to include(
          { 'assignee_id' => agent.id, 'open' => 2, 'unassigned' => 0, 'unattended' => 1 }
        )
        expect(response_data).to include(
          { 'assignee_id' => nil, 'open' => 1, 'unassigned' => 1, 'unattended' => 1 }
        )
      end
    end
  end
end
