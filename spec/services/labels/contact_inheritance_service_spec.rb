require 'rails_helper'

RSpec.describe Labels::ContactInheritanceService do
  let(:account) { create(:account) }
  let(:team) { create(:team, account: account) }
  let(:other_team) { create(:team, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:inbox) { create(:inbox, account: account, team: team) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }

  describe '#perform' do
    it 'applies the contact label of the conversation team to the new conversation' do
      label = create(:label, account: account, team: team)
      contact.update!(label_list: [label.title])

      described_class.new(conversation_id: conversation.id).perform

      expect(conversation.reload.label_list).to contain_exactly(label.title)
    end

    it 'does not apply a contact label that belongs to another team' do
      other_label = create(:label, account: account, team: other_team)
      contact.update!(label_list: [other_label.title])

      described_class.new(conversation_id: conversation.id).perform

      expect(conversation.reload.label_list).to eq([])
    end

    it 'applies every contact label of the conversation team' do
      labels = create_list(:label, 2, account: account, team: team)
      contact.update!(label_list: labels.map(&:title))

      described_class.new(conversation_id: conversation.id).perform

      expect(conversation.reload.label_list).to match_array(labels.map(&:title))
    end

    it 'applies only the labels of the conversation team when the contact has labels from several teams' do
      label = create(:label, account: account, team: team)
      other_label = create(:label, account: account, team: other_team)
      contact.update!(label_list: [label.title, other_label.title])

      described_class.new(conversation_id: conversation.id).perform

      expect(conversation.reload.label_list).to contain_exactly(label.title)
    end

    it 'fills cached_label_list' do
      labels = create_list(:label, 2, account: account, team: team)
      contact.update!(label_list: labels.map(&:title))

      described_class.new(conversation_id: conversation.id).perform

      expect(conversation.reload.cached_label_list.split(',').map(&:strip)).to match_array(labels.map(&:title))
    end

    it 'does nothing when the contact has no labels' do
      create(:label, account: account, team: team)
      conversation

      expect(Labels::TaggingWriter).not_to receive(:new)

      expect { described_class.new(conversation_id: conversation.id).perform }.not_to raise_error
      expect(conversation.reload.label_list).to eq([])
    end

    it 'does nothing when the conversation has no team' do
      label = create(:label, account: account, team: team)
      contact.update!(label_list: [label.title])
      conversation_without_team = create(:conversation, account: account, contact: contact)

      described_class.new(conversation_id: conversation_without_team.id).perform

      expect(conversation_without_team.reload.label_list).to eq([])
    end

    it 'does not raise when the conversation does not exist' do
      expect { described_class.new(conversation_id: -1).perform }.not_to raise_error
    end

    it 'does not raise when the contact no longer exists' do
      conversation
      allow(Conversation).to receive(:find_by).with(id: conversation.id).and_return(conversation)
      allow(conversation).to receive(:contact).and_return(nil)

      expect { described_class.new(conversation_id: conversation.id).perform }.not_to raise_error
    end

    it 'does not create an activity message on the conversation' do
      label = create(:label, account: account, team: team)
      contact.update!(label_list: [label.title])
      conversation

      expect { described_class.new(conversation_id: conversation.id).perform }
        .not_to(change { conversation.messages.where(message_type: :activity).count })
    end

    it 'does not enqueue a propagation job' do
      label = create(:label, account: account, team: team)
      contact.update!(label_list: [label.title])
      conversation

      expect { described_class.new(conversation_id: conversation.id).perform }
        .not_to have_enqueued_job(Labels::PropagateJob)
    end

    it 'respects label group exclusivity between labels of the same group' do
      label_group = create(:label_group, account: account, team: team)
      first_label = create(:label, account: account, team: team, label_group: label_group)
      second_label = create(:label, account: account, team: team, label_group: label_group)
      contact.update!(label_list: [first_label.title, second_label.title])

      described_class.new(conversation_id: conversation.id).perform

      expect(conversation.reload.label_list.size).to eq(1)
      expect([first_label.title, second_label.title]).to include(conversation.label_list.first)
    end
  end
end
