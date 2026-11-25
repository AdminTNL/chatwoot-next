require 'rails_helper'

RSpec.describe 'TnlAuth login start', type: :request do
  let(:env_options) do
    { TNL_AUTH_ISSUER: 'https://auth.test', TNL_AUTH_CLIENT_ID: 'chatwoot', TNL_AUTH_PROVIDER: 'google',
      FRONTEND_URL: 'http://www.example.com' }
  end
  let(:location) { URI.parse(response.location) }
  let(:query) { Rack::Utils.parse_query(location.query) }

  describe 'GET /tnl_auth/login' do
    it 'redirects to the tnl-auth authorize endpoint with state and PKCE' do
      with_modified_env env_options do
        get '/tnl_auth/login'
      end

      expect(response).to have_http_status(:found)
      expect(location.host).to eq('auth.test')
      expect(location.path).to eq('/authorize')
      expect(query).to include(
        'client_id' => 'chatwoot',
        'redirect_uri' => 'http://www.example.com/omniauth/tnl_auth/callback',
        'response_type' => 'code',
        'provider' => 'google',
        'code_challenge_method' => 'S256'
      )
      expect(query['state']).to match(/\A\h{48}\z/)
      expect(query['code_challenge']).to match(/\A[A-Za-z0-9_-]{43}\z/)
      expect(response.headers['Cache-Control']).to include('no-store')
    end

    it 'generates different state and code_challenge on each request' do
      with_modified_env env_options do
        get '/tnl_auth/login'
        first = Rack::Utils.parse_query(URI.parse(response.location).query)
        get '/tnl_auth/login'
        second = Rack::Utils.parse_query(URI.parse(response.location).query)

        expect(first['state']).not_to eq(second['state'])
        expect(first['code_challenge']).not_to eq(second['code_challenge'])
      end
    end

    it 'omits provider when it is empty' do
      with_modified_env env_options.merge(TNL_AUTH_PROVIDER: '') do
        get '/tnl_auth/login'
      end

      expect(query).not_to have_key('provider')
    end

    it 'does not produce a double slash when the issuer ends with slash' do
      with_modified_env env_options.merge(TNL_AUTH_ISSUER: 'https://auth.test/') do
        get '/tnl_auth/login'
      end

      expect(location.path).to eq('/authorize')
      expect(response.location).to start_with('https://auth.test/authorize?')
    end

    it 'returns 404 and does not touch the session without TNL_AUTH_ISSUER' do
      with_modified_env env_options.merge(TNL_AUTH_ISSUER: nil) do
        get '/tnl_auth/login'
      end

      expect(response).to have_http_status(:not_found)
      expect(response.headers['Set-Cookie'].to_s).not_to include('_chatwoot_session')
    end
  end
end
