require 'rails_helper'
# rubocop:disable RSpec/MultipleMemoizedHelpers

RSpec.describe Rede::People::Profile do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let!(:pe_team) { create(:team, account: account, name: 'pe') }
  let!(:pa_team) { create(:team, account: account, name: 'pa') }
  let(:pe) { pe_team.rede_project }
  let(:pa) { pa_team.rede_project }
  let!(:campo) { create(:rede_front, account: account, project: pe, name: 'Campo') }
  let!(:digital) { create(:rede_front, account: account, project: pe, name: 'Digital') }
  let!(:lider) { create(:rede_role, account: account, key: 'lider', name: 'Lider') }
  let(:ana) do
    create(:contact, account: account, name: 'Ana', email: 'ana@example.com', phone_number: '+5511988998899',
                     additional_attributes: { 'city' => 'Recife' })
  end
  let(:bruna) { create(:contact, account: account, name: 'Bruna', phone_number: '+5511977771111') }
  let(:superior) { create(:contact, account: account, name: 'Chefe') }
  let!(:ana_pe) do
    create(:rede_participation, account: account, project: pe, contact: ana, responsible_user: admin, next_step: 'Ligar', origin: :import,
                                referred_by_contact: superior, last_contact_at: 2.days.ago)
  end
  let!(:ana_pa) { create(:rede_participation, account: account, project: pa, contact: ana, referred_by_text: 'Fulano') }
  let!(:bruna_pe) { create(:rede_participation, account: account, project: pe, contact: bruna) }
  let!(:ana_campo) { create(:rede_assignment, account: account, participation: ana_pe, front: campo, role: lider, superior_contact: superior) }
  let!(:ana_digital) { create(:rede_assignment, account: account, participation: ana_pe, front: digital) }

  before do
    create(:team_member, team: pe_team, user: agent)
    create(:rede_evaluation, account: account, contact: ana, project: pe, front: campo, level: 'frio')
    create(:rede_evaluation, account: account, contact: ana, project: pe, front: campo, level: 'quente')
    create(:rede_evaluation, account: account, contact: ana, project: pa, level: 'morno')
  end

  def profile(user: admin, contact: ana)
    described_class.new(account: account, user: user, contact: contact).perform
  end

  def by_project(result, project)
    result[:participations].find { |item| item[:project][:id] == project.id }
  end

  def count_queries(&)
    count = 0
    counter = ->(_n, _s, _f, _i, payload) { count += 1 unless %w[SCHEMA TRANSACTION].include?(payload[:name]) || payload[:cached] }
    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record', &)
    count
  end

  it 'returns the contact data' do
    expect(profile[:contact]).to include(id: ana.id, name: 'Ana', phone_number: '+5511988998899', email: 'ana@example.com', city: 'Recife')
    expect(profile[:contact]).to have_key(:avatar_url)
  end

  it 'returns one participation per visible project for an administrator' do
    expect(profile[:participations].map { |item| item[:project][:id] }).to contain_exactly(pe.id, pa.id)
  end

  it 'describes a project with fronts: assignments with temperature per front' do # rubocop:disable RSpec/MultipleExpectations
    item = by_project(profile, pe)

    expect(item).to include(id: ana_pe.id, status: 'active', origin: 'import', next_step: 'Ligar', front_pending: false, project_temperature: nil)
    expect(item[:project]).to include(slug: pe.slug, name: pe.name, color: pe.color, status: 'active', has_fronts: true)
    expect(item[:responsible]).to eq(id: admin.id, name: admin.name)
    expect(item[:referred_by]).to eq(contact: { id: superior.id, name: 'Chefe' }, text: nil)
    expect(item[:last_contact_at]).to be_within(1.second).of(ana_pe.last_contact_at)
    campo_item = item[:assignments].find { |assignment| assignment[:front][:id] == campo.id }
    expect(campo_item).to include(id: ana_campo.id, temperature: 'quente', superior: { id: superior.id, name: 'Chefe' })
    expect(campo_item[:role]).to include(name: 'Lider')
    digital_item = item[:assignments].find { |assignment| assignment[:front][:id] == digital.id }
    expect(digital_item).to include(temperature: nil, superior: nil)
  end

  it 'describes a project without fronts with project_temperature' do
    create(:rede_assignment, account: account, participation: ana_pa, front: nil)
    item = by_project(profile, pa)

    expect(item).to include(project_temperature: 'morno', front_pending: false, referred_by: { contact: nil, text: 'Fulano' })
    expect(item[:project][:has_fronts]).to be(false)
    expect(item[:assignments].first).to include(front: nil, temperature: 'morno')
  end

  it 'flags front_pending when the project has fronts and the person has none or an assignment without front' do
    expect(by_project(profile(contact: bruna), pe)[:front_pending]).to be(true)
    create(:rede_assignment, account: account, participation: bruna_pe, front: nil)
    expect(by_project(profile(contact: bruna), pe)[:front_pending]).to be(true)
  end

  it 'lists only active assignments' do
    ana_digital.close!

    expect(by_project(profile, pe)[:assignments].pluck(:id)).to eq([ana_campo.id])
  end

  it 'keeps a closed participation with status closed' do
    ana_pe.update!(status: :closed)

    expect(by_project(profile, pe)[:status]).to eq('closed')
  end

  it 'limits an agent to the projects of their teams' do
    result = profile(user: agent)

    expect(result[:participations].map { |item| item[:project][:id] }).to eq([pe.id])
  end

  it 'raises not found when no participation is visible to the user' do
    expect { profile(user: agent, contact: create(:contact, account: account)) }.to raise_error(ActiveRecord::RecordNotFound)
    only_pa = create(:contact, account: account)
    create(:rede_participation, account: account, project: pa, contact: only_pa)
    expect { profile(user: agent, contact: only_pa) }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it 'raises not found for a contact of another account' do
    foreign = create(:contact, account: create(:account))

    expect { profile(contact: foreign) }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it 'runs a constant number of queries regardless of the number of participations' do
    profile
    baseline = count_queries { profile }
    3.times do
      other = create(:team, account: account).rede_project
      create(:rede_participation, account: account, project: other, contact: ana)
    end

    expect(count_queries { profile }).to eq(baseline)
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
