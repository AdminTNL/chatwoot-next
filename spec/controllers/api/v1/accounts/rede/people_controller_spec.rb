require 'rails_helper'

RSpec.describe 'Rede People API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:member_agent) { create(:user, account: account, role: :agent) }
  let(:outsider_agent) { create(:user, account: account, role: :agent) }
  let!(:pe_team) { create(:team, account: account, name: 'pe') }
  let!(:pa_team) { create(:team, account: account, name: 'pa') }
  let(:pe) { pe_team.rede_project }
  let(:pa) { pa_team.rede_project }
  let(:ana) { create(:contact, account: account, name: 'Ana', phone_number: '+5511988998899', additional_attributes: { 'city' => 'Recife' }) }
  let(:bruna) { create(:contact, account: account, name: 'Bruna', phone_number: '+5511977771111') }
  let!(:pe_campo) { create(:rede_front, account: account, project: pe, name: 'PE Campo') }
  let!(:pe_digital) { create(:rede_front, account: account, project: pe, name: 'PE Digital') }
  let!(:pe_participation) { create(:rede_participation, account: account, project: pe, contact: ana) }

  before do
    create(:rede_participation, account: account, project: pa, contact: ana)
    create(:rede_participation, account: account, project: pe, contact: bruna)
    create(:team_member, team: pe_team, user: member_agent)
    create(:rede_assignment, account: account, participation: pe_participation, front: pe_campo)
    create(:rede_assignment, account: account, participation: pe_participation, front: pe_digital)
    create(:rede_evaluation, account: account, contact: ana, project: pe, front: pe_campo, level: 'quente')
  end

  def admin_headers = administrator.create_new_auth_token
  def agent_headers = member_agent.create_new_auth_token
  def outsider_headers = outsider_agent.create_new_auth_token
  def url = "/api/v1/accounts/#{account.id}/rede/people"

  describe 'GET /people' do
    it 'returns unauthorized when unauthenticated' do
      get url

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns the rows and the meta for an administrator' do # rubocop:disable RSpec/MultipleExpectations
      get url, headers: admin_headers

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body['meta']).to eq('count' => 4, 'page' => 1, 'per_page' => 25)
      expect(body['payload'].size).to eq(4)
      campo_row = body['payload'].find { |row| row['front'] && row['front']['id'] == pe_campo.id }
      expect(campo_row).to include('participation_id' => pe_participation.id, 'temperature' => 'quente', 'front_pending' => false,
                                   'role' => nil, 'responsible' => nil, 'last_contact_at' => nil, 'next_step' => nil)
      expect(campo_row['row_key']).to eq("#{pe_participation.id}-#{campo_row['assignment_id']}")
      expect(campo_row['contact']).to include('id' => ana.id, 'name' => 'Ana', 'phone_number' => '+5511988998899', 'city' => 'Recife')
      expect(campo_row['contact']).to have_key('avatar_url')
      expect(campo_row['project']).to include('id' => pe.id, 'slug' => pe.slug, 'name' => pe.name, 'color' => pe.color, 'status' => 'active')
      pending_row = body['payload'].find { |row| row['contact']['id'] == bruna.id }
      expect(pending_row).to include('front' => nil, 'front_pending' => true, 'temperature' => nil, 'assignment_id' => nil)
    end

    it 'applies filters and pagination' do
      get url, headers: admin_headers, params: { project_ids: [pe.id], per_page: 2, page: 2 }

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['meta']).to eq('count' => 3, 'page' => 2, 'per_page' => 2)
      expect(response.parsed_body['payload'].size).to eq(1)
    end

    it 'applies the temperature filter' do
      get url, headers: admin_headers, params: { temperatures: ['quente'] }

      expect(response.parsed_body['payload'].map { |row| row['front']['name'] }).to eq(['PE Campo'])
    end

    it 'limits an agent to the rows of their projects' do
      get url, headers: agent_headers

      expect(response.parsed_body['meta']['count']).to eq(3)
      expect(response.parsed_body['payload'].map { |row| row['project']['id'] }.uniq).to eq([pe.id])
    end

    it 'ignores a project filter outside the scope' do
      get url, headers: agent_headers, params: { project_ids: [pa.id] }

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['meta']['count']).to eq(0)
      expect(response.parsed_body['payload']).to eq([])
    end

    it 'returns nothing for an agent without projects' do
      get url, headers: outsider_headers

      expect(response.parsed_body['meta']['count']).to eq(0)
    end
  end

  describe 'GET /people/:id' do
    it 'returns unauthorized when unauthenticated' do
      get "#{url}/#{ana.id}"

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns the whole profile for an administrator' do # rubocop:disable RSpec/MultipleExpectations
      get "#{url}/#{ana.id}", headers: admin_headers

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body['contact']).to include('id' => ana.id, 'name' => 'Ana', 'phone_number' => '+5511988998899', 'city' => 'Recife')
      expect(body['participations'].map { |item| item['project']['id'] }).to contain_exactly(pe.id, pa.id)
      pe_item = body['participations'].find { |item| item['project']['id'] == pe.id }
      expect(pe_item['project']).to include('slug' => pe.slug, 'has_fronts' => true)
      expect(pe_item['assignments'].size).to eq(2)
      expect(pe_item['assignments'].find { |item| item['front']['id'] == pe_campo.id }['temperature']).to eq('quente')
      expect(pe_item).to include('front_pending' => false, 'referred_by' => { 'contact' => nil, 'text' => nil })
      pa_item = body['participations'].find { |item| item['project']['id'] == pa.id }
      expect(pa_item['project']['has_fronts']).to be(false)
      expect(pa_item).to have_key('project_temperature')
    end

    it 'shows an agent only the projects of their teams' do
      get "#{url}/#{ana.id}", headers: agent_headers

      expect(response.parsed_body['participations'].map { |item| item['project']['id'] }).to eq([pe.id])
    end

    it 'returns 404 when the person has no participation visible to the user' do
      create(:team_member, team: pa_team, user: outsider_agent)

      get "#{url}/#{bruna.id}", headers: outsider_headers

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 for a contact of another account' do
      foreign = create(:contact, account: create(:account))

      get "#{url}/#{foreign.id}", headers: admin_headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /people/:id/timeline' do
    let(:timeline_url) { "#{url}/#{ana.id}/timeline" }

    before do
      create(:rede_interaction, account: account, project: pe, contact: ana, kind: :call, answered: true, occurred_at: 2.hours.ago)
      create(:rede_interaction, :note, account: account, project: pa, contact: ana, occurred_at: 1.hour.ago)
    end

    it 'returns unauthorized when unauthenticated' do
      get timeline_url

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns events and meta for an administrator' do
      get timeline_url, headers: admin_headers

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body['payload'].pluck('type')).to include('call', 'note', 'temperature_change', 'assignment_change')
      expect(body['payload'].first.keys).to include('type', 'occurred_at', 'project', 'front', 'author', 'data')
      expect(body['meta']).to include('limit' => 30, 'next_cursor' => nil)
    end

    it 'does not leak other projects to an agent and applies filters' do
      get timeline_url, headers: agent_headers, params: { types: ['call'] }

      expect(response.parsed_body['payload'].pluck('type')).to eq(['call'])
      get timeline_url, headers: agent_headers

      expect(response.parsed_body['payload'].map { |item| item['project']['id'] }.uniq).to eq([pe.id])
      expect(response.parsed_body['payload'].pluck('type')).not_to include('note')
    end

    it 'paginates with a cursor' do
      get timeline_url, headers: admin_headers, params: { limit: 2 }
      first_page = response.parsed_body
      get timeline_url, headers: admin_headers, params: { limit: 2, before: first_page['meta']['next_cursor'] }

      expect(first_page['payload'].size).to eq(2)
      expect(response.parsed_body['payload'].size).to eq(2)
      expect(first_page['payload'] & response.parsed_body['payload']).to be_empty
    end

    it 'returns 404 when the person has no participation visible to the user' do
      create(:team_member, team: pa_team, user: outsider_agent)

      get "#{url}/#{bruna.id}/timeline", headers: outsider_headers

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 for a project filter outside the scope' do
      get timeline_url, headers: agent_headers, params: { project_id: pa.id }

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 422 when from is after to or a date is invalid' do
      get timeline_url, headers: admin_headers, params: { from: '2026-05-03', to: '2026-05-02' }
      expect(response).to have_http_status(:unprocessable_entity)

      get timeline_url, headers: admin_headers, params: { from: 'xx' }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'GET /people/filters' do
    let(:filters_url) { "#{url}/filters" }

    it 'returns unauthorized when unauthenticated' do
      get filters_url

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns every project with fronts and the possible responsibles for an administrator' do
      get filters_url, headers: admin_headers

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body['projects'].map { |project| project['id'] }).to contain_exactly(pe.id, pa.id)
      pe_json = body['projects'].find { |project| project['id'] == pe.id }
      expect(pe_json).to include('slug' => pe.slug, 'name' => pe.name, 'color' => pe.color)
      expect(pe_json['fronts'].map { |front| front['name'] }).to eq(['PE Campo', 'PE Digital'])
      expect(body['responsibles'].map { |user| user['id'] }).to contain_exactly(administrator.id, member_agent.id)
    end

    it 'limits projects and responsibles to the scope of the agent' do
      create(:team_member, team: pa_team, user: outsider_agent)
      administrator

      get filters_url, headers: agent_headers

      body = response.parsed_body
      expect(body['projects'].map { |project| project['id'] }).to eq([pe.id])
      expect(body['responsibles'].map { |user| user['id'] }).to contain_exactly(administrator.id, member_agent.id)
    end
  end
end
