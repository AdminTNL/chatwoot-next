require 'rails_helper'

RSpec.describe 'Rede Quality API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let!(:pe_team) { create(:team, account: account, name: 'pe') }
  let!(:pa_team) { create(:team, account: account, name: 'pa') }
  let(:pe) { pe_team.rede_project }
  let(:pa) { pa_team.rede_project }
  let(:admin_headers) { administrator.create_new_auth_token }
  let(:agent_headers) { agent.create_new_auth_token }
  let(:base_url) { "/api/v1/accounts/#{account.id}/rede/quality" }
  let!(:ana) { create(:contact, account: account, name: 'Ana', phone_number: '+5581988887777', additional_attributes: { 'city' => 'Recife' }) }
  let!(:ana_dup) { create(:contact, account: account, name: 'Ana S.', phone_number: '+558188887777', additional_attributes: { 'city' => 'Recife' }) }

  before do
    create(:team_member, team: pe_team, user: agent)
    [ana, ana_dup].each { |contact| create(:rede_participation, account: account, contact: contact, project: pe) }
  end

  describe 'GET /rede/quality' do
    it 'returns unauthorized when unauthenticated' do
      get base_url, params: { project_id: pe.id }

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns unauthorized for an agent, even a member of the project' do
      get base_url, headers: agent_headers, params: { project_id: pe.id }

      expect(response).to have_http_status(:unauthorized)
    end

    it 'lists the duplicate pair once with the counts' do
      get base_url, headers: admin_headers, params: { project_id: pe.id }

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body['duplicates'].size).to eq(1)
      pair = body['duplicates'].first
      expect([pair['contact_a']['id'], pair['contact_b']['id']]).to eq([ana.id, ana_dup.id].sort)
      expect(pair['contact_a']).to include('name', 'phone_number')
      expect(body['counts']).to eq('duplicates' => 1, 'incompletes' => 0, 'resolved_this_month' => 0)
    end

    it 'does not list the pair in another project' do
      get base_url, headers: admin_headers, params: { project_id: pa.id }

      expect(response.parsed_body['duplicates']).to eq([])
    end

    it 'lists incomplete people with their kind' do
      diego = create(:contact, account: account, name: 'Diego', phone_number: '+5581977770000')
      create(:rede_participation, account: account, contact: diego, project: pe)
      front = create(:rede_front, account: account, project: pe)
      create(:rede_assignment, account: account, participation: Rede::Participation.find_by(contact_id: ana.id), front: front)

      get base_url, headers: admin_headers, params: { project_id: pe.id }

      incompletes = response.parsed_body['incompletes'].map { |item| [item['contact']['id'], item['kind']] }
      expect(incompletes).to include([diego.id, 'missing_city'], [diego.id, 'pending_front'], [ana_dup.id, 'pending_front'])
      expect(incompletes).not_to include([ana.id, 'pending_front'])
      expect(response.parsed_body['counts']['incompletes']).to eq(incompletes.size)
    end

    it 'requires a project of the account' do
      get base_url, headers: admin_headers, params: { project_id: 0 }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /rede/quality/dismissals' do
    let(:payload) { { project_id: pe.id, contact_a_id: ana_dup.id, contact_b_id: ana.id } }

    it 'returns unauthorized for an agent and records nothing' do
      post "#{base_url}/dismissals", headers: agent_headers, params: payload, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(Rede::QualityResolution.count).to eq(0)
    end

    it 'dismisses the pair, which disappears and counts as resolved' do
      post "#{base_url}/dismissals", headers: admin_headers, params: payload, as: :json

      expect(response).to have_http_status(:success)
      expect(Rede::QualityResolution.dismissed.last).to have_attributes(
        project_id: pe.id, contact_a_id: [ana.id, ana_dup.id].min, contact_b_id: [ana.id, ana_dup.id].max,
        resolved_by_user_id: administrator.id, account_id: account.id
      )

      get base_url, headers: admin_headers, params: { project_id: pe.id }
      expect(response.parsed_body['duplicates']).to eq([])
      expect(response.parsed_body['counts']['resolved_this_month']).to eq(1)
    end

    it 'is idempotent' do
      2.times { post "#{base_url}/dismissals", headers: admin_headers, params: payload, as: :json }

      expect(response).to have_http_status(:success)
      expect(Rede::QualityResolution.dismissed.count).to eq(1)
    end

    it 'rejects a pair of the same contact' do
      post "#{base_url}/dismissals", headers: admin_headers, params: payload.merge(contact_b_id: ana_dup.id), as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'does not accept contacts of another account' do
      foreign = create(:contact, account: create(:account))

      post "#{base_url}/dismissals", headers: admin_headers, params: payload.merge(contact_b_id: foreign.id), as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /rede/quality/merges' do
    let(:payload) { { project_id: pe.id, base_contact_id: ana.id, mergee_contact_id: ana_dup.id } }

    it 'returns unauthorized for an agent and merges nothing' do
      post "#{base_url}/merges", headers: agent_headers, params: payload, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(Contact.exists?(ana_dup.id)).to be(true)
    end

    it 'merges into the chosen base, moves rede data and records the resolution' do
      create(:rede_interaction, account: account, contact: ana_dup, project: pe)
      create(:rede_participation, account: account, contact: ana_dup, project: pa)

      post "#{base_url}/merges", headers: admin_headers, params: payload, as: :json

      expect(response).to have_http_status(:success)
      expect(Contact.exists?(ana_dup.id)).to be(false)
      expect(Rede::Participation.where(project_id: pe.id).pluck(:contact_id)).to eq([ana.id])
      expect(Rede::Participation.find_by(project_id: pa.id).contact_id).to eq(ana.id)
      expect(Rede::Interaction.where(contact_id: ana.id).count).to eq(1)
      expect(Rede::QualityResolution.merged.last).to have_attributes(
        project_id: pe.id, contact_a_id: [ana.id, ana_dup.id].min, contact_b_id: [ana.id, ana_dup.id].max,
        resolved_by_user_id: administrator.id
      )

      get base_url, headers: admin_headers, params: { project_id: pe.id }
      expect(response.parsed_body['counts']).to include('duplicates' => 0, 'resolved_this_month' => 1)
    end

    it 'rolls back everything when the merge fails midway' do
      create(:rede_interaction, account: account, contact: ana_dup, project: pe)
      allow(Rede::LastContact::Recompute).to receive(:new).and_raise(StandardError, 'boom')

      post "#{base_url}/merges", headers: admin_headers, params: payload, as: :json

      expect(response).to have_http_status(:internal_server_error)

      expect(Rede::QualityResolution.count).to eq(0)

      expect(Contact.exists?(ana_dup.id)).to be(true)
      expect(Rede::Interaction.where(contact_id: ana_dup.id).count).to eq(1)
    end

    it 'rejects merging a contact into itself' do
      post "#{base_url}/merges", headers: admin_headers, params: payload.merge(mergee_contact_id: ana.id), as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'rejects contacts that do not participate in the project' do
      outsider = create(:contact, account: account)

      post "#{base_url}/merges", headers: admin_headers, params: payload.merge(mergee_contact_id: outsider.id), as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(Contact.exists?(outsider.id)).to be(true)
    end

    it 'counts the resolved of the current month in the account time zone' do
      account.update!(reporting_timezone: 'Pacific/Kiritimati') # UTC+14
      zone = ActiveSupport::TimeZone['Pacific/Kiritimati']
      in_month = zone.now.beginning_of_month + 1.hour
      before_month = zone.now.beginning_of_month - 1.hour
      [in_month, before_month].each_with_index do |time, index|
        Rede::QualityResolution.create!(account: account, project: pe, kind: :dismissed, contact_a_id: 1000 + index, contact_b_id: 2000 + index,
                                        created_at: time)
      end

      get base_url, headers: admin_headers, params: { project_id: pe.id }

      expect(response.parsed_body['counts']['resolved_this_month']).to eq(1)
    end
  end
end
