require 'rails_helper'

RSpec.describe 'Rede Assignments API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:member_agent) { create(:user, account: account, role: :agent) }
  let!(:pe_team) { create(:team, account: account, name: 'pe') }
  let!(:pa_team) { create(:team, account: account, name: 'pa') }
  let(:pe) { pe_team.rede_project }
  let(:pa) { pa_team.rede_project }
  let(:admin_headers) { administrator.create_new_auth_token }
  let(:agent_headers) { member_agent.create_new_auth_token }
  let(:mobilizador) { account.rede_roles.find_by!(key: 'mobilizador') }
  let(:coordenador) { account.rede_roles.find_by!(key: 'coordenador') }
  let!(:pe_campo) { create(:rede_front, account: account, project: pe, name: 'PE Campo') }
  let!(:pe_participation) { create(:rede_participation, account: account, project: pe) }
  let!(:pa_participation) { create(:rede_participation, account: account, project: pa) }

  before { create(:team_member, team: pe_team, user: member_agent) }

  def url(participation, suffix = '')
    "/api/v1/accounts/#{account.id}/rede/participations/#{participation.id}/assignments#{suffix}"
  end

  describe 'POST /assignments' do
    it 'returns unauthorized when unauthenticated' do
      post url(pe_participation), params: {}, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'creates an assignment with front, role and superior' do
      superior = create(:contact, account: account)

      post url(pe_participation), headers: agent_headers,
                                  params: { front_id: pe_campo.id, role_id: mobilizador.id, superior_contact_id: superior.id }, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include('participation_id' => pe_participation.id, 'front_id' => pe_campo.id,
                                              'role_id' => mobilizador.id, 'superior_contact_id' => superior.id, 'status' => 'active')
    end

    it 'allows an assignment without front in a project with fronts' do
      post url(pe_participation), headers: admin_headers, params: { role_id: mobilizador.id }, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['front_id']).to be_nil
    end

    it 'returns 422 for a second active assignment without front' do
      create(:rede_assignment, account: account, participation: pe_participation)

      post url(pe_participation), headers: admin_headers, params: {}, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 422 for a front of another project' do
      post url(pe_participation), headers: admin_headers, params: { front_id: create(:rede_front, account: account, project: pa).id }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 422 for a closed front' do
      pe_campo.close!

      post url(pe_participation), headers: admin_headers, params: { front_id: pe_campo.id }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 422 when the superior is the person' do
      post url(pe_participation), headers: admin_headers, params: { superior_contact_id: pe_participation.contact_id }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 404 for an agent outside the project' do
      post url(pa_participation), headers: agent_headers, params: {}, as: :json

      expect(response).to have_http_status(:not_found)
      expect(Rede::Assignment.count).to eq(0)
    end
  end

  describe 'PATCH /assignments/:id' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    let!(:assignment) { create(:rede_assignment, account: account, participation: pe_participation, role: mobilizador) }

    it 'closes the old row and returns the new one when the role changes' do
      patch url(pe_participation, "/#{assignment.id}"), headers: agent_headers, params: { role_id: coordenador.id }, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['id']).not_to eq(assignment.id)
      expect(response.parsed_body).to include('role_id' => coordenador.id, 'status' => 'active')
      expect(assignment.reload).to have_attributes(status: 'closed')
      expect(assignment.ended_at).to be_present
    end

    it 'assigns a front to a "front to define" assignment, closing it' do
      patch url(pe_participation, "/#{assignment.id}"), headers: admin_headers, params: { front_id: pe_campo.id }, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include('front_id' => pe_campo.id, 'role_id' => mobilizador.id)
      expect(assignment.reload).to be_closed
    end

    it 'changes the superior' do
      superior = create(:contact, account: account)

      patch url(pe_participation, "/#{assignment.id}"), headers: admin_headers, params: { superior_contact_id: superior.id }, as: :json

      expect(response.parsed_body['superior_contact_id']).to eq(superior.id)
    end

    it 'returns 422 for an invalid change, keeping the assignment active' do
      patch url(pe_participation, "/#{assignment.id}"), headers: admin_headers, params: { superior_contact_id: pe_participation.contact_id },
                                                        as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(assignment.reload).to be_active
    end

    it 'returns 404 for an agent outside the project' do
      pa_assignment = create(:rede_assignment, account: account, participation: pa_participation)

      patch url(pa_participation, "/#{pa_assignment.id}"), headers: agent_headers, params: { role_id: coordenador.id }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(pa_assignment.reload).to be_active
    end

    it 'returns 404 when the assignment belongs to another participation' do
      other = create(:rede_assignment, account: account, participation: create(:rede_participation, account: account, project: pe))

      patch url(pe_participation, "/#{other.id}"), headers: admin_headers, params: { role_id: coordenador.id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /assignments/:id/close' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    let!(:assignment) { create(:rede_assignment, account: account, participation: pe_participation) }

    it 'closes the assignment' do
      post url(pe_participation, "/#{assignment.id}/close"), headers: agent_headers, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['status']).to eq('closed')
      expect(assignment.reload.ended_at).to be_present
    end

    it 'returns 404 for an agent outside the project' do
      pa_assignment = create(:rede_assignment, account: account, participation: pa_participation)

      post url(pa_participation, "/#{pa_assignment.id}/close"), headers: agent_headers, as: :json

      expect(response).to have_http_status(:not_found)
      expect(pa_assignment.reload).to be_active
    end
  end
end
