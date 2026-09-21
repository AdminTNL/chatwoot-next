require 'rails_helper'

RSpec.describe Contacts::AccessScope do
  let(:account) { create(:account) }
  let(:team_a) { create(:team, account: account) }
  let(:team_b) { create(:team, account: account) }

  let(:inbox_a) { create(:inbox, account: account, team: team_a) }
  let(:inbox_b) { create(:inbox, account: account, team: team_b) }
  let(:direct_inbox) { create(:inbox, account: account) }

  let(:administrator) { create(:user, :administrator, account: account) }
  let(:agent) { create(:user, account: account, role: :agent) }

  def scope_for(user)
    account_user = account.account_users.find_by(user: user)
    described_class.new(account: account, user: user, account_user: account_user)
  end

  describe '#unrestricted?' do
    it 'is true for an administrator' do
      expect(scope_for(administrator)).to be_unrestricted
    end

    it 'is false for a plain agent' do
      expect(scope_for(agent)).not_to be_unrestricted
    end
  end

  describe '#inbox_ids' do
    before do
      inbox_a
      inbox_b
      team_a.add_members([agent.id])
      create(:inbox_member, inbox: direct_inbox, user: agent)
    end

    it 'is nil for an unrestricted user' do
      expect(scope_for(administrator).inbox_ids).to be_nil
    end

    it 'combines team inboxes and direct inbox membership for a restricted agent' do
      expect(scope_for(agent).inbox_ids).to contain_exactly(inbox_a.id, direct_inbox.id)
    end

    it 'excludes inboxes of teams the agent does not belong to' do
      expect(scope_for(agent).inbox_ids).not_to include(inbox_b.id)
    end

    it 'is empty (not account-wide) for an agent with no access at all' do
      expect(scope_for(create(:user, account: account, role: :agent)).inbox_ids).to eq([])
    end
  end

  describe '#restrict' do
    it 'returns the relation untouched for an unrestricted (administrator) user' do
      contacts_relation = account.contacts

      expect(scope_for(administrator).restrict(contacts_relation)).to equal(contacts_relation)
    end

    it 'includes a contact with a conversation in an inbox accessible to the agent' do
      team_a.add_members([agent.id])
      contact = create(:contact, account: account)
      create(:conversation, account: account, inbox: inbox_a, contact: contact)

      expect(scope_for(agent).restrict(account.contacts)).to include(contact)
    end

    it 'excludes a contact whose only conversation is in an inaccessible inbox' do
      team_a.add_members([agent.id])
      contact = create(:contact, account: account)
      create(:conversation, account: account, inbox: inbox_b, contact: contact)

      expect(scope_for(agent).restrict(account.contacts)).not_to include(contact)
    end

    it 'excludes a contact only linked via contact_inbox with no conversation' do
      team_a.add_members([agent.id])
      contact = create(:contact, account: account)
      create(:contact_inbox, contact: contact, inbox: inbox_a)

      expect(scope_for(agent).restrict(account.contacts)).not_to include(contact)
    end

    it 'does not duplicate a contact with conversations in two accessible inboxes' do
      team_a.add_members([agent.id])
      create(:inbox_member, inbox: direct_inbox, user: agent)
      contact = create(:contact, account: account)
      create(:conversation, account: account, inbox: inbox_a, contact: contact)
      create(:conversation, account: account, inbox: direct_inbox, contact: contact)

      restricted = scope_for(agent).restrict(account.contacts)

      expect(restricted.where(id: contact.id).count).to eq(1)
    end

    it 'returns no contacts, without raising, for an agent with no accessible inbox at all' do
      contact = create(:contact, account: account)
      create(:conversation, account: account, inbox: inbox_a, contact: contact)

      expect(scope_for(agent).restrict(account.contacts)).to be_empty
    end
  end
end
