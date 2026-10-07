require 'rails_helper'

RSpec.describe Inboxes::TeamChangeJob do
  let(:account) { create(:account) }
  let(:team_a) { create(:team, account: account) }
  let(:team_b) { create(:team, account: account) }
  let(:inbox) { create(:inbox, account: account, team: team_a) }
  let(:agent_a) { create(:user, account: account, role: :agent) }
  let(:agent_b) { create(:user, account: account, role: :agent) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let!(:open_conversation) { create(:conversation, account: account, inbox: inbox, status: :open) }
  let!(:resolved_conversation) { create(:conversation, account: account, inbox: inbox, status: :resolved) }

  before do
    create(:team_member, team: team_a, user: agent_a)
    create(:team_member, team: team_b, user: agent_b)
  end

  # Mirrors what the Inbox callback does, without enqueuing the job
  def switch_team(to_team)
    previous_team_id = inbox.team_id
    inbox.update_column(:team_id, to_team&.id) # rubocop:disable Rails/SkipsModelValidations
    described_class.perform_now(inbox_id: inbox.id, previous_team_id: previous_team_id, new_team_id: to_team&.id)
  end

  def tag(conversation, titles)
    Labels::TaggingWriter.new(account: account).apply(record: conversation, added_labels: titles, removed_labels: [])
  end

  it 'moves open and resolved conversations to the new team' do
    switch_team(team_b)

    expect(open_conversation.reload.team_id).to eq(team_b.id)
    expect(resolved_conversation.reload.team_id).to eq(team_b.id)
  end

  it 'does not touch conversations of other inboxes' do
    other = create(:conversation, account: account, inbox: create(:inbox, account: account, team: team_a))

    switch_team(team_b)

    expect(other.reload.team_id).to eq(team_a.id)
  end

  it 'does nothing when the inbox no longer exists' do
    expect do
      described_class.perform_now(inbox_id: 0, previous_team_id: team_a.id, new_team_id: team_b.id)
    end.not_to raise_error
  end

  describe 'assignees' do
    it 'keeps members of the new team and administrators and clears the others' do
      open_conversation.update_column(:assignee_id, agent_b.id) # rubocop:disable Rails/SkipsModelValidations
      resolved_conversation.update_column(:assignee_id, admin.id) # rubocop:disable Rails/SkipsModelValidations
      third = create(:conversation, account: account, inbox: inbox)
      third.update_column(:assignee_id, agent_a.id) # rubocop:disable Rails/SkipsModelValidations

      switch_team(team_b)

      expect(open_conversation.reload.assignee_id).to eq(agent_b.id)
      expect(resolved_conversation.reload.assignee_id).to eq(admin.id)
      expect(third.reload.assignee_id).to be_nil
    end
  end

  describe 'labels' do
    it 'removes only the labels of the previous team' do
      old_label = create(:label, account: account, team: team_a)
      new_label = create(:label, account: account, team: team_b)
      tag(open_conversation, [old_label.title, new_label.title, 'sem-time'])
      contact = open_conversation.contact
      contact.update!(label_list: [old_label.title])

      switch_team(team_b)

      expect(open_conversation.reload.label_list).to contain_exactly(new_label.title, 'sem-time')
      expect(open_conversation.cached_label_list).not_to include(old_label.title)
      expect(contact.reload.label_list).to eq([old_label.title])
    end
  end

  describe 'notifications' do
    def notify(user, conversation)
      create(:notification, user: user, account: account, primary_actor: conversation, notification_type: 'conversation_mention')
    end

    it 'removes notifications of previous team members that lost access, keeping admins and shared members' do
      shared = create(:user, account: account, role: :agent)
      create(:team_member, team: team_a, user: shared)
      create(:team_member, team: team_b, user: shared)
      create(:team_member, team: team_a, user: admin)
      lost = notify(agent_a, open_conversation)
      admin_notification = notify(admin, open_conversation)
      shared_notification = notify(shared, open_conversation)

      switch_team(team_b)

      expect(Notification.exists?(lost.id)).to be(false)
      expect(Notification.exists?(admin_notification.id)).to be(true)
      expect(Notification.exists?(shared_notification.id)).to be(true)
    end
  end

  describe 'when the new team is nil' do
    it 'clears the team, assignees and notifications of previous members' do
      open_conversation.update_column(:assignee_id, agent_a.id) # rubocop:disable Rails/SkipsModelValidations
      admin_assigned = create(:conversation, account: account, inbox: inbox)
      admin_assigned.update_column(:assignee_id, admin.id) # rubocop:disable Rails/SkipsModelValidations
      notification = create(:notification, user: agent_a, account: account, primary_actor: open_conversation,
                                           notification_type: 'conversation_mention')

      switch_team(nil)

      expect(open_conversation.reload.team_id).to be_nil
      expect(open_conversation.assignee_id).to be_nil
      expect(admin_assigned.reload.assignee_id).to eq(admin.id)
      expect(Notification.exists?(notification.id)).to be(false)
    end
  end

  describe 'when the previous team is nil' do
    let(:inbox) { create(:inbox, account: account, team: nil) }

    it 'migrates conversations and keeps labels and notifications' do
      label = create(:label, account: account, team: team_a)
      tag(open_conversation, [label.title])
      notification = create(:notification, user: agent_a, account: account, primary_actor: open_conversation,
                                           notification_type: 'conversation_mention')

      switch_team(team_b)

      expect(open_conversation.reload.team_id).to eq(team_b.id)
      expect(open_conversation.label_list).to eq([label.title])
      expect(Notification.exists?(notification.id)).to be(true)
    end
  end

  it 'is idempotent' do
    label = create(:label, account: account, team: team_a)
    tag(open_conversation, [label.title])
    switch_team(team_b)

    expect do
      described_class.perform_now(inbox_id: inbox.id, previous_team_id: team_a.id, new_team_id: team_b.id)
    end.not_to(change { [open_conversation.reload.team_id, open_conversation.label_list, resolved_conversation.reload.team_id] })
  end

  it 'does not create activity messages' do
    expect { switch_team(team_b) }.not_to(change { Message.where(conversation_id: [open_conversation.id, resolved_conversation.id]).count })
  end

  it 'bumps the inbox and label cache keys' do
    before_keys = account.cache_keys

    switch_team(team_b)

    after_keys = account.cache_keys
    expect(after_keys[:inbox]).not_to eq(before_keys[:inbox])
    expect(after_keys[:label]).not_to eq(before_keys[:label])
  end
end
