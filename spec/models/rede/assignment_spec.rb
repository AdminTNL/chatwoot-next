require 'rails_helper'

RSpec.describe Rede::Assignment do
  let(:account) { create(:account) }
  let(:project) { create(:team, account: account).rede_project }
  let(:participation) { create(:rede_participation, account: account, project: project) }
  let(:front) { create(:rede_front, account: account, project: project) }

  def build_assignment(**attrs)
    described_class.new({ account: account, participation: participation }.merge(attrs))
  end

  it 'is valid without front, role and superior' do
    assignment = build_assignment
    assignment.validate

    expect(assignment).to be_valid
    expect(assignment).to be_active
    expect(assignment.started_at).to be_present
  end

  describe 'front' do
    it 'accepts an active front of the same project' do
      expect(build_assignment(front: front)).to be_valid
    end

    it 'rejects a front of another project' do
      other_front = create(:rede_front, account: account)

      expect(build_assignment(front: other_front)).not_to be_valid
    end

    it 'rejects a closed front' do
      front.close!

      expect(build_assignment(front: front)).not_to be_valid
    end

    it 'allows no front in a project that has fronts' do
      front

      expect(build_assignment(front: nil)).to be_valid
    end
  end

  describe 'one active assignment per participation and front' do
    it 'rejects a second active assignment without front' do
      build_assignment.save!

      expect(build_assignment).not_to be_valid
    end

    it 'rejects a second active assignment in the same front' do
      build_assignment(front: front).save!

      expect(build_assignment(front: front)).not_to be_valid
    end

    it 'allows the same front again once the previous one is closed' do
      build_assignment(front: front).tap(&:save!).close!

      expect(build_assignment(front: front)).to be_valid
    end

    it 'allows an assignment without front plus one with front' do
      build_assignment.save!

      expect(build_assignment(front: front)).to be_valid
    end

    it 'is enforced by the database with COALESCE for the null front' do
      build_assignment.save!

      expect { build_assignment(started_at: Time.current).save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'is enforced by the database for the same front' do
      build_assignment(front: front).save!

      expect { build_assignment(front: front, started_at: Time.current).save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'does not apply the index to closed rows' do
      build_assignment.tap(&:save!).close!

      expect { build_assignment(started_at: Time.current).save!(validate: false) }.not_to raise_error
    end
  end

  describe 'superior and role' do
    it 'rejects the person as their own superior' do
      expect(build_assignment(superior_contact: participation.contact)).not_to be_valid
    end

    it 'accepts another contact of the account' do
      expect(build_assignment(superior_contact: create(:contact, account: account))).to be_valid
    end

    it 'rejects a superior of another account' do
      expect(build_assignment(superior_contact: create(:contact, account: create(:account)))).not_to be_valid
    end

    it 'rejects a role of another account' do
      expect(build_assignment(role: create(:rede_role, account: create(:account)))).not_to be_valid
    end

    it 'accepts a role of the account' do
      expect(build_assignment(role: create(:rede_role, account: account))).to be_valid
    end
  end

  describe '#revise!' do
    let(:role_a) { create(:rede_role, account: account) }
    let(:role_b) { create(:rede_role, account: account) }
    let!(:assignment) { build_assignment(role: role_a).tap(&:save!) }

    it 'closes the current row and opens a new one when the role changes' do
      revised = assignment.revise!(role_id: role_b.id)

      expect(revised).not_to eq(assignment)
      expect(revised).to be_active
      expect(revised.role).to eq(role_b)
      expect(assignment.reload).to be_closed
      expect(assignment.ended_at).to be_present
    end

    it 'moves a "front to define" assignment to a front' do
      revised = assignment.revise!(front_id: front.id)

      expect(revised.front).to eq(front)
      expect(revised.role).to eq(role_a)
      expect(assignment.reload).to be_closed
    end

    it 'does nothing when nothing changes' do
      expect { assignment.revise!(role_id: role_a.id) }.not_to change(described_class, :count)
    end

    it 'rolls back when the new row is invalid' do
      expect { assignment.revise!(superior_contact_id: participation.contact_id) }.to raise_error(ActiveRecord::RecordInvalid)
      expect(assignment.reload).to be_active
    end

    it 'refuses to revise a closed assignment' do
      assignment.close!

      expect { assignment.revise!(role_id: role_b.id) }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
