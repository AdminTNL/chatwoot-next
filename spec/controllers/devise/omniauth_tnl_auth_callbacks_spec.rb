require 'rails_helper'

RSpec.describe 'TnlAuth OmniAuth callback', type: :request do
  let(:issuer) { 'https://auth.test' }
  let(:token_url) { "#{issuer}/token" }
  let(:jwks_url) { "#{issuer}/.well-known/jwks.json" }
  let(:key) { OpenSSL::PKey::EC.generate('prime256v1') }
  let(:jwks) { { keys: [JWT::JWK.new(key, kid: 'k1').export] } }
  let(:token_email) { 'ana@gmail.com' }
  let(:claims) do
    {
      'iss' => issuer, 'aud' => 'chatwoot', 'sub' => 'user:abc', 'exp' => 1.hour.from_now.to_i,
      'mode' => 'access', 'type' => 'user', 'properties' => { 'userID' => 'abc', 'email' => token_email }
    }
  end
  let(:access_token) { jwt_for(claims) }
  let(:token_status) { 200 }
  let(:token_body) { { access_token: access_token, expires_in: 3600, refresh_token: 'r' }.to_json }
  let(:env_options) { { TNL_AUTH_ISSUER: issuer, TNL_AUTH_CLIENT_ID: 'chatwoot', FRONTEND_URL: 'http://www.example.com' } }
  let(:failed_url) { 'http://www.example.com/app/login?error=tnl-auth-failed' }

  def jwt_for(payload, signing_key: key)
    JWT.encode(payload, signing_key, 'ES256', { kid: 'k1' })
  end

  # Comeca pelo /tnl_auth/login (grava state e verifier na sessao) e devolve state e code_challenge do redirect.
  def start_login
    get '/tnl_auth/login'
    query = Rack::Utils.parse_query(URI.parse(response.location).query)
    [query['state'], query['code_challenge']]
  end

  # A falha e entregue na propria resposta do callback do OmniAuth (nao ha redirect intermediario).
  def request_callback
    state, = start_login
    get '/omniauth/tnl_auth/callback', params: { code: 'abc', state: state }
  end

  def run_callback
    request_callback
    follow_redirect!
  end

  around do |example|
    previous_test_mode = OmniAuth.config.test_mode
    OmniAuth.config.test_mode = false
    example.run
  ensure
    OmniAuth.config.test_mode = previous_test_mode
  end

  before do
    GlobalConfig.clear_cache
    allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
    stub_request(:get, jwks_url).to_return(status: 200, body: jwks.to_json, headers: { 'Content-Type' => 'application/json' })
    stub_request(:post, token_url).to_return(status: token_status, body: token_body, headers: { 'Content-Type' => 'application/json' })
  end

  context 'with an existing agent' do
    before { create(:user, email: 'ana@gmail.com') }

    it 'logs the agent in through the sso token' do
      with_modified_env env_options do
        request_callback
        expect(response.location).to start_with('http://www.example.com/auth/tnl_auth/callback')
        follow_redirect!

        expect(response.location).to start_with('http://www.example.com/app/login?')
        expect(CGI.unescape(CGI.unescape(response.location))).to include('email=ana@gmail.com')
        expect(response.location).to include('sso_auth_token=')
      end
    end

    it 'sends client_id, redirect_uri and a code_verifier that matches the code_challenge' do
      challenge = nil
      with_modified_env env_options do
        state, challenge = start_login
        get '/omniauth/tnl_auth/callback', params: { code: 'abc', state: state }
      end

      verifier = nil
      expect(a_request(:post, token_url).with do |req|
        verifier = Rack::Utils.parse_query(req.body)['code_verifier']
        verifier.present?
      end).to have_been_made.once
      expect(Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)).to eq(challenge)

      expect(a_request(:post, token_url).with(
               body: hash_including('grant_type' => 'authorization_code', 'code' => 'abc', 'client_id' => 'chatwoot',
                                    'redirect_uri' => 'http://www.example.com/omniauth/tnl_auth/callback')
             )).to have_been_made.once
      expect(a_request(:post, token_url).with { |req| req.headers['Authorization'].present? }).not_to have_been_made
    end

    it 'does not double the slash when FRONTEND_URL ends with slash' do
      with_modified_env env_options.merge(FRONTEND_URL: 'http://www.example.com/') do
        request_callback
      end

      expect(a_request(:post, token_url).with(
               body: hash_including('redirect_uri' => 'http://www.example.com/omniauth/tnl_auth/callback')
             )).to have_been_made.once
    end

    context 'when the token email has uppercase' do
      let(:token_email) { 'Ana@Gmail.com' }

      it 'matches the existing user' do
        with_modified_env env_options do
          run_callback
          expect(response.location).to include('sso_auth_token=')
        end
      end
    end

    context 'when the token is invalid' do
      ['a wrong signing key', 'a wrong audience', 'a wrong issuer', 'an expired token', 'no email'].each do |label|
        context "with #{label}" do
          let(:access_token) do
            case label
            when 'a wrong signing key' then jwt_for(claims, signing_key: OpenSSL::PKey::EC.generate('prime256v1'))
            when 'a wrong audience' then jwt_for(claims.merge('aud' => 'outro'))
            when 'a wrong issuer' then jwt_for(claims.merge('iss' => 'https://evil.test'))
            when 'an expired token' then jwt_for(claims.merge('exp' => 1.minute.ago.to_i))
            else jwt_for(claims.merge('properties' => {}))
            end
          end

          it 'redirects to tnl-auth-failed' do
            with_modified_env env_options do
              request_callback
              expect(response).to redirect_to(failed_url)
            end
          end
        end
      end
    end

    context 'when /token returns 400' do
      let(:token_status) { 400 }
      let(:token_body) { { error: 'invalid_grant' }.to_json }

      it 'redirects to tnl-auth-failed' do
        with_modified_env env_options do
          request_callback
          expect(response).to redirect_to(failed_url)
        end
      end
    end

    it 'redirects to tnl-auth-failed when TNL_AUTH_ISSUER is missing' do
      with_modified_env env_options do
        state, = start_login
        with_modified_env TNL_AUTH_ISSUER: nil do
          get '/omniauth/tnl_auth/callback', params: { code: 'abc', state: state }
        end
      end

      expect(response).to redirect_to(failed_url)
    end
  end

  context 'when the state or session is not valid' do
    before { create(:user, email: 'ana@gmail.com') }

    it 'fails without state and does not call /token' do
      with_modified_env env_options do
        start_login
        get '/omniauth/tnl_auth/callback', params: { code: 'abc' }
      end

      expect(response).to redirect_to(failed_url)
      expect(a_request(:post, token_url)).not_to have_been_made
    end

    it 'fails with a wrong state and does not call /token' do
      with_modified_env env_options do
        start_login
        get '/omniauth/tnl_auth/callback', params: { code: 'abc', state: 'errado' }
      end

      expect(response).to redirect_to(failed_url)
      expect(a_request(:post, token_url)).not_to have_been_made
    end

    it 'fails without passing through /tnl_auth/login and does not call /token' do
      with_modified_env env_options do
        get '/omniauth/tnl_auth/callback', params: { code: 'abc', state: 'a' * 48 }
      end

      expect(response).to redirect_to(failed_url)
      expect(a_request(:post, token_url)).not_to have_been_made
    end

    it 'fails on a replayed callback with the same state' do
      with_modified_env env_options do
        state, = start_login
        get '/omniauth/tnl_auth/callback', params: { code: 'abc', state: state }
        expect(response.location).to start_with('http://www.example.com/auth/tnl_auth/callback')

        get '/omniauth/tnl_auth/callback', params: { code: 'abc', state: state }
        expect(response).to redirect_to(failed_url)
      end

      expect(a_request(:post, token_url)).to have_been_made.once
    end
  end

  context 'when the email is not an agent' do
    it 'redirects to no-account-found without creating records' do
      with_modified_env env_options do
        expect { run_callback }.not_to(change { [User.count, Account.count] })
        expect(response).to redirect_to('http://www.example.com/app/login?error=no-account-found')
      end
    end
  end
end
