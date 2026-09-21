require 'rails_helper'

RSpec.describe Labels::ContactPropagationService do
  let(:account) { create(:account) }
  let(:team) { create(:team, account: account) }
  let(:other_team) { create(:team, account: account) }
  let(:contact) { create(:contact, account: account) }

  let(:inbox) { create(:inbox, account: account, team: team) }
  let(:other_team_inbox) { create(:inbox, account: account, team: other_team) }

  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:sibling) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:other_team_conversation) { create(:conversation, account: account, inbox: other_team_inbox, contact: contact) }

  describe '#perform' do
    it 'propagates an added label only to conversations of the given team' do
      conversation
      other_team_conversation
      label = create(:label, account: account, team: team)

      described_class.new(
        contact_id: contact.id, team_id: team.id, added_labels: [label.title], removed_labels: []
      ).perform

      expect(conversation.reload.label_list).to contain_exactly(label.title)
      expect(other_team_conversation.reload.label_list).to eq([])
    end

    it 'propagates a removed label only to conversations of the given team' do
      label = create(:label, account: account, team: team)
      conversation.update!(label_list: [label.title])
      other_team_conversation.update!(label_list: [label.title])

      described_class.new(
        contact_id: contact.id, team_id: team.id, added_labels: [], removed_labels: [label.title]
      ).perform

      expect(conversation.reload.label_list).to eq([])
      expect(other_team_conversation.reload.label_list).to contain_exactly(label.title)
    end

    it 'respects label_group exclusivity on each target conversation independently' do
      label_group = create(:label_group, account: account, team: team)
      old_label = create(:label, account: account, team: team, label_group: label_group)
      new_label = create(:label, account: account, team: team, label_group: label_group)

      conversation.update!(label_list: [old_label.title])
      sibling.update!(label_list: [old_label.title])

      described_class.new(
        contact_id: contact.id, team_id: team.id, added_labels: [new_label.title], removed_labels: []
      ).perform

      expect(conversation.reload.label_list).to contain_exactly(new_label.title)
      expect(sibling.reload.label_list).to contain_exactly(new_label.title)
    end

    it 'does not raise when the contact has no conversations in the given team' do
      label = create(:label, account: account, team: team)

      expect do
        described_class.new(
          contact_id: contact.id, team_id: team.id, added_labels: [label.title], removed_labels: []
        ).perform
      end.not_to raise_error
    end

    it 'does not raise when the contact does not exist' do
      expect do
        described_class.new(
          contact_id: -1, team_id: team.id, added_labels: ['some-label'], removed_labels: []
        ).perform
      end.not_to raise_error
    end
  end
end
