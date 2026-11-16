require 'rails_helper'

RSpec.describe Rede::AccessScope do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:team_a) { create(:team, account: account) }
  let(:team_b) { create(:team, account: account) }
  let!(:project_a) { team_a.rede_project }
  let!(:project_b) { team_b.rede_project }

  def scope_for(user)
    described_class.new(account: account, user: user)
  end

  it 'is unrestricted for administrators, with nil project_ids' do
    scope = scope_for(admin)

    expect(scope).to be_unrestricted
    expect(scope.project_ids).to be_nil
    expect(scope.restrict_projects(Rede::Project.where(account_id: account.id))).to contain_exactly(project_a, project_b)
    expect(scope.can_access_project?(project_b)).to be(true)
  end

  it 'limits agents to the projects of their teams' do
    create(:team_member, team: team_a, user: agent)
    scope = scope_for(agent)

    expect(scope).not_to be_unrestricted
    expect(scope.project_ids).to eq([project_a.id])
    expect(scope.restrict_projects(Rede::Project.where(account_id: account.id))).to contain_exactly(project_a)
    expect(scope.can_access_project?(project_a)).to be(true)
    expect(scope.can_access_project?(project_b)).to be(false)
  end

  it 'sees both projects for an agent in two teams' do
    create(:team_member, team: team_a, user: agent)
    create(:team_member, team: team_b, user: agent)

    expect(scope_for(agent).project_ids).to contain_exactly(project_a.id, project_b.id)
  end

  it 'gives zero projects to an agent without teams, without error' do
    scope = scope_for(agent)

    expect(scope.project_ids).to eq([])
    expect(scope.restrict_projects(Rede::Project.where(account_id: account.id))).to be_empty
  end

  it 'gives nothing to a user of another account' do
    outsider = create(:user, account: create(:account), role: :administrator)
    scope = scope_for(outsider)

    expect(scope).not_to be_unrestricted
    expect(scope.restrict_projects(Rede::Project.where(account_id: account.id))).to be_empty
    expect(scope.can_access_project?(project_a)).to be(false)
  end

  it 'ignores teams of another account for the same user' do
    other_account = create(:account)
    create(:account_user, account: other_account, user: agent, role: :agent)
    create(:team_member, team: create(:team, account: other_account), user: agent)

    expect(scope_for(agent).project_ids).to eq([])
  end

  it 'restricts participations to the accessible projects' do
    create(:team_member, team: team_a, user: agent)
    participation_a = create(:rede_participation, account: account, project: project_a)
    participation_b = create(:rede_participation, account: account, project: project_b)

    expect(scope_for(agent).restrict_participations(Rede::Participation.all)).to contain_exactly(participation_a)
    expect(scope_for(admin).restrict_participations(Rede::Participation.all)).to contain_exactly(participation_a, participation_b)
  end
end
