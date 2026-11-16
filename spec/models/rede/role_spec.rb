require 'rails_helper'

RSpec.describe Rede::Role do
  let(:account) { create(:account) }

  it 'requires key and name' do
    role = described_class.new(account: account)

    expect(role).not_to be_valid
    expect(role.errors.attribute_names).to include(:key, :name)
  end

  it 'keeps the key unique per account' do
    create(:rede_role, account: account, key: 'extra')

    expect(build(:rede_role, account: account, key: 'extra')).not_to be_valid
    expect(build(:rede_role, account: create(:account), key: 'extra')).to be_valid
  end

  it 'enforces the unique key in the database' do
    create(:rede_role, account: account, key: 'extra')

    expect { build(:rede_role, account: account, key: 'extra').save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
