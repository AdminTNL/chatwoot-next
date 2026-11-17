require 'rails_helper'

RSpec.describe 'Rede Roles API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:url) { "/api/v1/accounts/#{account.id}/rede/roles" }

  before { Rede::Roles::EnsureDefaults.new(account).perform }

  it 'returns unauthorized when unauthenticated' do
    get url

    expect(response).to have_http_status(:unauthorized)
  end

  it 'lists the roles of the account for any user, without needing a team' do
    get url, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body.pluck('key')).to contain_exactly('coordenador', 'ponto_focal', 'mobilizador', 'entrevistador')
    expect(response.parsed_body.first.keys).to include('id', 'key', 'name')
  end

  it 'does not list roles of another account' do
    create(:rede_role, account: create(:account), key: 'alheio')

    get url, headers: agent.create_new_auth_token, as: :json

    expect(response.parsed_body.pluck('key')).not_to include('alheio')
  end
end
