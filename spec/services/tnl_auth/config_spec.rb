require 'rails_helper'

RSpec.describe TnlAuth::Config do
  describe '.issuer' do
    it 'strips the trailing slash' do
      with_modified_env TNL_AUTH_ISSUER: 'https://auth.test/' do
        expect(described_class.issuer).to eq('https://auth.test')
      end
    end

    it 'is empty when not set' do
      with_modified_env TNL_AUTH_ISSUER: nil do
        expect(described_class.issuer).to eq('')
      end
    end
  end

  describe '.enabled?' do
    it 'is true when the issuer is present' do
      with_modified_env TNL_AUTH_ISSUER: 'https://auth.test' do
        expect(described_class.enabled?).to be(true)
      end
    end

    it 'is false when the issuer is missing or empty' do
      with_modified_env TNL_AUTH_ISSUER: '' do
        expect(described_class.enabled?).to be(false)
      end
    end
  end

  describe '.client_id' do
    it 'defaults to chatwoot' do
      with_modified_env TNL_AUTH_CLIENT_ID: nil do
        expect(described_class.client_id).to eq('chatwoot')
      end
    end

    it 'reads the env var' do
      with_modified_env TNL_AUTH_CLIENT_ID: 'outro' do
        expect(described_class.client_id).to eq('outro')
      end
    end
  end

  describe '.provider' do
    it 'defaults to google' do
      with_modified_env TNL_AUTH_PROVIDER: nil do
        expect(described_class.provider).to eq('google')
      end
    end

    it 'is empty when the variable exists and is empty' do
      with_modified_env TNL_AUTH_PROVIDER: '' do
        expect(described_class.provider).to eq('')
      end
    end
  end

  describe '.callback_url' do
    it 'builds the url from FRONTEND_URL' do
      with_modified_env FRONTEND_URL: 'http://www.example.com' do
        expect(described_class.callback_url).to eq('http://www.example.com/omniauth/tnl_auth/callback')
      end
    end

    it 'does not double the slash when FRONTEND_URL ends with slash' do
      with_modified_env FRONTEND_URL: 'http://www.example.com/' do
        expect(described_class.callback_url).to eq('http://www.example.com/omniauth/tnl_auth/callback')
      end
    end
  end
end
