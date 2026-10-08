# frozen_string_literal: true

require 'rails_helper'

# Auto-atribuição desligada (spec 040): nenhuma conversa é atribuída automaticamente.
shared_examples_for 'auto_assignment_handler' do
  describe '#auto assignment' do
    let(:account) { create(:account) }
    let(:agent) { create(:user, email: 'agent1@example.com', account: account, auto_offline: false) }
    let(:inbox) { create(:inbox, account: account, enable_auto_assignment: true) }
    let(:conversation) do
      create(
        :conversation,
        account: account,
        contact: create(:contact, account: account),
        inbox: inbox,
        assignee: nil
      )
    end

    before do
      create(:inbox_member, inbox: inbox, user: agent)
      allow(Redis::Alfred).to receive(:rpoplpush).and_return(agent.id)
    end

    it 'does not auto assign on creation even with enable_auto_assignment true' do
      expect(conversation.reload.assignee).to be_nil
    end

    it 'does not enqueue AssignmentJob with assignment v2 enabled' do
      allow_any_instance_of(Inbox).to receive(:auto_assignment_v2_enabled?).and_return(true) # rubocop:disable RSpec/AnyInstance
      expect(AutoAssignment::AssignmentJob).not_to receive(:enqueue_for_inbox)

      conversation
    end

    it 'does not enqueue AssignmentJob with assignment v2 disabled' do
      allow_any_instance_of(Inbox).to receive(:auto_assignment_v2_enabled?).and_return(false) # rubocop:disable RSpec/AnyInstance
      expect(AutoAssignment::AssignmentJob).not_to receive(:enqueue_for_inbox)

      conversation
    end

    it 'does not auto assign when a resolved conversation is reopened' do
      conversation.update!(status: 'resolved')
      conversation.update!(status: 'open')

      expect(conversation.reload.assignee).to be_nil
    end

    it 'does not auto assign agent if its a bot conversation' do
      conversation = create(
        :conversation,
        account: account,
        contact: create(:contact, account: account),
        inbox: inbox,
        status: 'pending',
        assignee: nil
      )

      expect(conversation.reload.assignee).to be_nil
    end

    it 'keeps manual assignment working' do
      conversation.update!(assignee: agent)

      expect(conversation.reload.assignee).to eq(agent)
    end
  end
end
