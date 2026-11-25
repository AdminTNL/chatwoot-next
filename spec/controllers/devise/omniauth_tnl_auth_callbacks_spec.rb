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

  # rubocop:disable RSpec/MultipleMemoizedHelpers
  context 'when auto provisioning is configured' do
    let(:account) { create(:account) }
    let(:allowed_url) { "#{issuer}/allowed" }
    let(:allowed_status) { 200 }
    let(:allowed_role) { 'operator' }
    let(:allowed_status_field) { 'active' }
    let(:allowed_metadata) { nil }
    let(:allowed_body) do
      { email: token_email, name: 'Ana Souza', role: allowed_role, status: allowed_status_field, metadata: allowed_metadata }.to_json
    end
    let(:provision_env) { env_options.merge(TNL_AUTH_AUTO_PROVISION_ACCOUNT_ID: account.id.to_s) }
    let(:no_account_url) { 'http://www.example.com/app/login?error=no-account-found' }

    before do
      stub_request(:get, allowed_url).to_return(status: allowed_status, body: allowed_body,
                                                headers: { 'Content-Type' => 'application/json' })
    end

    context 'when allowed as operator without teams' do
      it 'creates a confirmed agent and logs in without sending email' do
        with_modified_env provision_env do
          expect { run_callback }.not_to have_enqueued_mail(Devise::Mailer, :confirmation_instructions)
        end

        user = User.from_email('ana@gmail.com')
        expect(user).to be_confirmed
        expect(user.account_users.find_by(account_id: account.id)).to be_agent
        expect(response.location).to start_with('http://www.example.com/app/login?')
        expect(response.location).to include('sso_auth_token=')
        expect(a_request(:get, allowed_url).with(headers: { 'Authorization' => "Bearer #{access_token}" })).to have_been_made.once
      end
    end

    context 'when allowed as admin' do
      let(:allowed_role) { 'admin' }

      it 'creates an administrator' do
        with_modified_env(provision_env) { run_callback }

        expect(User.from_email('ana@gmail.com').account_users.find_by(account_id: account.id)).to be_administrator
      end
    end

    context 'when metadata has team ids' do
      let!(:team) { create(:team, account: account) }
      let(:allowed_metadata) { { chatwoot_team_ids: [team.id, 9_999_999] } }

      it 'adds the agent to the existing team only' do
        with_modified_env(provision_env) { run_callback }

        expect(User.from_email('ana@gmail.com').team_members.pluck(:team_id)).to eq([team.id])
      end
    end

    context 'when not on the allowlist (403)' do
      let(:allowed_status) { 403 }
      let(:allowed_body) { { error: 'forbidden' }.to_json }

      it 'redirects to no-account-found and creates nothing' do
        with_modified_env provision_env do
          expect { run_callback }.not_to(change { [User.count, AccountUser.count, Account.count] })
          expect(response).to redirect_to(no_account_url)
        end
      end
    end

    context 'when the status is disabled' do
      let(:allowed_status_field) { 'disabled' }

      it 'redirects to no-account-found and creates nothing' do
        with_modified_env provision_env do
          expect { run_callback }.not_to(change(User, :count))
          expect(response).to redirect_to(no_account_url)
        end
      end
    end

    context 'when /allowed is down' do
      before { stub_request(:get, allowed_url).to_timeout }

      it 'redirects to no-account-found and creates nothing' do
        with_modified_env provision_env do
          expect { run_callback }.not_to(change(User, :count))
          expect(response).to redirect_to(no_account_url)
        end
      end
    end

    context 'when the target account does not exist' do
      it 'redirects to no-account-found and creates nothing' do
        with_modified_env provision_env.merge(TNL_AUTH_AUTO_PROVISION_ACCOUNT_ID: '99999999') do
          expect { run_callback }.not_to(change(User, :count))
          expect(response).to redirect_to(no_account_url)
        end
      end
    end

    context 'when the variable is not set' do
      it 'behaves like before and does not call /allowed' do
        with_modified_env env_options do
          expect { run_callback }.not_to(change(User, :count))
          expect(response).to redirect_to(no_account_url)
        end
        expect(a_request(:get, allowed_url)).not_to have_been_made
      end
    end

    context 'when the user already exists' do
      before { create(:user, email: 'ana@gmail.com') }

      it 'logs in without calling /allowed' do
        with_modified_env(provision_env) { run_callback }

        expect(response.location).to include('sso_auth_token=')
        expect(a_request(:get, allowed_url)).not_to have_been_made
      end
    end

    context 'with a second login' do
      it 'creates once and does not call /allowed again' do
        with_modified_env provision_env do
          run_callback
          run_callback
        end

        expect(User.where(email: 'ana@gmail.com').count).to eq(1)
        expect(a_request(:get, allowed_url)).to have_been_made.once
      end
    end

    context 'with the google_oauth2 provider' do
      it 'does not provision' do
        OmniAuth.config.test_mode = true
        OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
          provider: 'google', uid: '1', credentials: { token: 'g-token' },
          info: { name: 'Ana', email: 'ana@gmail.com' }
        )

        with_modified_env provision_env.merge(ENABLE_ACCOUNT_SIGNUP: 'false') do
          expect do
            get '/omniauth/google_oauth2/callback'
            follow_redirect!
          end.not_to(change(User, :count))
        end

        expect(a_request(:get, allowed_url)).not_to have_been_made
      end
    end
  end
  # rubocop:enable RSpec/MultipleMemoizedHelpers
end
