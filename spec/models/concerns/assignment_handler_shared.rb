# frozen_string_literal: true

require 'rails_helper'

shared_examples_for 'assignment_handler' do
  describe '#update_team' do
    let(:conversation) { create(:conversation, assignee: create(:user)) }
    let(:agent) do
      create(:user, email: 'agent@example.com', account: conversation.account, role: :agent, auto_offline: false)
    end
    let(:team) do
      create(:team, account: conversation.account, allow_auto_assign: false)
    end

    context 'when agent is current user' do
      before do
        Current.user = agent
        create(:team_member, team: team, user: agent)
        create(:inbox_member, user: agent, inbox: conversation.inbox)
        conversation.inbox.reload
      end

      # team_id is derived from the inbox's team (spec 008), so team assignment is now
      # exercised by pointing the conversation's inbox at a team and re-saving the
      # conversation, instead of writing `team:`/`team_id:` directly on it.
      it 'creates team assigned and unassigned message activity' do
        conversation.inbox.update!(team: team)
        expect(conversation.save).to be true
        conversation.inbox.update!(team: nil)
        expect(conversation.save).to be true
        expect(Conversations::ActivityMessageJob).to(have_been_enqueued.at_least(:once)
          .with(conversation, { account_id: conversation.account_id, inbox_id: conversation.inbox_id, message_type: :activity,
                                content: "Assigned to #{team.name} by #{agent.name}"  }))
        expect(Conversations::ActivityMessageJob).to(have_been_enqueued.at_least(:once)
          .with(conversation, { account_id: conversation.account_id, inbox_id: conversation.inbox_id, message_type: :activity,
                                content: "Unassigned from #{team.name} by #{agent.name}" }))
      end

      it 'changes assignee to nil if they doesnt belong to the team and allow_auto_assign is false' do
        expect(team.allow_auto_assign).to be false

        conversation.inbox.update!(team: team)
        conversation.save

        expect(conversation.reload.assignee).to be_nil
      end

      it 'changes assignee to a team member if allow_auto_assign is enabled' do
        team.update!(allow_auto_assign: true)

        conversation.inbox.update!(team: team)
        conversation.save

        expect(conversation.reload.assignee).to eq agent
        expect(Conversations::ActivityMessageJob).to(have_been_enqueued.at_least(:once)
          .with(conversation, { account_id: conversation.account_id, inbox_id: conversation.inbox_id, message_type: :activity,
                                content: "Assigned to #{conversation.assignee.name} via #{team.name} by #{agent.name}" }))
      end

      it 'wont change assignee if he is already a team member' do
        team.update!(allow_auto_assign: true)
        assignee = create(:user, account: conversation.account, role: :agent)
        create(:inbox_member, user: assignee, inbox: conversation.inbox)
        create(:team_member, team: team, user: assignee)
        conversation.update(assignee: assignee)

        conversation.inbox.update!(team: team)
        conversation.save

        expect(conversation.reload.assignee).to eq assignee
      end
    end
  end
end
