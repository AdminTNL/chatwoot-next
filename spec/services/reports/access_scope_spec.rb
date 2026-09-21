require 'rails_helper'

RSpec.describe Reports::AccessScope do
  let(:account) { create(:account) }
  let(:team_a) { create(:team, account: account) }
  let(:team_b) { create(:team, account: account) }

  let(:inbox_a) { create(:inbox, account: account, team: team_a) }
  let(:inbox_b) { create(:inbox, account: account, team: team_b) }
  let(:direct_inbox) { create(:inbox, account: account) }

  let(:label_global) { create(:label, account: account, title: 'global-label') }
  let(:label_team_a) { create(:label, account: account, team: team_a, title: 'team-a-label') }
  let(:label_team_b) { create(:label, account: account, team: team_b, title: 'team-b-label') }

  let(:administrator) { create(:user, :administrator, account: account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:custom_role) { create(:custom_role, account: account, permissions: ['report_manage']) }

  def scope_for(user, custom_role_for_user: nil)
    account_user = account.account_users.find_by(user: user)
    account_user.update!(custom_role: custom_role_for_user) if custom_role_for_user
    described_class.new(account: account, user: user, account_user: account_user)
  end

  describe '#unrestricted?' do
    it 'is true for an administrator' do
      expect(scope_for(administrator)).to be_unrestricted
    end

    it 'is true for an agent with the report_manage custom-role permission' do
      expect(scope_for(agent, custom_role_for_user: custom_role)).to be_unrestricted
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

  describe '#label_ids / #label_titles' do
    before do
      label_global
      label_team_a
      label_team_b
      team_a.add_members([agent.id])
    end

    it 'is nil for an unrestricted user' do
      expect(scope_for(administrator).label_ids).to be_nil
    end

    it 'returns global labels plus the labels of the agent team' do
      access_scope = scope_for(agent)

      expect(access_scope.label_ids).to contain_exactly(label_global.id, label_team_a.id)
      expect(access_scope.label_titles).to contain_exactly(label_global.title, label_team_a.title)
    end
  end

  describe '#team_ids' do
    before { team_a.add_members([agent.id]) }

    it 'is nil for an unrestricted user' do
      expect(scope_for(administrator).team_ids).to be_nil
    end

    it 'returns only the teams the agent belongs to' do
      expect(scope_for(agent).team_ids).to contain_exactly(team_a.id)
    end
  end

  describe '#agent_ids' do
    let(:teammate) { create(:user, account: account, role: :agent) }
    let(:inbox_colleague) { create(:user, account: account, role: :agent) }
    let(:stranger) { create(:user, account: account, role: :agent) }

    before do
      stranger
      team_a.add_members([agent.id, teammate.id])
      create(:inbox_member, inbox: direct_inbox, user: agent)
      create(:inbox_member, inbox: direct_inbox, user: inbox_colleague)
    end

    it 'is nil for an unrestricted user' do
      expect(scope_for(administrator).agent_ids).to be_nil
    end

    it 'includes the requesting agent themselves' do
      expect(scope_for(agent).agent_ids).to include(agent.id)
    end

    it 'includes agents who share a team' do
      expect(scope_for(agent).agent_ids).to include(teammate.id)
    end

    it 'includes agents who share an accessible inbox' do
      expect(scope_for(agent).agent_ids).to include(inbox_colleague.id)
    end

    it 'excludes agents who share neither an inbox nor a team' do
      expect(scope_for(agent).agent_ids).not_to include(stranger.id)
    end
  end

  describe '#permits_dimension?' do
    before { team_a.add_members([agent.id]) }

    it 'always permits the account dimension' do
      expect(scope_for(agent).permits_dimension?(:account, nil)).to be true
    end

    it 'permits an inbox the agent can access' do
      expect(scope_for(agent).permits_dimension?(:inbox, inbox_a.id)).to be true
    end

    it 'denies an inbox of another team' do
      expect(scope_for(agent).permits_dimension?(:inbox, inbox_b.id)).to be false
    end

    it 'denies a label of another team' do
      expect(scope_for(agent).permits_dimension?(:label, label_team_b.id)).to be false
    end

    it 'denies a team the agent is not a member of' do
      expect(scope_for(agent).permits_dimension?(:team, team_b.id)).to be false
    end

    it 'permits every dimension for an unrestricted user' do
      access_scope = scope_for(administrator)

      expect(access_scope.permits_dimension?(:inbox, inbox_b.id)).to be true
      expect(access_scope.permits_dimension?(:team, team_b.id)).to be true
    end

    it 'denies a blank id for a restricted dimension type' do
      expect(scope_for(agent).permits_dimension?(:inbox, nil)).to be false
    end
  end

  describe '#restrict' do
    it 'returns the target untouched for an unrestricted user' do
      access_scope = scope_for(administrator)

      expect(access_scope.restrict(account)).to equal(account)
    end

    it 'wraps the target so conversations/messages/reporting_events are limited to accessible inboxes' do
      team_a.add_members([agent.id])
      conversation_in_scope = create(:conversation, account: account, inbox: inbox_a)
      conversation_out_of_scope = create(:conversation, account: account, inbox: inbox_b)

      restricted_account = scope_for(agent).restrict(account)

      expect(restricted_account.conversations).to include(conversation_in_scope)
      expect(restricted_account.conversations).not_to include(conversation_out_of_scope)
    end

    it 'delegates unknown methods to the wrapped target' do
      access_scope = scope_for(agent)

      expect(access_scope.restrict(account).id).to eq(account.id)
    end
  end
end
