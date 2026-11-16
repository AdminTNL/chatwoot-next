require 'rails_helper'

RSpec.describe Rede::ApiToken do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, role: :administrator) }

  describe '.generate!' do
    it 'returns the record and the plain value in the rede_ format' do
      record, plain = described_class.generate!(account: account, name: 'Formulários Central', user: user)

      expect(record).to be_persisted
      expect(plain).to match(/\Arede_[A-Za-z0-9]{40}\z/)
      expect(record).to have_attributes(
        account_id: account.id, name: 'Formulários Central', created_by_user_id: user.id,
        scopes: ['projects:read'], token_prefix: plain[0, 8], revoked_at: nil, last_used_at: nil
      )
    end

    it 'stores only the SHA-256 digest, never the plain value' do
      record, plain = described_class.generate!(account: account, name: 'Token', user: user)

      expect(record.token_digest).to eq(Digest::SHA256.hexdigest(plain))
      row = ActiveRecord::Base.connection.select_one("SELECT * FROM rede_api_tokens WHERE id = #{record.id}")
      expect(row.values.map(&:to_s).grep(/#{plain}/)).to be_empty
    end

    it 'generates different values on each call' do
      _, first = described_class.generate!(account: account, name: 'A', user: user)
      _, second = described_class.generate!(account: account, name: 'B', user: user)

      expect(first).not_to eq(second)
    end

    it 'requires a name' do
      expect { described_class.generate!(account: account, name: ' ', user: user) }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe 'validations' do
    it 'rejects unknown scopes' do
      token = build(:rede_api_token, account: account, scopes: ['projects:write'])

      expect(token).not_to be_valid
    end

    it 'enforces a unique token_digest' do
      first = create(:rede_api_token, account: account)

      expect(build(:rede_api_token, account: account, token_digest: first.token_digest)).not_to be_valid
    end
  end

  describe '.authenticate' do
    let!(:pair) { described_class.generate!(account: account, name: 'Token', user: user) }
    let(:record) { pair.first }
    let(:plain) { pair.last }

    it 'returns the token for a valid value' do
      expect(described_class.authenticate(plain)).to eq(record)
    end

    it 'returns nil for an unknown, blank or nil value' do
      expect(described_class.authenticate('rede_naoexiste')).to be_nil
      expect(described_class.authenticate('')).to be_nil
      expect(described_class.authenticate(nil)).to be_nil
    end

    it 'returns nil for a revoked token' do
      record.revoke!

      expect(described_class.authenticate(plain)).to be_nil
    end

    it 'sets last_used_at on first use' do
      freeze_time do
        described_class.authenticate(plain)

        expect(record.reload.last_used_at).to eq(Time.current)
      end
    end

    it 'updates last_used_at at most once per minute' do
      first_use = Time.zone.local(2026, 11, 16, 12, 0, 0)
      travel_to(first_use) { described_class.authenticate(plain) }

      travel_to(first_use + 30.seconds) { described_class.authenticate(plain) }
      expect(record.reload.last_used_at).to eq(first_use)

      travel_to(first_use + 61.seconds) { described_class.authenticate(plain) }
      expect(record.reload.last_used_at).to eq(first_use + 61.seconds)
    end
  end

  describe '#revoke!' do
    it 'sets revoked_at and is idempotent' do
      record, = described_class.generate!(account: account, name: 'Token', user: user)

      travel_to(Time.zone.local(2026, 11, 16, 12, 0, 0)) { record.revoke! }
      travel_to(Time.zone.local(2026, 11, 16, 13, 0, 0)) { record.revoke! }

      expect(record.reload.revoked_at).to eq(Time.zone.local(2026, 11, 16, 12, 0, 0))
      expect(record).to be_revoked
    end
  end

  describe '#scope?' do
    it 'checks the granted scopes' do
      token = build(:rede_api_token, scopes: ['projects:read'])

      expect(token.scope?('projects:read')).to be(true)
      expect(build(:rede_api_token, scopes: []).scope?('projects:read')).to be(false)
    end
  end
end
