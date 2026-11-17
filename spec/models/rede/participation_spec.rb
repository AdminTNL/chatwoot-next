require 'rails_helper'

RSpec.describe Rede::Participation do
  let(:account) { create(:account) }
  let(:team) { create(:team, account: account) }
  let(:project) { team.rede_project }
  let(:contact) { create(:contact, account: account) }

  def build_participation(**attrs)
    described_class.new({ account: account, contact: contact, project: project }.merge(attrs))
  end

  it 'is invalid (not an exception) when the status is unknown' do
    participation = build_participation(status: 'foo')

    expect(participation).not_to be_valid
    expect(participation.errors.attribute_names).to include(:status)
  end

  it 'is valid with defaults (manual, active, joined_at filled)' do
    participation = build_participation
    participation.validate

    expect(participation).to be_valid
    expect(participation).to be_origin_manual
    expect(participation).to be_active
    expect(participation.joined_at).to be_present
  end

  it 'maps the enums' do
    expect(described_class.origins).to eq('manual' => 0, 'import' => 1, 'integration' => 2, 'form' => 3)
    expect(described_class.statuses).to eq('active' => 0, 'closed' => 1)
  end

  it 'allows one participation per contact and project' do
    build_participation.save!

    duplicate = build_participation
    expect(duplicate).not_to be_valid
    expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it 'allows the same contact in another project' do
    build_participation.save!

    expect(build_participation(project: create(:team, account: account).rede_project)).to be_valid
  end

  it 'rejects a contact or project of another account' do
    expect(build_participation(contact: create(:contact, account: create(:account)))).not_to be_valid
    expect(build_participation(project: create(:team, account: create(:account)).rede_project)).not_to be_valid
  end

  describe 'responsible' do
    it 'accepts a team member' do
      user = create(:user, account: account, role: :agent)
      create(:team_member, team: team, user: user)

      expect(build_participation(responsible_user: user)).to be_valid
    end

    it 'accepts an administrator who is not a member' do
      admin = create(:user, account: account, role: :administrator)

      expect(build_participation(responsible_user: admin)).to be_valid
    end

    it 'rejects an agent who is not a member' do
      agent = create(:user, account: account, role: :agent)
      participation = build_participation(responsible_user: agent)

      expect(participation).not_to be_valid
      expect(participation.errors.attribute_names).to include(:responsible_user)
    end

    it 'may be empty' do
      expect(build_participation(responsible_user: nil)).to be_valid
    end
  end

  describe 'referral' do
    it 'rejects both referred_by_contact and referred_by_text' do
      other = create(:contact, account: account)

      expect(build_participation(referred_by_contact: other, referred_by_text: 'Fulano')).not_to be_valid
    end

    it 'rejects the person referring themselves' do
      expect(build_participation(referred_by_contact: contact)).not_to be_valid
    end

    it 'rejects a referrer of another account' do
      expect(build_participation(referred_by_contact: create(:contact, account: create(:account)))).not_to be_valid
    end
  end

  it 'does not accept new participations in a closed project' do
    project.close!

    expect(build_participation).not_to be_valid
  end

  it 'accepts changes on an existing participation of a closed project' do
    participation = build_participation.tap(&:save!)
    project.close!

    expect(participation.update(next_step: 'Ligar')).to be(true)
  end

  it 'is destroyed with the contact, along with its assignments' do
    participation = build_participation.tap(&:save!)
    create(:rede_assignment, account: account, participation: participation)

    expect { contact.destroy! }.to change(described_class, :count).by(-1).and change(Rede::Assignment, :count).by(-1)
  end
end
