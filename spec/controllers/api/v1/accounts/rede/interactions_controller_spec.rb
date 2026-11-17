require 'rails_helper'

RSpec.describe 'Rede Interactions API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:carlos) { create(:user, account: account, role: :agent, name: 'Carlos') }
  let(:other_agent) { create(:user, account: account, role: :agent) }
  let(:outsider_agent) { create(:user, account: account, role: :agent) }
  let!(:pe_team) { create(:team, account: account, name: 'pe') }
  let!(:pa_team) { create(:team, account: account, name: 'pa') }
  let(:pe) { pe_team.rede_project }
  let(:pa) { pa_team.rede_project }
  let(:ana) { create(:contact, account: account, name: 'Ana') }
  let(:base_url) { "/api/v1/accounts/#{account.id}/rede/interactions" }
  let(:carlos_headers) { carlos.create_new_auth_token }
  let!(:pe_campo) { create(:rede_front, account: account, project: pe) }
  let(:payload) { { contact_id: ana.id, project_id: pe.id, kind: 'call', answered: true, summary: 'Combinamos a visita' } }

  before do
    create(:team_member, team: pe_team, user: carlos)
    create(:team_member, team: pe_team, user: other_agent)
    create(:team_member, team: pa_team, user: other_agent)
    create(:rede_participation, account: account, contact: ana, project: pe)
  end

  describe 'POST /rede/interactions' do
    it 'returns unauthorized when unauthenticated' do
      post base_url, params: payload, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'registers an answered call by the logged user' do
      expect { post base_url, headers: carlos_headers, params: payload, as: :json }.to change(Rede::Interaction, :count).by(1)

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include('kind' => 'call', 'answered' => true, 'summary' => 'Combinamos a visita',
                                              'project_id' => pe.id, 'contact_id' => ana.id)
      expect(response.parsed_body['author']).to eq('id' => carlos.id, 'name' => 'Carlos')
      expect(response.parsed_body['occurred_at']).to be_present
    end

    it 'ignores author_user_id sent in the params' do
      post base_url, headers: carlos_headers, params: payload.merge(author_user_id: other_agent.id), as: :json

      expect(response.parsed_body['author']['id']).to eq(carlos.id)
    end

    it 'lets the administrator register' do
      post base_url, headers: administrator.create_new_auth_token, params: payload, as: :json

      expect(response).to have_http_status(:success)
    end

    it 'accepts a front of the project and a past occurred_at' do
      past = 3.days.ago.change(usec: 0)
      post base_url, headers: carlos_headers, params: payload.merge(front_id: pe_campo.id, occurred_at: past), as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['front_id']).to eq(pe_campo.id)
      expect(Time.zone.parse(response.parsed_body['occurred_at'])).to eq(past)
    end

    it 'returns 422 for a call without answered' do
      post base_url, headers: carlos_headers, params: payload.except(:answered), as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'stores a note with answered ignored' do
      post base_url, headers: carlos_headers, params: payload.merge(kind: 'note', answered: true), as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include('kind' => 'note', 'answered' => nil)
    end

    it 'returns 422 for an unknown kind' do
      post base_url, headers: carlos_headers, params: payload.merge(kind: 'sms'), as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 422 when the person does not participate in the project' do
      create(:team_member, team: pa_team, user: carlos)

      post base_url, headers: carlos_headers, params: payload.merge(project_id: pa.id), as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 404 for a project outside the operator scope' do
      create(:rede_participation, account: account, contact: ana, project: pa)

      post base_url, headers: carlos_headers, params: payload.merge(project_id: pa.id), as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 422 for a front of another project' do
      other_front = create(:rede_front, account: account, project: pa)

      post base_url, headers: carlos_headers, params: payload.merge(front_id: other_front.id), as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 422 for occurred_at in the future' do
      post base_url, headers: carlos_headers, params: payload.merge(occurred_at: 2.hours.from_now), as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 404 for a contact of another account' do
      post base_url, headers: carlos_headers, params: payload.merge(contact_id: create(:contact).id), as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'still registers for a closed participation' do
      Rede::Participation.find_by!(contact: ana, project: pe).update!(status: :closed)

      post base_url, headers: carlos_headers, params: payload, as: :json

      expect(response).to have_http_status(:success)
    end
  end

  describe 'PATCH /rede/interactions/:id' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    let!(:interaction) { create(:rede_interaction, account: account, project: pe, contact: ana, author_user: carlos) }
    let(:url) { "#{base_url}/#{interaction.id}" }

    it 'lets the author edit summary and answered within 24 hours' do
      patch url, headers: carlos_headers, params: { summary: 'Corrigido', answered: false }, as: :json

      expect(response).to have_http_status(:success)
      expect(interaction.reload).to have_attributes(summary: 'Corrigido', answered: false)
    end

    it 'does not change other fields' do
      patch url, headers: carlos_headers, params: { summary: 'x', kind: 'note', project_id: pa.id }, as: :json

      expect(interaction.reload).to have_attributes(kind: 'call', project_id: pe.id)
    end

    it 'returns 401 for another user of the project' do
      patch url, headers: other_agent.create_new_auth_token, params: { summary: 'x' }, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(interaction.reload.summary).not_to eq('x')
    end

    it 'gives the administrator no exception' do
      patch url, headers: administrator.create_new_auth_token, params: { summary: 'x' }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 404 for an agent outside the project' do
      patch url, headers: outsider_agent.create_new_auth_token, params: { summary: 'x' }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 422 for the author after 24 hours' do
      headers = carlos_headers
      travel_to(25.hours.from_now) do
        patch url, headers: headers, params: { summary: 'tarde' }, as: :json
      end

      expect(response).to have_http_status(:unprocessable_entity)
      expect(interaction.reload.summary).not_to eq('tarde')
    end

    it 'returns 422 when removing answered from a call' do
      patch url, headers: carlos_headers, params: { answered: nil }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'GET /rede/interactions' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    let!(:old_call) { create(:rede_interaction, account: account, project: pe, contact: ana, occurred_at: 3.days.ago, summary: 'antiga') }
    let!(:new_note) { create(:rede_interaction, :note, account: account, project: pe, contact: ana, occurred_at: 1.day.ago, summary: 'recente') }
    let!(:pa_call) { create(:rede_interaction, account: account, project: pa, contact: ana, summary: 'em pa') }

    it 'returns unauthorized when unauthenticated' do
      get base_url, params: { contact_id: ana.id }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'lists in descending order only the projects in scope' do
      get base_url, headers: carlos_headers, params: { contact_id: ana.id }, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.pluck('id')).to eq([new_note.id, old_call.id])
    end

    it 'lets the administrator see all projects and filter by project' do
      headers = administrator.create_new_auth_token

      get base_url, headers: headers, params: { contact_id: ana.id }, as: :json
      expect(response.parsed_body.size).to eq(3)

      get base_url, headers: headers, params: { contact_id: ana.id, project_id: pa.id }, as: :json
      expect(response.parsed_body.pluck('id')).to eq([pa_call.id])
    end

    it 'requires contact_id (the global handler answers 422 for a missing param)' do
      get base_url, headers: carlos_headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 404 when filtering by a project outside the scope' do
      get base_url, headers: carlos_headers, params: { contact_id: ana.id, project_id: pa.id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
