require 'rails_helper'

RSpec.describe Label do
  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to belong_to(:team).optional }
  end

  describe 'team validations' do
    it 'is valid without a team' do
      label = FactoryBot.build(:label, team: nil)
      expect(label.valid?).to be true
    end

    it 'is valid when the team belongs to the same account' do
      account = create(:account)
      team = create(:team, account: account)
      label = FactoryBot.build(:label, account: account, team: team)

      expect(label.valid?).to be true
    end

    it 'is invalid when the team belongs to a different account' do
      account = create(:account)
      other_account_team = create(:team, account: create(:account))
      label = FactoryBot.build(:label, account: account, team: other_account_team)

      expect(label.valid?).to be false
      expect(label.errors[:team]).to be_present
    end

    it 'becomes global when its team is destroyed' do
      account = create(:account)
      team = create(:team, account: account)
      label = create(:label, account: account, team: team)

      team.destroy!

      expect(label.reload.team_id).to be_nil
    end
  end

  describe 'title validations' do
    it 'would not let you start title without numbers or letters' do
      label = FactoryBot.build(:label, title: '_12')
      expect(label.valid?).to be false
    end

    it 'would not let you use special characters' do
      label = FactoryBot.build(:label, title: 'jell;;2_12')
      expect(label.valid?).to be false
    end

    it 'would not allow space' do
      label = FactoryBot.build(:label, title: 'heeloo _12')
      expect(label.valid?).to be false
    end

    it 'allows foreign charactes' do
      label = FactoryBot.build(:label, title: '学中文_12')
      expect(label.valid?).to be true
    end

    it 'converts uppercase letters to lowercase' do
      label = FactoryBot.build(:label, title: 'Hello_World')
      expect(label.valid?).to be true
      expect(label.title).to eq 'hello_world'
    end

    it 'validates uniqueness of label name for account' do
      account = create(:account)
      label = FactoryBot.create(:label, account: account)
      duplicate_label = FactoryBot.build(:label, title: label.title, account: account)
      expect(duplicate_label.valid?).to be false
    end
  end

  describe '.after_update_commit' do
    let(:label) { create(:label) }

    it 'calls update job' do
      expect(Labels::UpdateJob).to receive(:perform_later).with('new-title', label.title, label.account_id)

      label.update(title: 'new-title')
    end

    it 'does not call update job if title is not updated' do
      expect(Labels::UpdateJob).not_to receive(:perform_later)

      label.update(description: 'new-description')
    end
  end
end
