FactoryBot.define do
  factory :conversation_participant do
    conversation
    account

    before(:build) do |conversation|
      if conversation.user.blank?
        conversation.user = create(:user, account: conversation.account)
        inbox = conversation.conversation.inbox
        team = inbox.team || create(:team, account: inbox.account).tap { |new_team| inbox.update!(team: new_team) }
        create(:team_member, user: conversation.user, team: team)
      end
    end
  end
end
