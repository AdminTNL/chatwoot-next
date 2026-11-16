require 'rails_helper'

RSpec.describe 'Rede Projects API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:member_agent) { create(:user, account: account, role: :agent) }
  let(:other_agent) { create(:user, account: account, role: :agent) }
  let!(:member_team) { create(:team, account: account, name: 'meu time') }
  let!(:other_team) { create(:team, account: account, name: 'outro time') }
  let(:member_project) { member_team.rede_project }
  let(:other_project) { other_team.rede_project }
  let(:base_url) { "/api/v1/accounts/#{account.id}/rede/projects" }

  before do
    create(:team_member, team: member_team, user: member_agent)
    create(:team_member, team: other_team, user: administrator)
  end

  describe 'GET /rede/projects' do
    it 'returns unauthorized when unauthenticated' do
      get base_url

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns all projects, including closed ones, for the administrator' do
      other_project.update!(status: :closed, closed_at: Time.current)

      get base_url, headers: administrator.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.pluck('id')).to contain_exactly(member_project.id, other_project.id)
    end

    it 'returns only the projects of teams the agent belongs to' do
      get base_url, headers: member_agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.pluck('id')).to eq([member_project.id])
    end

    it 'returns nothing to an agent without teams' do
      get base_url, headers: other_agent.create_new_auth_token, as: :json

      expect(response.parsed_body).to eq([])
    end

    it 'does not leak projects of another account' do
      create(:team, account: create(:account))

      get base_url, headers: administrator.create_new_auth_token, as: :json

      expect(response.parsed_body.size).to eq(2)
    end

    it 'renders the project fields' do
      create(:inbox, account: account, team: member_team)

      get base_url, headers: member_agent.create_new_auth_token, as: :json

      expect(response.parsed_body.first).to include(
        'id' => member_project.id, 'slug' => member_project.slug, 'name' => 'Meu Time', 'color' => member_project.color,
        'status' => 'active', 'closed_at' => nil, 'team_id' => member_team.id, 'team_name' => 'meu time',
        'is_member' => true, 'inboxes_count' => 1, 'members_count' => 1
      )
      expect(response.parsed_body.first.keys).to include('created_at', 'updated_at')
    end
  end

  describe 'GET /rede/projects/:id' do
    it 'shows the project to a member agent' do
      get "#{base_url}/#{member_project.id}", headers: member_agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['id']).to eq(member_project.id)
    end

    it 'returns 404 for an agent outside the team' do
      get "#{base_url}/#{other_project.id}", headers: member_agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'shows any project to the administrator' do
      get "#{base_url}/#{member_project.id}", headers: administrator.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['is_member']).to be(false)
    end

    it 'returns 404 for a project of another account' do
      foreign = create(:team, account: create(:account)).rede_project

      get "#{base_url}/#{foreign.id}", headers: administrator.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /rede/projects' do
    let(:params) { { name: 'Mobiliza Pará', color: '#1F93FF' } }

    it 'returns unauthorized when unauthenticated' do
      post base_url, params: params, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns unauthorized for an agent' do
      expect { post base_url, params: params, headers: member_agent.create_new_auth_token, as: :json }.not_to change(Team, :count)

      expect(response).to have_http_status(:unauthorized)
    end

    it 'creates the team and the project' do
      expect { post base_url, params: params, headers: administrator.create_new_auth_token, as: :json }
        .to change(Team, :count).by(1).and change(Rede::Project, :count).by(1)

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include('name' => 'Mobiliza Pará', 'slug' => 'mobiliza-para', 'color' => '#1F93FF', 'status' => 'active')
      expect(account.teams.find_by(name: 'mobiliza pará')).to be_present
    end

    it 'stores description and icon on the team' do
      post base_url, params: params.merge(description: 'desc', icon: 'i-lucide-star', icon_color: '#112233'),
                     headers: administrator.create_new_auth_token, as: :json

      expect(account.teams.find_by(name: 'mobiliza pará')).to have_attributes(description: 'desc', icon: 'i-lucide-star', icon_color: '#112233')
    end

    it 'returns 422 for an invalid color and creates nothing' do
      expect do
        post base_url, params: params.merge(color: 'azul'), headers: administrator.create_new_auth_token, as: :json
      end.not_to change(Team, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 422 for a blank name' do
      post base_url, params: params.merge(name: ''), headers: administrator.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 422 when the name collides with an existing team' do
      post base_url, params: params.merge(name: 'Meu Time'), headers: administrator.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'PATCH /rede/projects/:id' do
    it 'returns unauthorized for an agent, even a member' do
      patch "#{base_url}/#{member_project.id}", params: { name: 'Novo' }, headers: member_agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'updates name (and team name), color and description' do
      patch "#{base_url}/#{member_project.id}", params: { name: 'Mobiliza PA', color: '#00FF00', description: 'nova' },
                                                headers: administrator.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(member_project.reload).to have_attributes(name: 'Mobiliza PA', color: '#00FF00')
      expect(member_team.reload).to have_attributes(name: 'mobiliza pa', description: 'nova')
    end

    it 'ignores the slug' do
      slug = member_project.slug

      patch "#{base_url}/#{member_project.id}", params: { slug: 'hack', name: 'Outro' },
                                                headers: administrator.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(member_project.reload.slug).to eq(slug)
    end

    it 'returns 422 and changes nothing when the name collides with another team' do
      patch "#{base_url}/#{member_project.id}", params: { name: 'Outro Time', color: '#00FF00' },
                                                headers: administrator.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(member_project.reload).to have_attributes(name: 'Meu Time', color: member_project.color)
      expect(member_team.reload.name).to eq('meu time')
    end

    it 'returns 422 for an invalid color' do
      patch "#{base_url}/#{member_project.id}", params: { color: 'x' }, headers: administrator.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'POST /rede/projects/:id/close and /reopen' do
    it 'returns unauthorized for an agent' do
      post "#{base_url}/#{member_project.id}/close", headers: member_agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unauthorized)

      post "#{base_url}/#{member_project.id}/reopen", headers: member_agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it 'closes the project and is idempotent' do
      2.times do
        post "#{base_url}/#{member_project.id}/close", headers: administrator.create_new_auth_token, as: :json
        expect(response).to have_http_status(:success)
      end

      expect(member_project.reload.status).to eq('closed')
      expect(member_project.closed_at).to be_present
      expect(response.parsed_body['status']).to eq('closed')
    end

    it 'does not move closed_at when closing twice' do
      post "#{base_url}/#{member_project.id}/close", headers: administrator.create_new_auth_token, as: :json
      closed_at = member_project.reload.closed_at

      post "#{base_url}/#{member_project.id}/close", headers: administrator.create_new_auth_token, as: :json

      expect(member_project.reload.closed_at).to eq(closed_at)
    end

    it 'reopens the project and is idempotent' do
      member_project.update!(status: :closed, closed_at: Time.current)

      2.times do
        post "#{base_url}/#{member_project.id}/reopen", headers: administrator.create_new_auth_token, as: :json
        expect(response).to have_http_status(:success)
      end

      expect(member_project.reload).to have_attributes(status: 'active', closed_at: nil)
    end

    it 'does not touch members or inboxes when closing' do
      create(:inbox, account: account, team: member_team)

      post "#{base_url}/#{member_project.id}/close", headers: administrator.create_new_auth_token, as: :json

      expect(member_team.reload.inboxes.count).to eq(1)
      expect(member_team.team_members.count).to eq(1)
    end
  end
end
