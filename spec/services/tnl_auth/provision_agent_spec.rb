require 'rails_helper'

RSpec.describe TnlAuth::ProvisionAgent do
  let(:account) { create(:account) }
  let(:allowed) { { 'email' => 'Ana@Gmail.com', 'name' => 'Ana Souza', 'role' => 'operator', 'status' => 'active', 'metadata' => nil } }
  let(:email) { 'ana@gmail.com' }

  before { account }

  def provision(attrs = allowed, account_id: account.id, mail: email)
    described_class.new(email: mail, allowed: attrs, account_id: account_id).perform
  end

  it 'creates a confirmed user with an agent role and no inviter' do
    user = provision

    expect(user).to be_persisted
    expect(user.email).to eq('ana@gmail.com')
    expect(user.name).to eq('Ana Souza')
    expect(user).to be_confirmed
    account_user = AccountUser.find_by(user_id: user.id, account_id: account.id)
    expect(account_user).to be_agent
    expect(account_user.inviter_id).to be_nil
  end

  it 'does not enqueue or deliver any confirmation email' do
    expect { provision }.not_to have_enqueued_mail(Devise::Mailer, :confirmation_instructions)
    expect(ActionMailer::Base.deliveries.map(&:subject)).not_to include(a_string_matching(/onfirm/i))
  end

  it 'lowercases the email' do
    expect(provision(allowed, mail: 'ANA@Gmail.com').email).to eq('ana@gmail.com')
  end

  it 'falls back to the email local part when the name is blank' do
    user = provision(allowed.merge('name' => ' '))

    expect(user.name).to eq('ana')
  end

  %w[master admin].each do |role|
    it "maps #{role} to administrator" do
      user = provision(allowed.merge('role' => role))

      expect(AccountUser.find_by(user_id: user.id)).to be_administrator
    end
  end

  %w[operator viewer].each do |role|
    it "maps #{role} to agent" do
      user = provision(allowed.merge('role' => role))

      expect(AccountUser.find_by(user_id: user.id)).to be_agent
    end
  end

  it 'maps an unknown role to agent' do
    user = provision(allowed.merge('role' => 'whatever'))

    expect(AccountUser.find_by(user_id: user.id)).to be_agent
  end

  describe 'teams' do
    let!(:team) { create(:team, account: account) }
    let!(:other_team) { create(:team, account: create(:account)) }

    it 'adds the user to teams of the same account and ignores others' do
      user = provision(allowed.merge('metadata' => { 'chatwoot_team_ids' => [team.id, other_team.id, 9_999_999] }))

      expect(user.team_members.pluck(:team_id)).to eq([team.id])
    end

    it 'ignores non integer ids' do
      user = provision(allowed.merge('metadata' => { 'chatwoot_team_ids' => [team.id.to_s, nil, 'x'] }))

      expect(user.team_members.count).to eq(0)
    end

    it 'ignores metadata that is not a hash or has a non array value' do
      [nil, 'x', { 'chatwoot_team_ids' => 3 }, {}].each_with_index do |metadata, i|
        user = provision(allowed.merge('metadata' => metadata), mail: "u#{i}@gmail.com")

        expect(user.team_members.count).to eq(0)
      end
    end
  end

  it 'rolls back the user when the account user fails' do
    allow(AccountUser).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)

    expect { provision }.to raise_error(ActiveRecord::RecordInvalid)
    expect(User.from_email(email)).to be_nil
  end

  it 'returns nil and creates nothing when the account does not exist' do
    expect(provision(allowed, account_id: 0)).to be_nil
    expect(User.from_email(email)).to be_nil
  end

  it 'returns the existing user on a unique violation race' do
    existing = create(:user, email: email)
    allow(User).to receive(:new).and_wrap_original do |original, *args, **kw|
      user = original.call(*args, **kw)
      allow(user).to receive(:save!).and_raise(ActiveRecord::RecordNotUnique)
      user
    end

    expect(provision).to eq(existing)
  end

  it 'logs the audit line without any token' do
    allow(Rails.logger).to receive(:info)

    provision

    expect(Rails.logger).to have_received(:info).with(/ana@gmail.com.*#{account.id}.*agent/)
  end
end
