require 'rails_helper'

RSpec.describe TnlAuth::AccessTokenVerifier do
  let(:issuer) { 'https://auth.test' }
  let(:client_id) { 'chatwoot' }
  let(:jwks_url) { "#{issuer}/.well-known/jwks.json" }
  let(:key) { OpenSSL::PKey::EC.generate('prime256v1') }
  let(:jwks) { { keys: [JWT::JWK.new(key, kid: 'k1').export] } }
  let(:memory_cache) { ActiveSupport::Cache::MemoryStore.new }
  let(:claims) do
    {
      'iss' => issuer, 'aud' => client_id, 'sub' => 'user:abc', 'exp' => 1.hour.from_now.to_i,
      'mode' => 'access', 'type' => 'user', 'properties' => { 'userID' => 'abc', 'email' => 'Ana@Gmail.com' }
    }
  end

  def build_token(payload = claims, signing_key: key, kid: 'k1')
    JWT.encode(payload, signing_key, 'ES256', { kid: kid })
  end

  def stub_jwks(body: jwks.to_json, status: 200)
    stub_request(:get, jwks_url).to_return(status: status, body: body, headers: { 'Content-Type' => 'application/json' })
  end

  around do |example|
    with_modified_env(TNL_AUTH_ISSUER: issuer, TNL_AUTH_CLIENT_ID: client_id) { example.run }
  end

  before do
    allow(Rails).to receive(:cache).and_return(memory_cache)
    stub_jwks
  end

  describe '#perform' do
    it 'returns the claims for a valid token' do
      result = described_class.new(build_token).perform

      expect(result['sub']).to eq('user:abc')
      expect(result.dig('properties', 'email')).to eq('Ana@Gmail.com')
    end

    it 'rejects a token signed by another key' do
      token = build_token(signing_key: OpenSSL::PKey::EC.generate('prime256v1'))

      expect { described_class.new(token).perform }.to raise_error(described_class::InvalidToken)
    end

    it 'rejects a wrong audience' do
      token = build_token(claims.merge('aud' => 'outro'))

      expect { described_class.new(token).perform }.to raise_error(described_class::InvalidToken)
    end

    it 'rejects a wrong issuer' do
      token = build_token(claims.merge('iss' => 'https://evil.test'))

      expect { described_class.new(token).perform }.to raise_error(described_class::InvalidToken)
    end

    it 'rejects an expired token' do
      token = build_token(claims.merge('exp' => 1.minute.ago.to_i))

      expect { described_class.new(token).perform }.to raise_error(described_class::InvalidToken)
    end

    it 'rejects a token without email' do
      token = build_token(claims.merge('properties' => { 'userID' => 'abc' }))

      expect { described_class.new(token).perform }.to raise_error(described_class::InvalidToken)
    end

    it 'rejects a token with mode other than access' do
      token = build_token(claims.merge('mode' => 'refresh'))

      expect { described_class.new(token).perform }.to raise_error(described_class::InvalidToken)
    end

    it 'rejects a token with type other than user' do
      token = build_token(claims.merge('type' => 'client'))

      expect { described_class.new(token).perform }.to raise_error(described_class::InvalidToken)
    end

    it 'rejects garbage' do
      expect { described_class.new('nao-e-jwt').perform }.to raise_error(described_class::InvalidToken)
    end

    it 'rejects an unsigned token (alg none)' do
      token = JWT.encode(claims, nil, 'none', { kid: 'k1' })

      expect { described_class.new(token).perform }.to raise_error(described_class::InvalidToken)
    end

    it 'rejects when the issuer is not configured' do
      with_modified_env(TNL_AUTH_ISSUER: nil) do
        expect { described_class.new(build_token).perform }.to raise_error(described_class::InvalidToken)
      end
    end

    it 'fetches the JWKS once for two validations (cache)' do
      2.times { described_class.new(build_token).perform }

      expect(a_request(:get, jwks_url)).to have_been_made.once
    end

    it 'fetches the JWKS again once when the kid is unknown' do
      described_class.new(build_token).perform
      new_key = OpenSSL::PKey::EC.generate('prime256v1')
      rotated = { keys: [JWT::JWK.new(key, kid: 'k1').export, JWT::JWK.new(new_key, kid: 'k2').export] }
      stub_jwks(body: rotated.to_json)

      result = described_class.new(build_token(signing_key: new_key, kid: 'k2')).perform

      expect(result['sub']).to eq('user:abc')
      expect(a_request(:get, jwks_url)).to have_been_made.twice
    end

    it 'raises InvalidToken when the JWKS endpoint returns 500' do
      stub_jwks(status: 500, body: 'erro')

      expect { described_class.new(build_token).perform }.to raise_error(described_class::InvalidToken)
    end

    it 'raises InvalidToken when the JWKS endpoint times out' do
      stub_request(:get, jwks_url).to_timeout

      expect { described_class.new(build_token).perform }.to raise_error(described_class::InvalidToken)
    end
  end
end
