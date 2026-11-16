require 'rails_helper'

RSpec.describe 'Rede Evaluations API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:member_agent) { create(:user, account: account, role: :agent) }
  let(:outsider_agent) { create(:user, account: account, role: :agent) }
  let!(:pe_team) { create(:team, account: account, name: 'pe') }
  let!(:pa_team) { create(:team, account: account, name: 'pa') }
  let(:pe) { pe_team.rede_project }
  let(:pa) { pa_team.rede_project }
  let(:ana) { create(:contact, account: account) }
  let!(:pe_campo) { create(:rede_front, account: account, project: pe, name: 'PE Campo') }
  let!(:pe_digital) { create(:rede_front, account: account, project: pe, name: 'PE Digital') }
  let!(:pe_participation) { create(:rede_participation, account: account, project: pe, contact: ana) }

  before do
    create(:rede_participation, account: account, project: pa, contact: ana)
    create(:team_member, team: pe_team, user: member_agent)
    create(:team_member, team: pa_team, user: member_agent)
    create(:rede_assignment, account: account, participation: pe_participation, front: pe_campo)
  end

  def admin_headers = administrator.create_new_auth_token
  def agent_headers = member_agent.create_new_auth_token
  def outsider_headers = outsider_agent.create_new_auth_token
  def url = "/api/v1/accounts/#{account.id}/rede/evaluations"

  def current_level(project, front)
    Rede::Evaluations::Current.new(Rede::Participation.where(contact_id: ana.id)).perform[[ana.id, project.id, front&.id]]
  end

  describe 'POST /evaluations' do
    it 'returns unauthorized when unauthenticated' do
      post url, params: {}, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'registers the temperature of a person in a front, authored by the member' do
      post url, headers: agent_headers, params: { contact_id: ana.id, project_id: pe.id, front_id: pe_campo.id, level: 'quente', note: 'animada' },
                as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include('contact_id' => ana.id, 'project_id' => pe.id, 'front_id' => pe_campo.id,
                                              'level' => 'quente', 'note' => 'animada', 'dimension' => 'temperatura',
                                              'author' => { 'id' => member_agent.id, 'name' => member_agent.name })
      expect(current_level(pe, pe_campo)).to eq('quente')
    end

    it 'lets an administrator register in any project' do
      post url, headers: admin_headers, params: { contact_id: ana.id, project_id: pe.id, front_id: pe_campo.id, level: 'frio' }, as: :json

      expect(response).to have_http_status(:success)
    end

    it 'keeps both rows when the level changes' do
      post url, headers: agent_headers, params: { contact_id: ana.id, project_id: pe.id, front_id: pe_campo.id, level: 'quente' }, as: :json
      post url, headers: agent_headers, params: { contact_id: ana.id, project_id: pe.id, front_id: pe_campo.id, level: 'morno' }, as: :json

      expect(current_level(pe, pe_campo)).to eq('morno')
      expect(Rede::Evaluation.where(contact_id: ana.id, front_id: pe_campo.id).count).to eq(2)
    end

    it 'removes the temperature with a nil level' do
      post url, headers: agent_headers, params: { contact_id: ana.id, project_id: pe.id, front_id: pe_campo.id, level: 'quente' }, as: :json
      post url, headers: agent_headers, params: { contact_id: ana.id, project_id: pe.id, front_id: pe_campo.id, level: nil }, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['level']).to be_nil
      expect(current_level(pe, pe_campo)).to be_nil
    end

    it 'returns 422 without front in a project with fronts' do
      post url, headers: agent_headers, params: { contact_id: ana.id, project_id: pe.id, level: 'quente' }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 422 for a front where the person has no active assignment' do
      post url, headers: agent_headers, params: { contact_id: ana.id, project_id: pe.id, front_id: pe_digital.id, level: 'quente' }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 422 for a front without temperature' do
      pe_campo.update!(has_temperature: false)

      post url, headers: agent_headers, params: { contact_id: ana.id, project_id: pe.id, front_id: pe_campo.id, level: 'quente' }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 422 for a closed front' do
      pe_campo.close!

      post url, headers: agent_headers, params: { contact_id: ana.id, project_id: pe.id, front_id: pe_campo.id, level: 'quente' }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 422 for an invalid level' do
      post url, headers: agent_headers, params: { contact_id: ana.id, project_id: pe.id, front_id: pe_campo.id, level: 'fervendo' }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 422 for a person without participation in the project' do
      stranger = create(:contact, account: account)

      post url, headers: agent_headers, params: { contact_id: stranger.id, project_id: pe.id, front_id: pe_campo.id, level: 'quente' }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'registers a project temperature with a nil front in a project without fronts' do
      post url, headers: agent_headers, params: { contact_id: ana.id, project_id: pa.id, front_id: nil, level: 'frio' }, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['front_id']).to be_nil
      expect(current_level(pa, nil)).to eq('frio')
    end

    it 'returns 422 for any front in a project without fronts' do
      other_front = create(:rede_front, account: account, project: pe, name: 'Outra')

      post url, headers: agent_headers, params: { contact_id: ana.id, project_id: pa.id, front_id: other_front.id, level: 'frio' }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 404 for an agent who is not a member of the project' do
      post url, headers: outsider_headers, params: { contact_id: ana.id, project_id: pe.id, front_id: pe_campo.id, level: 'quente' }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(Rede::Evaluation.count).to eq(0)
    end
  end

  describe 'GET /evaluations' do
    before do
      create(:rede_evaluation, account: account, contact: ana, project: pe, front: pe_campo, level: 'quente', evaluated_at: 2.days.ago,
                               author_user: member_agent)
      create(:rede_evaluation, account: account, contact: ana, project: pe, front: pe_campo, level: 'morno', evaluated_at: 1.day.ago)
      create(:rede_evaluation, account: account, contact: ana, project: pa, front: nil, level: 'frio')
    end

    it 'returns unauthorized when unauthenticated' do
      get url, params: { contact_id: ana.id, project_id: pe.id }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns the history of the project, newest first, with the author' do
      get url, headers: agent_headers, params: { contact_id: ana.id, project_id: pe.id }, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.pluck('level')).to eq(%w[morno quente])
      expect(response.parsed_body.last['author']).to eq('id' => member_agent.id, 'name' => member_agent.name)
    end

    it 'lets an administrator read any project' do
      get url, headers: admin_headers, params: { contact_id: ana.id, project_id: pa.id }, as: :json

      expect(response.parsed_body.pluck('level')).to eq(['frio'])
    end

    it 'returns 422 without contact_id (ParameterMissing handled by the app)' do
      get url, headers: agent_headers, params: { project_id: pe.id }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 404 for an agent who is not a member of the project' do
      get url, headers: outsider_headers, params: { contact_id: ana.id, project_id: pe.id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
