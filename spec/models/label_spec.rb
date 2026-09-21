require 'rails_helper'

RSpec.describe Label do
  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to belong_to(:team) }
  end

  describe 'team validations' do
    it 'is invalid without a team' do
      label = FactoryBot.build(:label, team: nil)

      expect(label.valid?).to be false
      expect(label.errors[:team]).to be_present
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

    it 'leaves an existing global label untouched when its team is destroyed' do
      account = create(:account)
      team = create(:team, account: account)
      label = create(:label, account: account, team: team)

      team.destroy!

      expect(label.reload.team_id).to be_nil
    end
  end

  describe 'label_group validations' do
    it 'is valid without a label_group' do
      account = create(:account)
      team = create(:team, account: account)
      label = FactoryBot.build(:label, account: account, team: team, label_group: nil)
      expect(label.valid?).to be true
    end

    it 'is valid when the label_group belongs to the same team as the label' do
      account = create(:account)
      team = create(:team, account: account)
      label_group = create(:label_group, account: account, team: team)
      label = FactoryBot.build(:label, account: account, team: team, label_group: label_group)

      expect(label.valid?).to be true
    end

    it 'is invalid when the label_group belongs to a different team than the label' do
      account = create(:account)
      team = create(:team, account: account)
      other_team = create(:team, account: account)
      label_group = create(:label_group, account: account, team: other_team)
      label = FactoryBot.build(:label, account: account, team: team, label_group: label_group)

      expect(label.valid?).to be false
      expect(label.errors[:label_group]).to be_present
    end

    it 'is invalid when the label_group is present but the label has no team' do
      account = create(:account)
      team = create(:team, account: account)
      label_group = create(:label_group, account: account, team: team)
      label = FactoryBot.build(:label, account: account, team: nil, label_group: label_group)

      expect(label.valid?).to be false
      expect(label.errors[:label_group]).to be_present
    end
  end

  describe 'title validations' do
    let(:account) { create(:account) }
    let(:team) { create(:team, account: account, name: 'Suporte') }

    it 'gets prefixed with the team slug even when the suffix alone would start with an invalid character' do
      label = FactoryBot.build(:label, account: account, team: team, title: '_12')
      expect(label.valid?).to be true
      expect(label.title).to eq 'suporte-_12'
    end

    it 'would not let you use special characters' do
      label = FactoryBot.build(:label, account: account, team: team, title: 'jell;;2_12')
      expect(label.valid?).to be false
    end

    it 'would not allow space' do
      label = FactoryBot.build(:label, account: account, team: team, title: 'heeloo _12')
      expect(label.valid?).to be false
    end

    it 'allows foreign charactes' do
      label = FactoryBot.build(:label, account: account, team: team, title: '学中文_12')
      expect(label.valid?).to be true
    end

    it 'converts uppercase letters to lowercase' do
      label = FactoryBot.build(:label, account: account, team: team, title: 'Hello_World')
      expect(label.valid?).to be true
      expect(label.title).to eq 'suporte-hello_world'
    end

    it 'validates uniqueness of label name for account' do
      label = FactoryBot.create(:label, account: account, team: team)
      duplicate_label = FactoryBot.build(:label, title: label.title, account: account, team: team)
      expect(duplicate_label.valid?).to be false
    end
  end

  describe 'team prefix on title' do
    let(:account) { create(:account) }

    it 'prefixes the title with the team slug when the title has no prefix yet' do
      team = create(:team, account: account, name: 'Suporte')
      label = create(:label, account: account, team: team, title: 'quente')

      expect(label.title).to eq 'suporte-quente'
    end

    it 'does not duplicate the prefix when the title already includes it' do
      team = create(:team, account: account, name: 'Suporte')
      label = create(:label, account: account, team: team, title: 'suporte-quente')

      expect(label.title).to eq 'suporte-quente'
    end

    it 'replaces the previous team prefix when the team changes' do
      team_a = create(:team, account: account, name: 'Time A')
      team_b = create(:team, account: account, name: 'Time B')
      label = create(:label, account: account, team: team_a, title: 'quente')
      expect(label.title).to eq 'time-a-quente'

      label.update!(team: team_b)

      expect(label.title).to eq 'time-b-quente'
    end

    it 'keeps the prefix unchanged when only the suffix changes for the same team' do
      team = create(:team, account: account, name: 'Suporte')
      label = create(:label, account: account, team: team, title: 'quente')

      label.update!(title: 'frio')

      expect(label.title).to eq 'suporte-frio'
    end

    it 'applies the new prefix without trying to strip the old one when the previous team was already destroyed' do
      team_a = create(:team, account: account, name: 'Time A')
      team_b = create(:team, account: account, name: 'Time B')
      label = create(:label, account: account, team: team_a, title: 'quente')
      expect(label.title).to eq 'time-a-quente'

      # team_a is destroyed without reloading `label`, so its in-memory
      # team_id_was still points at team_a even though team_a no longer exists.
      team_a.destroy!
      label.update!(team: team_b)

      expect(label.title).to eq 'time-b-time-a-quente'
    end

    it 'fails uniqueness validation when two teams produce the same slug and title' do
      team_a = create(:team, account: account, name: 'Time A')
      team_b = create(:team, account: account, name: 'time-a')
      create(:label, account: account, team: team_a, title: 'quente')

      duplicate_label = FactoryBot.build(:label, account: account, team: team_b, title: 'quente')

      expect(duplicate_label.valid?).to be false
      expect(duplicate_label.errors[:title]).to be_present
    end
  end

  describe '.after_update_commit' do
    let(:account) { create(:account) }
    let(:team) { create(:team, account: account) }
    let(:label) { create(:label, account: account, team: team) }

    it 'calls update job' do
      expected_new_title = "#{team.label_prefix}-new-title"
      expect(Labels::UpdateJob).to receive(:perform_later).with(expected_new_title, label.title, label.account_id)

      label.update(title: 'new-title')
    end

    it 'does not call update job if title is not updated' do
      expect(Labels::UpdateJob).not_to receive(:perform_later)

      label.update(description: 'new-description')
    end
  end
end
