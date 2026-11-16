require 'rails_helper'

RSpec.describe 'Rede external projects API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:url) { '/api/rede/v1/projects' }
  let(:token_pair) { Rede::ApiToken.generate!(account: account, name: 'Formulários Central', user: administrator) }
  let(:api_token) { token_pair.first }
  let(:plain) { token_pair.last }
  let(:headers) { { 'Authorization' => "Bearer #{plain}" } }
  let!(:team_b) { create(:team, account: account, name: 'beta') }
  let!(:team_a) { create(:team, account: account, name: 'alfa') }
  let(:project_a) { team_a.rede_project }
  let(:project_b) { team_b.rede_project }

  before do
    project_a.update!(name: 'Alfa', color: '#1F93FF')
    project_b.update!(name: 'Beta', color: '#E5484D')
  end

  describe 'GET /api/rede/v1/projects' do
    let!(:front_b) { create(:rede_front, account: account, project: project_a, name: 'PE Digital', has_temperature: false) }
    let!(:front_a) { create(:rede_front, account: account, project: project_a, name: 'PE Campo') }

    it 'lists the projects by name with the public fields only' do
      get url, headers: headers

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body.pluck('name')).to eq(%w[Alfa Beta])
      expect(body.first.keys).to match_array(%w[id name status color updated_at fronts])
      expect(body.first).to include('id' => project_a.slug, 'name' => 'Alfa', 'status' => 'active', 'color' => '#1F93FF')
      expect(response.body).not_to match(/team|inbox|member|contact|account_id/)
    end

    it 'lists fronts by public_id with the public fields only' do
      get url, headers: headers

      fronts = response.parsed_body.first['fronts']
      expect(fronts.pluck('name')).to eq(['PE Campo', 'PE Digital'])
      expect(fronts.first.keys).to match_array(%w[id name status has_temperature updated_at])
      expect(fronts.first).to include('id' => front_a.reload.public_id, 'has_temperature' => true, 'status' => 'active')
      expect(fronts.last).to include('id' => front_b.reload.public_id, 'has_temperature' => false)
    end

    it 'returns fronts as an empty list for a project without fronts' do
      get url, headers: headers

      expect(response.parsed_body.last).to include('name' => 'Beta', 'fronts' => [])
    end

    it 'includes closed projects and closed fronts' do
      project_b.close!
      front_a.close!

      get url, headers: headers

      body = response.parsed_body
      expect(body.last['status']).to eq('closed')
      expect(body.first['fronts'].pluck('status')).to match_array(%w[closed active])
    end

    it 'keeps the project id after a rename' do
      expect { project_a.update!(name: 'Zeta') }.not_to(change { project_a.reload.slug })

      get url, headers: headers

      expect(response.parsed_body.pluck('id')).to include(project_a.slug)
      expect(response.parsed_body.pluck('name')).to eq(%w[Beta Zeta])
    end

    it 'reads only the account of the token' do
      other_team = create(:team, account: create(:account), name: 'estrangeiro')

      get url, headers: headers

      expect(response.parsed_body.pluck('id')).not_to include(other_team.rede_project.slug)
      expect(response.parsed_body.size).to eq(2)
    end

    it 'conforms to the swagger schema' do
      get url, headers: headers

      expect(response).to conform_schema(200)
    end

    it 'sets no cookies' do
      get url, headers: headers

      expect(response.headers['Set-Cookie']).to be_nil
    end

    it 'does not set Current.user' do
      get url, headers: headers

      expect(response).to have_http_status(:ok)
      expect(Current.user).to be_nil
    end
  end

  describe 'authentication' do
    it 'returns 401 invalid_token without the header' do
      get url

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body).to eq('error' => 'invalid_token')
    end

    it 'returns the same 401 for an unknown token' do
      get url, headers: { 'Authorization' => 'Bearer rede_naoexiste' }

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body).to eq('error' => 'invalid_token')
    end

    it 'returns 401 for a revoked token' do
      headers
      api_token.revoke!

      get url, headers: headers

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body).to eq('error' => 'invalid_token')
    end

    it 'returns 401 for another authorization scheme' do
      get url, headers: { 'Authorization' => "Token #{plain}" }

      expect(response).to have_http_status(:unauthorized)
    end

    it 'does not accept a user api_access_token' do
      get url, headers: { 'api_access_token' => administrator.access_token.token }

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 403 when the token lacks the projects:read scope' do
      create(:rede_api_token, account: account, scopes: [], plain_value: 'rede_semescopo')

      get url, headers: { 'Authorization' => 'Bearer rede_semescopo' }

      expect(response).to have_http_status(:forbidden)
    end

    it 'updates last_used_at' do
      get url, headers: headers

      expect(api_token.reload.last_used_at).to be_present
    end
  end

  describe 'ETag' do
    it 'returns 304 for the same If-None-Match when nothing changed' do
      get url, headers: headers
      etag = response.headers['ETag']

      expect(etag).to be_present

      get url, headers: headers.merge('If-None-Match' => etag)

      expect(response).to have_http_status(:not_modified)
    end

    it 'returns the same ETag for the same data' do
      get url, headers: headers
      first = response.headers['ETag']

      get url, headers: headers

      expect(response.headers['ETag']).to eq(first)
    end

    it 'returns 200 with a new ETag after a front is edited' do
      front = create(:rede_front, account: account, project: project_a, name: 'PE Campo')
      get url, headers: headers
      etag = response.headers['ETag']

      travel(2.seconds) { front.update!(name: 'PE Rural') }
      get url, headers: headers.merge('If-None-Match' => etag)

      expect(response).to have_http_status(:ok)
      expect(response.headers['ETag']).not_to eq(etag)
    end

    it 'returns a new ETag after a front is created' do
      get url, headers: headers
      etag = response.headers['ETag']

      create(:rede_front, account: account, project: project_a, name: 'PE Nova')
      get url, headers: headers.merge('If-None-Match' => etag)

      expect(response).to have_http_status(:ok)
      expect(response.headers['ETag']).not_to eq(etag)
    end

    it 'returns a new ETag after a front is closed' do
      front = create(:rede_front, account: account, project: project_a, name: 'PE Campo')
      get url, headers: headers
      etag = response.headers['ETag']

      travel(2.seconds) { front.close! }
      get url, headers: headers.merge('If-None-Match' => etag)

      expect(response).to have_http_status(:ok)
      expect(response.headers['ETag']).not_to eq(etag)
    end
  end

  describe 'suspended account' do
    it 'returns 401 invalid_token when the account is suspended' do
      account.update!(status: :suspended)

      get url, headers: headers

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body['error']).to eq('invalid_token')
    end
  end
end
