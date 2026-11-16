require 'rails_helper'

migration_file = Dir[Rails.root.join('db/migrate/*_backfill_rede_projects.rb')].first
require migration_file if migration_file

RSpec.describe 'Backfill of rede_projects' do # rubocop:disable RSpec/DescribeClass
  let(:account) { create(:account) }

  def run_backfill
    BackfillRedeProjects.new.up
  end

  # cria times sem projeto, como existiam antes da spec 001
  def create_teams_without_project(names)
    Team.skip_callback(:create, :after, :create_default_rede_project)
    names.map { |name| create(:team, account: account, name: name) }
  ensure
    Team.set_callback(:create, :after, :create_default_rede_project)
  end

  it 'creates one project for each team without project' do
    teams = create_teams_without_project(%w[alfa beta gama])

    expect { run_backfill }.to change(Rede::Project, :count).by(3)
    expect(teams.all? { |team| team.reload.rede_project.present? }).to be(true)
  end

  it 'is idempotent' do
    create_teams_without_project(%w[alfa beta])
    run_backfill

    expect { run_backfill }.not_to change(Rede::Project, :count)
  end

  it 'does not touch teams that already have a project' do
    team = create(:team, account: account)
    slug = team.rede_project.slug

    expect { run_backfill }.not_to change(Rede::Project, :count)
    expect(team.rede_project.reload.slug).to eq(slug)
  end

  it 'respects slug collisions' do
    create_teams_without_project(['são paulo', 'sao  paulo'])
    run_backfill

    expect(Rede::Project.where(account_id: account.id).pluck(:slug)).to contain_exactly('sao-paulo', 'sao-paulo-2')
  end
end
