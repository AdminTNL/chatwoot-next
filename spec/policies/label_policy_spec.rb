require 'rails_helper'

RSpec.describe LabelPolicy, type: :policy do
  let(:account) { create(:account) }
  let(:team_a) { create(:team, account: account) }
  let(:team_b) { create(:team, account: account) }

  let(:administrator) { create(:user, :administrator, account: account) }
  let(:agent_no_team) { create(:user, account: account) }
  let(:agent_team_a) { create(:user, account: account) }
  let(:agent_both_teams) { create(:user, account: account) }

  let!(:global_label) { create(:label, account: account, title: 'global-label') }
  let!(:team_a_label) { create(:label, account: account, team: team_a, title: 'team-a-label') }
  let!(:team_b_label) { create(:label, account: account, team: team_b, title: 'team-b-label') }

  let(:administrator_context) { { user: administrator, account: account, account_user: account.account_users.find_by(user: administrator) } }
  let(:agent_no_team_context) { { user: agent_no_team, account: account, account_user: account.account_users.find_by(user: agent_no_team) } }
  let(:agent_team_a_context) { { user: agent_team_a, account: account, account_user: account.account_users.find_by(user: agent_team_a) } }
  let(:agent_both_teams_context) { { user: agent_both_teams, account: account, account_user: account.account_users.find_by(user: agent_both_teams) } }

  before do
    team_a.add_members([agent_team_a.id, agent_both_teams.id])
    team_b.add_members([agent_both_teams.id])
  end

  describe 'Scope#resolve' do
    it 'returns all labels of the account for an administrator' do
      resolved = LabelPolicy::Scope.new(administrator_context, Label.where(account: account)).resolve

      expect(resolved).to contain_exactly(global_label, team_a_label, team_b_label)
    end

    it 'returns only global labels for an agent with no team' do
      resolved = LabelPolicy::Scope.new(agent_no_team_context, Label.where(account: account)).resolve

      expect(resolved).to contain_exactly(global_label)
    end

    it 'returns global labels plus the labels of the agent team' do
      resolved = LabelPolicy::Scope.new(agent_team_a_context, Label.where(account: account)).resolve

      expect(resolved).to contain_exactly(global_label, team_a_label)
      expect(resolved).not_to include(team_b_label)
    end

    it 'returns global labels plus the labels of every team the agent belongs to' do
      resolved = LabelPolicy::Scope.new(agent_both_teams_context, Label.where(account: account)).resolve

      expect(resolved).to contain_exactly(global_label, team_a_label, team_b_label)
    end
  end
end
