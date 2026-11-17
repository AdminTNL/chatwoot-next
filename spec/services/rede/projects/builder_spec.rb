require 'rails_helper'

RSpec.describe Rede::Projects::Builder do
  let(:account) { create(:account) }

  # cria o time sem o callback, para exercitar o builder isoladamente
  def team_without_project(attrs = {})
    Team.skip_callback(:create, :after, :create_default_rede_project)
    create(:team, { account: account }.merge(attrs))
  ensure
    Team.set_callback(:create, :after, :create_default_rede_project)
  end

  it 'titleizes the team name' do
    team = team_without_project(name: 'mobiliza pará')

    expect(described_class.for_team(team).name).to eq('Mobiliza Pará')
  end

  it 'builds an accent-free slug' do
    team = team_without_project(name: 'mobiliza pará')

    expect(described_class.for_team(team).slug).to eq('mobiliza-para')
  end

  it 'adds a numeric suffix on slug collision' do
    create(:rede_project, account: account, slug: 'sao-paulo')
    create(:rede_project, account: account, slug: 'sao-paulo-2')
    team = team_without_project(name: 'são paulo')

    expect(described_class.for_team(team).slug).to eq('sao-paulo-3')
  end

  it 'uses a valid icon_color as the project color' do
    team = team_without_project(icon: 'i-lucide-star', icon_color: '#ABCDEF')

    expect(described_class.for_team(team).color).to eq('#ABCDEF')
  end

  it 'falls back to the palette when icon_color is empty' do
    team = team_without_project(icon: '🔥', icon_color: '')

    expect(described_class.for_team(team).color).to eq(Rede::Project::COLOR_PALETTE.first)
  end

  it 'falls back to the palette when icon_color is invalid' do
    team = team_without_project(icon_color: 'red')

    expect(described_class.for_team(team).color).to eq(Rede::Project::COLOR_PALETTE.first)
  end

  it 'picks the next palette color for the next project' do
    create(:rede_project, account: account)
    team = team_without_project

    expect(described_class.for_team(team).color).to eq(Rede::Project::COLOR_PALETTE.second)
  end

  it 'creates an active project linked to the team and account' do
    team = team_without_project
    project = described_class.for_team(team)

    expect(project).to be_persisted
    expect(project).to have_attributes(team_id: team.id, account_id: account.id, status: 'active')
  end
end
