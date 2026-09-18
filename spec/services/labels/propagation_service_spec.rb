require 'rails_helper'

RSpec.describe Labels::PropagationService do
  let(:account) { create(:account) }
  let(:team) { create(:team, account: account) }
  let(:other_team) { create(:team, account: account) }
  let(:contact) { create(:contact, account: account) }

  let(:inbox) { create(:inbox, account: account, team: team) }
  let(:sibling_inbox) { create(:inbox, account: account, team: team) }
  let(:other_team_inbox) { create(:inbox, account: account, team: other_team) }

  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:sibling) { create(:conversation, account: account, inbox: sibling_inbox, contact: contact) }

  describe '#perform' do
    it 'propagates an added label without label_group to sibling conversations and the contact, only summing' do
      conversation
      sibling.update!(label_list: ['existing'])
      label = create(:label, account: account, team: team)

      described_class.new(conversation_id: conversation.id, added_labels: [label.title], removed_labels: []).perform

      expect(sibling.reload.label_list).to match_array(['existing', label.title])
      expect(contact.reload.label_list).to contain_exactly(label.title)
    end

    it 'replaces a same-group label already present on the destination' do
      label_group = create(:label_group, account: account, team: team)
      old_label = create(:label, account: account, team: team, label_group: label_group)
      new_label = create(:label, account: account, team: team, label_group: label_group)

      conversation
      sibling.update!(label_list: [old_label.title])
      contact.update!(label_list: [old_label.title])

      described_class.new(conversation_id: conversation.id, added_labels: [new_label.title], removed_labels: []).perform

      expect(sibling.reload.label_list).to contain_exactly(new_label.title)
      expect(contact.reload.label_list).to contain_exactly(new_label.title)
    end

    it 'just adds a grouped label when the destination has no label from that group yet' do
      label_group = create(:label_group, account: account, team: team)
      new_label = create(:label, account: account, team: team, label_group: label_group)

      conversation
      sibling

      described_class.new(conversation_id: conversation.id, added_labels: [new_label.title], removed_labels: []).perform

      expect(sibling.reload.label_list).to contain_exactly(new_label.title)
    end

    it 'propagates a removed label to sibling conversations and the contact when present' do
      label = create(:label, account: account, team: team)
      conversation
      sibling.update!(label_list: [label.title, 'other'])
      contact.update!(label_list: [label.title])

      described_class.new(conversation_id: conversation.id, added_labels: [], removed_labels: [label.title]).perform

      expect(sibling.reload.label_list).to contain_exactly('other')
      expect(contact.reload.label_list).to eq([])
    end

    it 'does not raise when removing a label the destination never had' do
      label = create(:label, account: account, team: team)
      conversation
      sibling

      expect do
        described_class.new(conversation_id: conversation.id, added_labels: [], removed_labels: [label.title]).perform
      end.not_to raise_error

      expect(sibling.reload.label_list).to eq([])
      expect(contact.reload.label_list).to eq([])
    end

    it 'does not propagate anything when the source conversation has no team_id' do
      teamless_conversation = create(:conversation, account: account, contact: contact)
      sibling
      label = create(:label, account: account, team: team)

      described_class.new(conversation_id: teamless_conversation.id, added_labels: [label.title], removed_labels: []).perform

      expect(sibling.reload.label_list).to eq([])
      expect(contact.reload.label_list).to eq([])
    end

    it 'does not affect conversations belonging to a different team' do
      conversation
      other_team_conversation = create(:conversation, account: account, inbox: other_team_inbox, contact: contact)
      label = create(:label, account: account, team: team)

      described_class.new(conversation_id: conversation.id, added_labels: [label.title], removed_labels: []).perform

      expect(other_team_conversation.reload.label_list).to eq([])
    end

    it 'propagates only to the contact when there are no sibling conversations' do
      conversation
      label = create(:label, account: account, team: team)

      expect do
        described_class.new(conversation_id: conversation.id, added_labels: [label.title], removed_labels: []).perform
      end.not_to raise_error

      expect(contact.reload.label_list).to contain_exactly(label.title)
    end

    it 'is idempotent when the same propagation runs twice' do
      conversation
      sibling
      label = create(:label, account: account, team: team)

      2.times do
        described_class.new(conversation_id: conversation.id, added_labels: [label.title], removed_labels: []).perform
      end

      expect(sibling.reload.label_list).to contain_exactly(label.title)
      expect(
        ActsAsTaggableOn::Tagging.joins(:tag)
          .where(context: 'labels', taggable: sibling, tags: { name: label.title }).count
      ).to eq(1)
    end

    it 'does not raise when an added label title no longer exists as a Label record' do
      conversation
      sibling

      expect do
        described_class.new(conversation_id: conversation.id, added_labels: ['ghost-label'], removed_labels: []).perform
      end.not_to raise_error

      expect(sibling.reload.label_list).to contain_exactly('ghost-label')
    end

    it 'when two labels of the same group are added at once, the last one processed wins' do
      label_group = create(:label_group, account: account, team: team)
      first_label = create(:label, account: account, team: team, label_group: label_group)
      second_label = create(:label, account: account, team: team, label_group: label_group)

      conversation
      sibling

      described_class.new(
        conversation_id: conversation.id,
        added_labels: [first_label.title, second_label.title],
        removed_labels: []
      ).perform

      expect(sibling.reload.label_list).to contain_exactly(second_label.title)
    end

    it 'does not re-trigger propagation when updating a sibling conversation directly' do
      conversation
      sibling
      label = create(:label, account: account, team: team)

      expect do
        described_class.new(conversation_id: conversation.id, added_labels: [label.title], removed_labels: []).perform
      end.not_to have_enqueued_job(Labels::PropagateJob)
    end
  end
end
