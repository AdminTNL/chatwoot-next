require 'rails_helper'

RSpec.describe 'Rede API Tokens API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:base_url) { "/api/v1/accounts/#{account.id}/rede/api_tokens" }
  let(:admin_headers) { administrator.create_new_auth_token }
  let(:agent_headers) { agent.create_new_auth_token }

  describe 'POST /rede/api_tokens' do
    it 'returns unauthorized when unauthenticated' do
      post base_url, params: { name: 'Formulários Central' }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns unauthorized for an agent and creates nothing' do
      post base_url, headers: agent_headers, params: { name: 'Formulários Central' }, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(Rede::ApiToken.count).to eq(0)
    end

    it 'creates the token for the administrator and returns the value once' do
      post base_url, headers: admin_headers, params: { name: 'Formulários Central' }, as: :json

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body.keys).to match_array(%w[id name token_prefix token scopes created_at])
      expect(body).to include('name' => 'Formulários Central', 'scopes' => ['projects:read'])
      expect(body['token']).to match(/\Arede_[A-Za-z0-9]{40}\z/)
      expect(body['token_prefix']).to eq(body['token'][0, 8])
      record = Rede::ApiToken.find(body['id'])
      expect(record).to have_attributes(account_id: account.id, created_by_user_id: administrator.id)
      expect(record.token_digest).to eq(Digest::SHA256.hexdigest(body['token']))
    end

    it 'ignores client supplied scopes' do
      post base_url, headers: admin_headers, params: { name: 'Token', scopes: ['projects:write'] }, as: :json

      expect(response.parsed_body['scopes']).to eq(['projects:read'])
    end

    it 'returns 422 without a name' do
      post base_url, headers: admin_headers, params: { name: '' }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'GET /rede/api_tokens' do
    let!(:active_token) { create(:rede_api_token, account: account, name: 'Ativo', last_used_at: 1.hour.ago) }
    let!(:revoked_token) { create(:rede_api_token, account: account, name: 'Revogado', revoked_at: 1.day.ago) }

    before { create(:rede_api_token) }

    it 'lists the tokens of the account without the value' do
      get base_url, headers: admin_headers, as: :json

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body.pluck('id')).to contain_exactly(active_token.id, revoked_token.id)
      expect(body.first.keys).to match_array(%w[id name token_prefix scopes created_by_user_id last_used_at revoked_at created_at])
      expect(response.body).not_to include(active_token.token_digest)
    end

    it 'does not list the value created earlier' do
      post base_url, headers: admin_headers, params: { name: 'Formulários Central' }, as: :json
      plain = response.parsed_body['token']

      get base_url, headers: admin_headers, as: :json

      expect(response.parsed_body.find { |item| item['name'] == 'Formulários Central' }).not_to have_key('token')
      expect(response.body).not_to include(plain)
    end

    it 'returns unauthorized for an agent' do
      get base_url, headers: agent_headers, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /rede/api_tokens/:id/revoke' do
    let!(:token) { create(:rede_api_token, account: account) }

    it 'revokes the token for the administrator, idempotently' do
      2.times do
        post "#{base_url}/#{token.id}/revoke", headers: admin_headers, as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body['revoked_at']).to be_present
      end
      expect(token.reload).to be_revoked
    end

    it 'returns unauthorized for an agent' do
      post "#{base_url}/#{token.id}/revoke", headers: agent_headers, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(token.reload).not_to be_revoked
    end

    it 'returns 404 for a token of another account' do
      foreign = create(:rede_api_token)

      post "#{base_url}/#{foreign.id}/revoke", headers: admin_headers, as: :json

      expect(response).to have_http_status(:not_found)
      expect(foreign.reload).not_to be_revoked
    end
  end
end
