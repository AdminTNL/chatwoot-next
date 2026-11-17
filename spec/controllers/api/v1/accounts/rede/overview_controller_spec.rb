require 'rails_helper'

RSpec.describe 'Rede Overview API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:pe_agent) { create(:user, account: account, role: :agent) }
  let(:outsider_agent) { create(:user, account: account, role: :agent) }
  let!(:pe_team) { create(:team, account: account, name: 'pe') }
  let!(:pa_team) { create(:team, account: account, name: 'pa') }
  let(:pe) { pe_team.rede_project }
  let(:pa) { pa_team.rede_project }
  let(:ana) { create(:contact, account: account, name: 'Ana') }
  let(:bruna) { create(:contact, account: account, name: 'Bruna') }
  let!(:campo) { create(:rede_front, account: account, project: pe, name: 'Campo') }
  let!(:digital) { create(:rede_front, account: account, project: pe, name: 'Digital') }
  let!(:ana_pe) { create(:rede_participation, account: account, project: pe, contact: ana) }

  before do
    create(:rede_participation, account: account, project: pa, contact: ana)
    create(:rede_participation, account: account, project: pe, contact: bruna)
    create(:team_member, team: pe_team, user: pe_agent)
    create(:rede_assignment, account: account, participation: ana_pe, front: campo)
    create(:rede_assignment, account: account, participation: ana_pe, front: digital)
    create(:rede_evaluation, account: account, contact: ana, project: pe, front: campo, level: 'quente')
  end

  def url = "/api/v1/accounts/#{account.id}/rede/overview"

  describe 'GET /overview' do
    it 'returns unauthorized when unauthenticated' do
      get url

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns the numbers, filters and recent changes for an administrator' do
      get url, headers: administrator.create_new_auth_token

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body).to include('people_count' => 2, 'front_participations_count' => 2, 'pending_front_count' => 1, 'no_contact_7d_count' => 4)
      expect(body['by_temperature']).to eq('vapor' => 0, 'quente' => 1, 'morno' => 0, 'frio' => 0, 'none' => 3)
      expect(body['filters']['no_contact_7d']).to eq('no_contact_days' => 7, 'project_ids' => [pe.id, pa.id].sort)
      expect(body['filters']['by_temperature']['quente']).to include('temperatures' => ['quente'])
      expect(body['recent_changes'].size).to be_between(1, 10)
      expect(body['recent_changes'].first).to include('type', 'occurred_at', 'project', 'contact', 'data')
    end

    it 'restricts to the project of project_id' do
      get url, headers: administrator.create_new_auth_token, params: { project_id: pa.id }

      expect(response.parsed_body).to include('people_count' => 1, 'front_participations_count' => 0, 'pending_front_count' => 0)
    end

    it 'shows only the projects of the agent' do
      get url, headers: pe_agent.create_new_auth_token

      expect(response.parsed_body).to include('people_count' => 2, 'front_participations_count' => 2)
      expect(response.parsed_body['filters']['people']['project_ids']).to eq([pe.id])
    end

    it 'returns not found for a project outside the scope of the agent' do
      get url, headers: pe_agent.create_new_auth_token, params: { project_id: pa.id }

      expect(response).to have_http_status(:not_found)
    end

    it 'returns zeros for an agent without projects' do
      get url, headers: outsider_agent.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include('people_count' => 0, 'recent_changes' => [])
    end

    it 'gives numbers that match the people list called with the returned filters' do
      headers = administrator.create_new_auth_token
      get url, headers: headers
      body = response.parsed_body
      people_url = "/api/v1/accounts/#{account.id}/rede/people"
      cards = { 'front_participations' => 'front_participations_count', 'pending_front' => 'pending_front_count',
                'no_contact_7d' => 'no_contact_7d_count' }

      cards.each do |filter, count|
        get people_url, headers: headers, params: body['filters'][filter]
        expect(response.parsed_body['meta']['count']).to eq(body[count]), filter
      end
      body['by_temperature'].each do |level, count|
        get people_url, headers: headers, params: body['filters']['by_temperature'][level]
        expect(response.parsed_body['meta']['count']).to eq(count), level
      end
    end

    it 'returns not found for an unknown project' do
      get url, headers: administrator.create_new_auth_token, params: { project_id: 0 }

      expect(response).to have_http_status(:not_found)
    end
  end
end
