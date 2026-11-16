require 'rails_helper'

RSpec.describe 'Rede Participations API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:member_agent) { create(:user, account: account, role: :agent) }
  let(:outsider_agent) { create(:user, account: account, role: :agent) }
  let!(:pe_team) { create(:team, account: account, name: 'pe') }
  let!(:pa_team) { create(:team, account: account, name: 'pa') }
  let(:pe) { pe_team.rede_project }
  let(:pa) { pa_team.rede_project }
  let(:base_url) { "/api/v1/accounts/#{account.id}/rede/participations" }
  let(:admin_headers) { administrator.create_new_auth_token }
  let(:agent_headers) { member_agent.create_new_auth_token }
  let(:mobilizador) { account.rede_roles.find_by!(key: 'mobilizador') }
  let!(:pe_campo) { create(:rede_front, account: account, project: pe, name: 'PE Campo') }

  before { create(:team_member, team: pe_team, user: member_agent) }

  describe 'POST /rede/participations' do
    let(:new_person) { { project_id: pe.id, contact: { name: 'Ana', phone_number: '(81) 9 8888-7777' } } }

    it 'returns unauthorized when unauthenticated' do
      post base_url, params: new_person, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'lets the administrator add a new person with the first assignment' do
      params = new_person.merge(assignment: { front_id: pe_campo.id, role_id: mobilizador.id })

      expect { post base_url, headers: admin_headers, params: params, as: :json }
        .to change(Contact, :count).by(1).and change(Rede::Participation, :count).by(1).and change(Rede::Assignment, :count).by(1)

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body).to include('project_id' => pe.id, 'origin' => 'manual', 'status' => 'active')
      expect(body['contact']).to include('name' => 'Ana', 'phone_number' => '+5581988887777')
      expect(body['assignments'].size).to eq(1)
      expect(body['assignments'].first).to include('front_id' => pe_campo.id, 'role_id' => mobilizador.id, 'status' => 'active')
    end

    it 'lets a project member add people' do
      post base_url, headers: agent_headers, params: new_person, as: :json

      expect(response).to have_http_status(:success)
    end

    it 'returns 404 for an agent outside the project, creating nothing' do
      expect do
        post base_url, headers: outsider_agent.create_new_auth_token, params: new_person, as: :json
      end.not_to change(Contact, :count)

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 for a member of another project' do
      post base_url, headers: agent_headers, params: new_person.merge(project_id: pa.id), as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'reuses the contact with the same phone without the ninth digit' do
      existing = create(:contact, account: account, phone_number: '+558188887777')

      expect { post base_url, headers: admin_headers, params: new_person, as: :json }.not_to change(Contact, :count)

      expect(response.parsed_body['contact']['id']).to eq(existing.id)
    end

    it 'adds an existing contact by contact_id' do
      contact = create(:contact, account: account)

      post base_url, headers: admin_headers, params: { project_id: pe.id, contact_id: contact.id }, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['contact']['id']).to eq(contact.id)
    end

    it 'returns 422 with the existing participation when the person is already in the project' do
      contact = create(:contact, account: account)
      existing = create(:rede_participation, account: account, project: pe, contact: contact)

      post base_url, headers: admin_headers, params: { project_id: pe.id, contact_id: contact.id }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['id']).to eq(existing.id)
      expect(response.parsed_body['error']).to be_present
    end

    it 'returns 404 for a contact of another account' do
      foreign = create(:contact, account: create(:account))

      post base_url, headers: admin_headers, params: { project_id: pe.id, contact_id: foreign.id }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 422 for an invalid phone without creating a contact' do
      expect do
        post base_url, headers: admin_headers, params: { project_id: pe.id, contact: { name: 'Ana', phone_number: 'abc' } }, as: :json
      end.not_to change(Contact, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 422 and rolls back when the front belongs to another project' do
      pa_front = create(:rede_front, account: account, project: pa)

      expect do
        post base_url, headers: admin_headers, params: new_person.merge(assignment: { front_id: pa_front.id }), as: :json
      end.not_to change(Contact, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 422 for a closed front' do
      pe_campo.close!

      post base_url, headers: admin_headers, params: new_person.merge(assignment: { front_id: pe_campo.id }), as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'allows an assignment without front in a project with fronts' do
      post base_url, headers: admin_headers, params: new_person.merge(assignment: { role_id: mobilizador.id }), as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['assignments'].first['front_id']).to be_nil
    end

    it 'returns 422 for a new participation in a closed project' do
      pe.close!

      post base_url, headers: admin_headers, params: new_person, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'PATCH /rede/participations/:id' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    let!(:pe_participation) { create(:rede_participation, account: account, project: pe) }
    let!(:pa_participation) { create(:rede_participation, account: account, project: pa) }

    it 'updates the allowed fields as a project member' do
      referrer = create(:contact, account: account)

      params = { responsible_user_id: member_agent.id, next_step: 'Ligar sexta', referred_by_contact_id: referrer.id }
      patch "#{base_url}/#{pe_participation.id}", headers: agent_headers, params: params, as: :json

      expect(response).to have_http_status(:success)
      expect(pe_participation.reload).to have_attributes(responsible_user_id: member_agent.id, next_step: 'Ligar sexta',
                                                         referred_by_contact_id: referrer.id)
    end

    it 'updates referred_by_text and status' do
      patch "#{base_url}/#{pe_participation.id}", headers: admin_headers, params: { referred_by_text: 'Fulano', status: 'closed' }, as: :json

      expect(response).to have_http_status(:success)
      expect(pe_participation.reload).to have_attributes(referred_by_text: 'Fulano', status: 'closed')
    end

    it 'ignores fields outside the allowed list' do
      other = create(:contact, account: account)

      patch "#{base_url}/#{pe_participation.id}", headers: admin_headers, params: { contact_id: other.id, project_id: pa.id, origin: 'form' },
                                                  as: :json

      expect(pe_participation.reload).to have_attributes(project_id: pe.id, origin: 'manual')
      expect(pe_participation.contact_id).not_to eq(other.id)
    end

    it 'returns 422 for a responsible who is neither member nor administrator' do
      patch "#{base_url}/#{pe_participation.id}", headers: admin_headers, params: { responsible_user_id: outsider_agent.id }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 404 for a participation of a project the agent does not belong to' do
      patch "#{base_url}/#{pa_participation.id}", headers: agent_headers, params: { next_step: 'x' }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(pa_participation.reload.next_step).to be_nil
    end

    it 'lets the administrator update any project' do
      patch "#{base_url}/#{pa_participation.id}", headers: admin_headers, params: { next_step: 'x' }, as: :json

      expect(response).to have_http_status(:success)
    end

    it 'accepts updates on a closed project' do
      pe.close!

      patch "#{base_url}/#{pe_participation.id}", headers: admin_headers, params: { next_step: 'Acompanhar' }, as: :json

      expect(response).to have_http_status(:success)
    end

    it 'returns 404 for a participation of another account' do
      foreign = create(:rede_participation, account: create(:account))

      patch "#{base_url}/#{foreign.id}", headers: admin_headers, params: { next_step: 'x' }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
