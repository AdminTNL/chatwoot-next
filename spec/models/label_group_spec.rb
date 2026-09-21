require 'rails_helper'

RSpec.describe LabelGroup do
  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to belong_to(:team) }
    it { is_expected.to have_many(:labels) }
  end

  describe 'team validations' do
    it 'is invalid without a team' do
      account = create(:account)
      label_group = FactoryBot.build(:label_group, account: account, team: nil)

      expect(label_group.valid?).to be false
      expect(label_group.errors[:team]).to be_present
    end

    it 'is valid when the team belongs to the same account' do
      account = create(:account)
      team = create(:team, account: account)
      label_group = FactoryBot.build(:label_group, account: account, team: team)

      expect(label_group.valid?).to be true
    end

    it 'is invalid when the team belongs to a different account' do
      account = create(:account)
      other_account_team = create(:team, account: create(:account))
      label_group = FactoryBot.build(:label_group, account: account, team: other_account_team)

      expect(label_group.valid?).to be false
      expect(label_group.errors[:team]).to be_present
    end

    it 'destroys the label groups when the team is destroyed' do
      account = create(:account)
      team = create(:team, account: account)
      label_group = create(:label_group, account: account, team: team)

      team.destroy!

      expect(LabelGroup.exists?(label_group.id)).to be false
    end

    it 'nullifies the label_group_id of labels when the team is destroyed' do
      account = create(:account)
      team = create(:team, account: account)
      label_group = create(:label_group, account: account, team: team)
      label = create(:label, account: account, team: team, label_group: label_group)

      team.destroy!

      expect(Label.exists?(label.id)).to be true
      expect(label.reload.label_group_id).to be_nil
    end
  end

  describe 'name validations' do
    it 'is invalid without a name' do
      label_group = FactoryBot.build(:label_group, name: nil)
      expect(label_group.valid?).to be false
    end

    it 'normalizes the name with strip and downcase' do
      label_group = FactoryBot.build(:label_group, name: '  Hot Lead  ')
      label_group.valid?

      expect(label_group.name).to eq('hot lead')
    end

    it 'validates uniqueness of name scoped to team' do
      account = create(:account)
      team = create(:team, account: account)
      FactoryBot.create(:label_group, account: account, team: team, name: 'temperature')
      duplicate = FactoryBot.build(:label_group, account: account, team: team, name: 'temperature')

      expect(duplicate.valid?).to be false
    end

    it 'allows the same name for label groups of different teams' do
      account = create(:account)
      team_a = create(:team, account: account)
      team_b = create(:team, account: account)
      FactoryBot.create(:label_group, account: account, team: team_a, name: 'temperature')
      other_team_group = FactoryBot.build(:label_group, account: account, team: team_b, name: 'temperature')

      expect(other_team_group.valid?).to be true
    end
  end

  describe '#labels' do
    it 'returns the labels belonging to the label group' do
      account = create(:account)
      team = create(:team, account: account)
      label_group = create(:label_group, account: account, team: team)
      label = create(:label, account: account, team: team, label_group: label_group)

      expect(label_group.labels).to contain_exactly(label)
    end
  end
end
