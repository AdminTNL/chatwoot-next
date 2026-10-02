require 'rails_helper'

RSpec.describe '/api/v1/accounts/{account.id}/contacts/:id/teams', type: :request do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }

  # A conversation's team_id is always derived from its inbox's team_id (spec 008),
  # so each team used in these examples needs its own inbox pointed at that team.
  def conversation_for(team, last_activity_at: Time.current)
    inbox = create(:inbox, account: account, team: team)
    contact_inbox = create(:contact_inbox, contact: contact, inbox: inbox)
    create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox,
                          last_activity_at: last_activity_at)
  end

  describe 'GET /api/v1/accounts/{account.id}/contacts/:id/teams' do
    context 'when unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/contacts/#{contact.id}/teams"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when user is logged in' do
      it 'returns the distinct teams from the contact conversations, ordered by name' do
        team_b = create(:team, account: account, name: 'B time')
        team_a = create(:team, account: account, name: 'A time')
        conversation_for(team_b)
        conversation_for(team_b)
        conversation_for(team_a)

        get "/api/v1/accounts/#{account.id}/contacts/#{contact.id}/teams", headers: admin.create_new_auth_token

        expect(response).to have_http_status(:success)
        json_response = response.parsed_body
        expect(json_response.pluck('id')).to eq([team_a.id, team_b.id])
      end

      it 'includes teams that only appear outside the 20 most recent conversations' do
        old_team = create(:team, account: account, name: 'Time antigo')
        conversation_for(old_team, last_activity_at: 30.days.ago)
        20.times { conversation_for(nil, last_activity_at: Time.current) }

        get "/api/v1/accounts/#{account.id}/contacts/#{contact.id}/teams", headers: admin.create_new_auth_token

        expect(response).to have_http_status(:success)
        json_response = response.parsed_body
        expect(json_response.pluck('id')).to eq([old_team.id])
      end

      it 'excludes conversations with no team' do
        conversation_for(nil)

        get "/api/v1/accounts/#{account.id}/contacts/#{contact.id}/teams", headers: admin.create_new_auth_token

        expect(response).to have_http_status(:success)
        expect(response.parsed_body).to eq([])
      end

      it 'returns an empty array when the contact has no conversations' do
        get "/api/v1/accounts/#{account.id}/contacts/#{contact.id}/teams", headers: admin.create_new_auth_token

        expect(response).to have_http_status(:success)
        expect(response.parsed_body).to eq([])
      end

      it 'returns the same result regardless of the requesting agent role' do
        team = create(:team, account: account, name: 'Time único')
        conversation_for(team)

        get "/api/v1/accounts/#{account.id}/contacts/#{contact.id}/teams", headers: agent.create_new_auth_token

        expect(response).to have_http_status(:success)
        expect(response.parsed_body.pluck('id')).to eq([team.id])
      end
    end
  end
end
