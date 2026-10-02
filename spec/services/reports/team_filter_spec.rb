require 'rails_helper'

RSpec.describe Reports::TeamFilter do
  let(:account) { create(:account) }
  let(:team) { create(:team, account: account) }
  let(:other_team) { create(:team, account: account) }
  let(:filter) { described_class.new(account: account, team_id: team.id) }

  it 'exposes the team id' do
    expect(filter.team_id).to eq(team.id)
    expect(filter.team_ids).to eq([team.id])
  end

  context 'when the team has members, inboxes and labels' do
    let!(:member) { create(:user, account: account, role: :agent) }
    let!(:other_member) { create(:user, account: account, role: :agent) }
    let!(:inbox) { create(:inbox, account: account, team: team) }
    let!(:label) { create(:label, account: account, team: team, title: 'team-label') }

    before do
      team.add_members([member.id])
      other_team.add_members([other_member.id])
      create(:inbox, account: account, team: other_team)
      create(:label, account: account, team: other_team, title: 'other-label')
    end

    it 'returns only the ids and titles that belong to the team' do
      expect(filter.agent_ids).to eq([member.id])
      expect(filter.inbox_ids).to eq([inbox.id])
      expect(filter.label_ids).to eq([label.id])
      expect(filter.label_titles).to eq([label.title])
    end
  end

  context 'when the team has nothing' do
    it 'returns empty arrays' do
      expect(filter.agent_ids).to eq([])
      expect(filter.inbox_ids).to eq([])
      expect(filter.label_ids).to eq([])
      expect(filter.label_titles).to eq([])
    end
  end
end
