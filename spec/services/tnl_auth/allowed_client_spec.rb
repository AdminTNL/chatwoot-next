require 'rails_helper'

RSpec.describe TnlAuth::AllowedClient do
  let(:issuer) { 'https://auth.test' }
  let(:url) { "#{issuer}/allowed" }
  let(:payload) { { email: 'ana@gmail.com', name: 'Ana', role: 'operator', status: 'active', metadata: nil } }

  def perform(&)
    with_modified_env(TNL_AUTH_ISSUER: issuer, &)
  end

  it 'returns the parsed hash on 200 and sends the bearer token' do
    stub_request(:get, url).with(headers: { 'Authorization' => 'Bearer tok123' })
                           .to_return(status: 200, body: payload.to_json, headers: { 'Content-Type' => 'application/json' })

    result = perform { described_class.new('tok123').perform }

    expect(result).to include('email' => 'ana@gmail.com', 'role' => 'operator', 'status' => 'active')
  end

  it 'returns nil on 403' do
    stub_request(:get, url).to_return(status: 403, body: { error: 'forbidden' }.to_json)

    expect(perform { described_class.new('t').perform }).to be_nil
  end

  it 'returns nil on 500' do
    stub_request(:get, url).to_return(status: 500, body: 'oops')

    expect(perform { described_class.new('t').perform }).to be_nil
  end

  it 'returns nil on timeout' do
    stub_request(:get, url).to_timeout

    expect(perform { described_class.new('t').perform }).to be_nil
  end

  it 'returns nil on a network error' do
    stub_request(:get, url).to_raise(SocketError)

    expect(perform { described_class.new('t').perform }).to be_nil
  end

  it 'returns nil on invalid JSON' do
    stub_request(:get, url).to_return(status: 200, body: 'not json')

    expect(perform { described_class.new('t').perform }).to be_nil
  end

  it 'returns nil when the JSON is not an object' do
    stub_request(:get, url).to_return(status: 200, body: '[1]')

    expect(perform { described_class.new('t').perform }).to be_nil
  end

  it 'returns nil without calling the network when the issuer is missing' do
    result = with_modified_env(TNL_AUTH_ISSUER: nil) { described_class.new('t').perform }

    expect(result).to be_nil
    expect(a_request(:get, url)).not_to have_been_made
  end

  it 'returns nil without calling the network when the token is blank' do
    expect(perform { described_class.new('').perform }).to be_nil
    expect(a_request(:get, url)).not_to have_been_made
  end
end
