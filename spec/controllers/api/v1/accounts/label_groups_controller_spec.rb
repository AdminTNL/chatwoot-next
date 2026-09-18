require 'rails_helper'

RSpec.describe 'Label Group API', type: :request do
  let!(:account) { create(:account) }
  let!(:team) { create(:team, account: account) }
  let!(:label_group) { create(:label_group, account: account, team: team) }

  describe 'GET /api/v1/accounts/{account.id}/label_groups' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/label_groups"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an agent' do
      it 'returns unauthorized' do
        agent = create(:user, account: account, role: :agent)

        get "/api/v1/accounts/#{account.id}/label_groups",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an administrator' do
      let(:admin) { create(:user, account: account, role: :administrator) }

      it 'returns all the label groups in the account' do
        get "/api/v1/accounts/#{account.id}/label_groups",
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        payload = JSON.parse(response.body)['payload']
        expect(payload.pluck('id')).to include(label_group.id)
        expect(payload.first).to have_key('team_id')
      end
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/label_groups/:id' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/label_groups/#{label_group.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an agent' do
      it 'returns unauthorized' do
        agent = create(:user, account: account, role: :agent)

        get "/api/v1/accounts/#{account.id}/label_groups/#{label_group.id}",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an administrator' do
      let(:admin) { create(:user, account: account, role: :administrator) }

      it 'shows the label group' do
        get "/api/v1/accounts/#{account.id}/label_groups/#{label_group.id}",
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(JSON.parse(response.body)['id']).to eq(label_group.id)
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/label_groups' do
    let(:valid_params) { { label_group: { name: 'temperature', team_id: team.id } } }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        expect do
          post "/api/v1/accounts/#{account.id}/label_groups", params: valid_params
        end.not_to change(LabelGroup, :count)

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an agent' do
      it 'returns unauthorized' do
        agent = create(:user, account: account, role: :agent)

        expect do
          post "/api/v1/accounts/#{account.id}/label_groups",
               headers: agent.create_new_auth_token,
               params: valid_params
        end.not_to change(LabelGroup, :count)

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an administrator' do
      let(:admin) { create(:user, account: account, role: :administrator) }

      it 'creates the label group and returns it with team_id in the JSON' do
        expect do
          post "/api/v1/accounts/#{account.id}/label_groups",
               headers: admin.create_new_auth_token,
               params: valid_params
        end.to change(LabelGroup, :count).by(1)

        expect(response).to have_http_status(:success)
        expect(JSON.parse(response.body)['team_id']).to eq(team.id)
        expect(LabelGroup.last.name).to eq('temperature')
      end

      it 'returns a validation error when the label group name is already used by the team' do
        create(:label_group, account: account, team: team, name: 'temperature')

        expect do
          post "/api/v1/accounts/#{account.id}/label_groups",
               headers: admin.create_new_auth_token,
               params: valid_params
        end.not_to change(LabelGroup, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'PATCH /api/v1/accounts/{account.id}/label_groups/:id' do
    let(:valid_params) { { label_group: { name: 'cold' } } }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        patch "/api/v1/accounts/#{account.id}/label_groups/#{label_group.id}",
              params: valid_params

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an agent' do
      it 'returns unauthorized' do
        agent = create(:user, account: account, role: :agent)

        patch "/api/v1/accounts/#{account.id}/label_groups/#{label_group.id}",
              headers: agent.create_new_auth_token,
              params: valid_params

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an administrator' do
      let(:admin) { create(:user, account: account, role: :administrator) }

      it 'updates the label group' do
        patch "/api/v1/accounts/#{account.id}/label_groups/#{label_group.id}",
              headers: admin.create_new_auth_token,
              params: valid_params,
              as: :json

        expect(response).to have_http_status(:success)
        expect(label_group.reload.name).to eq('cold')
      end
    end
  end

  describe 'DELETE /api/v1/accounts/{account.id}/label_groups/:id' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        delete "/api/v1/accounts/#{account.id}/label_groups/#{label_group.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an agent' do
      it 'returns unauthorized' do
        agent = create(:user, account: account, role: :agent)

        delete "/api/v1/accounts/#{account.id}/label_groups/#{label_group.id}",
               headers: agent.create_new_auth_token,
               as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an administrator' do
      let(:admin) { create(:user, account: account, role: :administrator) }

      it 'deletes the label group' do
        delete "/api/v1/accounts/#{account.id}/label_groups/#{label_group.id}",
               headers: admin.create_new_auth_token,
               as: :json

        expect(response).to have_http_status(:ok)
        expect(LabelGroup.exists?(label_group.id)).to be(false)
      end

      it 'nullifies the label_group_id of associated labels without destroying them' do
        label = create(:label, account: account, team: team, label_group: label_group)

        delete "/api/v1/accounts/#{account.id}/label_groups/#{label_group.id}",
               headers: admin.create_new_auth_token,
               as: :json

        expect(response).to have_http_status(:ok)
        expect(Label.exists?(label.id)).to be(true)
        expect(label.reload.label_group_id).to be_nil
      end
    end
  end
end
