require 'rails_helper'

RSpec.describe Rede::Front do
  let(:account) { create(:account) }
  let(:project) { create(:team, account: account).rede_project }

  describe 'validations' do
    it 'requires a name' do
      front = build(:rede_front, account: account, project: project, name: ' ')

      expect(front).not_to be_valid
      expect(front.errors.attribute_names).to include(:name)
    end

    it 'rejects a nil has_temperature instead of hitting the database constraint' do
      front = build(:rede_front, account: account, project: project, has_temperature: nil)

      expect(front).not_to be_valid
      expect(front.errors.attribute_names).to include(:has_temperature)
    end

    it 'strips the name before validating' do
      front = create(:rede_front, account: account, project: project, name: '  PE Digital  ')

      expect(front.name).to eq('PE Digital')
    end

    it 'rejects a duplicated name in the same project ignoring case' do
      create(:rede_front, account: account, project: project, name: 'PE Digital')
      front = build(:rede_front, account: account, project: project, name: 'pe digital')

      expect(front).not_to be_valid
      expect(front.errors.attribute_names).to include(:name)
    end

    it 'rejects a duplicated name even when the other front is closed' do
      create(:rede_front, account: account, project: project, name: 'PE Digital', status: :closed, closed_at: Time.current)

      expect(build(:rede_front, account: account, project: project, name: 'PE DIGITAL')).not_to be_valid
    end

    it 'allows the same name in another project' do
      other_project = create(:team, account: account).rede_project
      create(:rede_front, account: account, project: project, name: 'PE Digital')

      expect(build(:rede_front, account: account, project: other_project, name: 'PE Digital')).to be_valid
    end

    it 'is enforced by a unique index on lower(name)' do
      create(:rede_front, account: account, project: project, name: 'PE Digital')
      front = build(:rede_front, account: account, project: project, name: 'pe digital')

      expect { front.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe 'defaults' do
    it 'is active and uses temperature by default' do
      front = create(:rede_front, account: account, project: project)

      expect(front).to be_active
      expect(front.has_temperature).to be(true)
      expect(front.closed_at).to be_nil
    end
  end

  describe 'public_id' do
    it 'is generated on creation' do
      front = create(:rede_front, account: account, project: project)

      expect(front.reload.public_id).to match(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/)
    end

    it 'is unique per front' do
      fronts = create_list(:rede_front, 2, account: account, project: project)

      expect(fronts.map { |f| f.reload.public_id }.uniq.size).to eq(2)
    end

    it 'is not changed by update' do
      front = create(:rede_front, account: account, project: project)
      original = front.reload.public_id

      front.update!(public_id: SecureRandom.uuid, name: 'Outro nome')

      expect(front.reload.public_id).to eq(original)
      expect(front.name).to eq('Outro nome')
    end
  end

  describe 'status' do
    it 'defines the active and closed enum' do
      expect(described_class.statuses).to eq('active' => 0, 'closed' => 1)
    end

    it 'closes and reopens, idempotently' do
      front = create(:rede_front, account: account, project: project)

      front.close!
      closed_at = front.reload.closed_at
      front.close!

      expect(front.reload).to be_closed
      expect(front.closed_at).to eq(closed_at)

      front.reopen!
      front.reopen!

      expect(front.reload).to be_active
      expect(front.closed_at).to be_nil
    end
  end
end
