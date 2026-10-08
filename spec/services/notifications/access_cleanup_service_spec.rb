require 'rails_helper'

RSpec.describe Notifications::AccessCleanupService do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account) }
  let(:team_a) { create(:team, account: account) }
  let(:team_b) { create(:team, account: account) }
  let(:conversation_a) { create(:conversation, account: account, inbox: create(:inbox, account: account, team: team_a)) }
  let(:conversation_b) { create(:conversation, account: account, inbox: create(:inbox, account: account, team: team_b)) }

  def notify(user, conversation, acc = account)
    create(:notification, user: user, account: acc, primary_actor: conversation, notification_type: 'conversation_mention')
  end

  def run(users, acc = account)
    described_class.new(account: acc, user_ids: users.map(&:id)).perform
  end

  it 'removes only notifications of conversations the user no longer reaches' do
    create(:team_member, team: team_b, user: agent)
    na = notify(agent, conversation_a)
    nb = notify(agent, conversation_b)

    run([agent])

    expect(Notification.exists?(na.id)).to be(false)
    expect(Notification.exists?(nb.id)).to be(true)
  end

  it 'spares administrators' do
    admin = create(:user, account: account, role: :administrator)
    n = notify(admin, conversation_a)

    run([admin])

    expect(Notification.exists?(n.id)).to be(true)
  end

  it 'keeps notifications of conversations reachable through a legacy inbox membership' do
    create(:inbox_member, user: agent, inbox: conversation_a.inbox)
    n = notify(agent, conversation_a)

    run([agent])

    expect(Notification.exists?(n.id)).to be(true)
  end

  it 'does not touch notifications of other accounts' do
    other_account = create(:account)
    other_conversation = create(:conversation, account: other_account)
    other = notify(agent, other_conversation, other_account)

    run([agent])

    expect(Notification.exists?(other.id)).to be(true)
  end

  it 'removes all conversation notifications of a user who left the account' do
    n = notify(agent, conversation_a)
    agent.account_users.find_by(account: account).delete

    run([agent])

    expect(Notification.exists?(n.id)).to be(false)
  end
end
