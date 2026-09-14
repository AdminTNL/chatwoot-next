require 'rails_helper'

RSpec.describe 'Label API', type: :request do
  let!(:account) { create(:account) }
  let!(:label) { create(:label, account: account) }
  let!(:conversation) { create(:conversation, account: account) }

  describe 'GET /api/v1/accounts/{account.id}/labels' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/labels"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :administrator) }

      it 'returns all the labels in account' do
        get "/api/v1/accounts/#{account.id}/labels",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(response.body).to include(label.title)
      end

      it 'includes team_id in the payload' do
        get "/api/v1/accounts/#{account.id}/labels",
            headers: agent.create_new_auth_token,
            as: :json

        payload = JSON.parse(response.body)['payload']
        returned_label = payload.find { |l| l['id'] == label.id }
        expect(returned_label).to have_key('team_id')
      end
    end

    context 'when filtering by team' do
      let!(:team_a) { create(:team, account: account) }
      let!(:team_b) { create(:team, account: account) }
      let!(:team_a_label) { create(:label, account: account, team: team_a, title: 'team-a-label') }
      let!(:team_b_label) { create(:label, account: account, team: team_b, title: 'team-b-label') }

      it 'returns all labels for an administrator' do
        admin = create(:user, account: account, role: :administrator)

        get "/api/v1/accounts/#{account.id}/labels",
            headers: admin.create_new_auth_token,
            as: :json

        titles = JSON.parse(response.body)['payload'].pluck('title')
        expect(titles).to include(label.title, team_a_label.title, team_b_label.title)
      end

      it 'returns global labels and the labels of the teams the agent belongs to' do
        agent_in_team_a = create(:user, account: account, role: :agent)
        team_a.add_members([agent_in_team_a.id])

        get "/api/v1/accounts/#{account.id}/labels",
            headers: agent_in_team_a.create_new_auth_token,
            as: :json

        titles = JSON.parse(response.body)['payload'].pluck('title')
        expect(titles).to include(label.title, team_a_label.title)
        expect(titles).not_to include(team_b_label.title)
      end

      it 'returns only global labels for an agent with no team' do
        agent_without_team = create(:user, account: account, role: :agent)

        get "/api/v1/accounts/#{account.id}/labels",
            headers: agent_without_team.create_new_auth_token,
            as: :json

        titles = JSON.parse(response.body)['payload'].pluck('title')
        expect(titles).to include(label.title)
        expect(titles).not_to include(team_a_label.title, team_b_label.title)
      end
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/labels/:id' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/labels/#{label.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:admin) { create(:user, account: account, role: :administrator) }

      it 'shows the contact' do
        get "/api/v1/accounts/#{account.id}/labels/#{label.id}",
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(response.body).to include(label.title)
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/labels' do
    let(:valid_params) { { label: { title: 'test' } } }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        expect { post "/api/v1/accounts/#{account.id}/labels", params: valid_params }.not_to change(Label, :count)

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:admin) { create(:user, account: account, role: :administrator) }

      it 'creates the contact' do
        expect do
          post "/api/v1/accounts/#{account.id}/labels", headers: admin.create_new_auth_token,
                                                        params: valid_params
        end.to change(Label, :count).by(1)

        expect(response).to have_http_status(:success)
      end

      it 'creates the label with a team_id and returns it in the JSON' do
        team = create(:team, account: account)

        post "/api/v1/accounts/#{account.id}/labels", headers: admin.create_new_auth_token,
                                                        params: { label: { title: 'team-scoped', team_id: team.id } }

        expect(response).to have_http_status(:success)
        expect(JSON.parse(response.body)['team_id']).to eq(team.id)
        expect(Label.last.team_id).to eq(team.id)
      end
    end
  end

  describe 'PATCH /api/v1/accounts/{account.id}/labels/:id' do
    let(:valid_params) { { title: 'Test_2' }  }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        put "/api/v1/accounts/#{account.id}/labels/#{label.id}",
            params: valid_params

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:admin) { create(:user, account: account, role: :administrator) }

      it 'updates the label' do
        patch "/api/v1/accounts/#{account.id}/labels/#{label.id}",
              headers: admin.create_new_auth_token,
              params: valid_params,
              as: :json

        expect(response).to have_http_status(:success)
        expect(label.reload.title).to eq('test_2')
      end

      it 'removes the team when team_id is set to null' do
        team = create(:team, account: account)
        team_label = create(:label, account: account, team: team)

        patch "/api/v1/accounts/#{account.id}/labels/#{team_label.id}",
              headers: admin.create_new_auth_token,
              params: { team_id: nil },
              as: :json

        expect(response).to have_http_status(:success)
        expect(team_label.reload.team_id).to be_nil
      end
    end
  end

  describe 'DELETE /api/v1/accounts/{account.id}/labels/:id' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        delete "/api/v1/accounts/#{account.id}/labels/#{label.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:admin) { create(:user, account: account, role: :administrator) }

      it 'deletes the label and enqueues label cleanup' do
        label_deleted_at = Time.zone.parse('2026-05-07 10:00:00 UTC')
        conversation.label_list.add(label.title)
        conversation.save!

        clear_enqueued_jobs

        travel_to(label_deleted_at) do
          expect do
            delete "/api/v1/accounts/#{account.id}/labels/#{label.id}", headers: admin.create_new_auth_token, as: :json
          end.to have_enqueued_job(Labels::RemoveAssociationsJob).with(
            label_title: label.title,
            account_id: account.id,
            label_deleted_at: label_deleted_at
          )
        end

        expect(response).to have_http_status(:ok)
        expect(Label.exists?(label.id)).to be(false)
      end
    end
  end
end
