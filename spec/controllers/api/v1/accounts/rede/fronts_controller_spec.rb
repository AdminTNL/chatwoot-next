require 'rails_helper'

RSpec.describe 'Rede Fronts API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:member_agent) { create(:user, account: account, role: :agent) }
  let(:other_agent) { create(:user, account: account, role: :agent) }
  let!(:member_team) { create(:team, account: account, name: 'meu time') }
  let!(:other_team) { create(:team, account: account, name: 'outro time') }
  let(:project) { member_team.rede_project }
  let(:other_project) { other_team.rede_project }
  let(:base_url) { "/api/v1/accounts/#{account.id}/rede/projects/#{project.id}/fronts" }
  let(:admin_headers) { administrator.create_new_auth_token }
  let(:agent_headers) { member_agent.create_new_auth_token }

  before { create(:team_member, team: member_team, user: member_agent) }

  describe 'GET /rede/projects/:project_id/fronts' do
    let!(:closed_front) { create(:rede_front, account: account, project: project, name: 'Antiga', status: :closed, closed_at: Time.current) }
    let!(:front_b) { create(:rede_front, account: account, project: project, name: 'PE Digital') }
    let!(:front_a) { create(:rede_front, account: account, project: project, name: 'PE Campo') }

    it 'returns unauthorized when unauthenticated' do
      get base_url

      expect(response).to have_http_status(:unauthorized)
    end

    it 'lists active fronts by name, then closed ones, for a member agent' do
      get base_url, headers: agent_headers, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.pluck('id')).to eq([front_a.id, front_b.id, closed_front.id])
    end

    it 'renders the front fields' do
      get base_url, headers: agent_headers, as: :json

      expect(response.parsed_body.first).to include(
        'id' => front_a.id, 'public_id' => front_a.reload.public_id, 'name' => 'PE Campo',
        'has_temperature' => true, 'status' => 'active', 'closed_at' => nil
      )
    end

    it 'lists the fronts of any project for the administrator' do
      get base_url, headers: admin_headers, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.size).to eq(3)
    end

    it 'returns 404 for an agent outside the team' do
      get base_url, headers: other_agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 for a project of another account' do
      foreign_project = create(:team, account: create(:account)).rede_project

      get "/api/v1/accounts/#{account.id}/rede/projects/#{foreign_project.id}/fronts", headers: admin_headers, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /rede/projects/:project_id/fronts' do
    it 'creates fronts for the administrator' do
      post base_url, headers: admin_headers, params: { name: 'PE Digital', has_temperature: false }, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include('name' => 'PE Digital', 'has_temperature' => false, 'status' => 'active')
      expect(project.fronts.pluck(:name)).to eq(['PE Digital'])
      expect(project.fronts.first.account_id).to eq(account.id)
    end

    it 'defaults has_temperature to true' do
      post base_url, headers: admin_headers, params: { name: 'PE Campo' }, as: :json

      expect(response.parsed_body['has_temperature']).to be(true)
    end

    it 'returns 422 for the same name ignoring case in the project' do
      create(:rede_front, account: account, project: project, name: 'PE Digital')

      post base_url, headers: admin_headers, params: { name: 'pe digital' }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'allows the same name in another project' do
      create(:rede_front, account: account, project: other_project, name: 'PE Digital')

      post base_url, headers: admin_headers, params: { name: 'PE Digital' }, as: :json

      expect(response).to have_http_status(:success)
    end

    it 'accepts a new front in a closed project' do
      project.close!

      post base_url, headers: admin_headers, params: { name: 'PE Digital' }, as: :json

      expect(response).to have_http_status(:success)
    end

    it 'returns unauthorized for a member agent' do
      post base_url, headers: agent_headers, params: { name: 'PE Digital' }, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(project.fronts).to be_empty
    end
  end

  describe 'PATCH /rede/projects/:project_id/fronts/:id' do
    let!(:front) { create(:rede_front, account: account, project: project, name: 'PE Digital') }

    it 'updates name and has_temperature, ignoring public_id' do
      original = front.reload.public_id

      patch "#{base_url}/#{front.id}", headers: admin_headers,
                                       params: { name: 'PE Online', has_temperature: false, public_id: SecureRandom.uuid }, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include('name' => 'PE Online', 'has_temperature' => false, 'public_id' => original)
      expect(front.reload.public_id).to eq(original)
    end

    it 'returns 422 for a duplicated name' do
      create(:rede_front, account: account, project: project, name: 'PE Campo')

      patch "#{base_url}/#{front.id}", headers: admin_headers, params: { name: 'pe campo' }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns unauthorized for a member agent' do
      patch "#{base_url}/#{front.id}", headers: agent_headers, params: { name: 'Outro' }, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(front.reload.name).to eq('PE Digital')
    end

    it 'returns 404 for a front of another project' do
      foreign = create(:rede_front, account: account, project: other_project)

      patch "#{base_url}/#{foreign.id}", headers: admin_headers, params: { name: 'Outro' }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 for a front of another account' do
      foreign = create(:rede_front)

      patch "#{base_url}/#{foreign.id}", headers: admin_headers, params: { name: 'Outro' }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST close and reopen' do
    let!(:front) { create(:rede_front, account: account, project: project) }

    it 'closes the front, idempotently' do
      2.times do
        post "#{base_url}/#{front.id}/close", headers: admin_headers, as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body['status']).to eq('closed')
      end
      expect(front.reload.closed_at).to be_present
    end

    it 'reopens the front, idempotently' do
      front.close!

      2.times do
        post "#{base_url}/#{front.id}/reopen", headers: admin_headers, as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body).to include('status' => 'active', 'closed_at' => nil)
      end
    end

    it 'returns unauthorized for a member agent' do
      post "#{base_url}/#{front.id}/close", headers: agent_headers, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(front.reload).to be_active
    end
  end

  describe 'DELETE' do
    it 'has no delete endpoint' do
      front = create(:rede_front, account: account, project: project)

      delete "#{base_url}/#{front.id}", headers: admin_headers, as: :json

      expect(response).to have_http_status(:not_found)
      expect(Rede::Front.exists?(front.id)).to be(true)
    end
  end
end
