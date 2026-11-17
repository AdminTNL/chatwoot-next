require 'rails_helper'
# rubocop:disable RSpec/MultipleMemoizedHelpers

RSpec.describe Rede::Overview::Summary do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let!(:pe_team) { create(:team, account: account, name: 'pe') }
  let!(:pa_team) { create(:team, account: account, name: 'pa') }
  let(:pe) { pe_team.rede_project }
  let(:pa) { pa_team.rede_project }
  let!(:campo) { create(:rede_front, account: account, project: pe, name: 'Campo') }
  let!(:digital) { create(:rede_front, account: account, project: pe, name: 'Digital') }
  let(:ana) { create(:contact, account: account, name: 'Ana') }
  let(:bruna) { create(:contact, account: account, name: 'Bruna') }

  let!(:ana_pe) { create(:rede_participation, account: account, project: pe, contact: ana) }
  let!(:ana_pa) { create(:rede_participation, account: account, project: pa, contact: ana) }
  let!(:bruna_pe) { create(:rede_participation, account: account, project: pe, contact: bruna) }
  let!(:ana_campo) { create(:rede_assignment, account: account, participation: ana_pe, front: campo) }
  let!(:ana_digital) { create(:rede_assignment, account: account, participation: ana_pe, front: digital) }

  def summary(user: admin, project_id: nil)
    described_class.new(account: account, user: user, project_id: project_id).perform
  end

  def evaluate(contact, project, front, level, at: Time.current)
    create(:rede_evaluation, account: account, contact: contact, project: project, front: front, level: level, evaluated_at: at)
  end

  def list_count(user: admin, **filters)
    Rede::People::Query.new(account: account, user: user, params: filters.merge(per_page: 100)).perform.count
  end

  describe 'numbers' do
    it 'counts everything for an administrator without filter' do
      result = summary

      expect(result).to include(people_count: 2, front_participations_count: 2, pending_front_count: 1)
      expect(result[:by_temperature].values.sum).to eq(4)
    end

    it 'counts distinct people, not participations' do
      expect(summary[:people_count]).to eq(2)
      expect(list_count).to eq(4)
    end

    it 'restricts to one project' do
      result = summary(project_id: pa.id)

      expect(result).to include(people_count: 1, front_participations_count: 0, pending_front_count: 0)
      expect(result[:by_temperature].values.sum).to eq(1)
    end

    it 'shows only the projects of an agent' do
      create(:team_member, team: pe_team, user: agent)

      expect(summary(user: agent)).to include(people_count: 2, front_participations_count: 2, pending_front_count: 1)
      expect(summary(user: agent)[:by_temperature].values.sum).to eq(3)
    end

    it 'raises not found for a project outside the scope' do
      create(:team_member, team: pe_team, user: agent)

      expect { summary(user: agent, project_id: pa.id) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'raises not found for a project of another account' do
      other = create(:team, account: create(:account)).rede_project

      expect { summary(project_id: other.id) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'ignores closed projects by default and shows them when asked by id' do
      pa.close!

      expect(summary).to include(people_count: 2)
      expect(summary[:by_temperature].values.sum).to eq(3)
      expect(summary(project_id: pa.id)).to include(people_count: 1)
    end

    it 'ignores closed participations and closed assignments' do
      ana_digital.close!
      ana_pa.update!(status: :closed)

      result = summary
      expect(result).to include(people_count: 2, front_participations_count: 1)
      expect(result[:by_temperature].values.sum).to eq(2)
    end

    it 'returns zeros and no changes for an account without projects' do
      empty_account = create(:account)
      empty_admin = create(:user, account: empty_account, role: :administrator)

      result = described_class.new(account: empty_account, user: empty_admin).perform

      expect(result).to include(people_count: 0, front_participations_count: 0, pending_front_count: 0, no_contact_7d_count: 0,
                                by_temperature: { vapor: 0, quente: 0, morno: 0, frio: 0, none: 0 }, recent_changes: [])
    end

    it 'returns zeros for an agent without projects' do
      expect(summary(user: agent)).to include(people_count: 0, no_contact_7d_count: 0, recent_changes: [])
    end
  end

  describe 'no_contact_7d_count' do
    it 'counts null and older than 7 days, not recent ones' do
      ana_pe.update!(last_contact_at: 2.days.ago)
      ana_pa.update!(last_contact_at: 8.days.ago)

      # ana_pe (2 linhas) recente fora; ana_pa antiga e bruna_pe nula dentro.
      expect(summary[:no_contact_7d_count]).to eq(2)
    end
  end

  describe 'by_temperature' do
    it 'groups rows by level, with none for no temperature and for pending front' do
      evaluate(ana, pe, campo, 'vapor')
      evaluate(ana, pe, digital, 'frio')
      evaluate(ana, pa, nil, 'quente')

      expect(summary[:by_temperature]).to eq(vapor: 1, quente: 1, morno: 0, frio: 1, none: 1)
    end

    it 'uses the latest evaluation and treats a withdrawn one as none' do
      evaluate(ana, pe, campo, 'vapor', at: 2.hours.ago)
      evaluate(ana, pe, campo, nil, at: 1.hour.ago)

      expect(summary[:by_temperature]).to include(vapor: 0, none: 4)
    end
  end

  describe 'contract with the people list' do
    before do
      evaluate(ana, pe, campo, 'vapor')
      evaluate(ana, pe, digital, 'frio')
      evaluate(ana, pa, nil, 'quente')
      ana_pa.update!(last_contact_at: 1.day.ago)
      bruna_pe.update!(last_contact_at: 10.days.ago)
    end

    def contract(user: admin, project_id: nil)
      result = summary(user: user, project_id: project_id)
      expect(result[:filters].keys).to match_array(%i[people front_participations pending_front no_contact_7d by_temperature])
      result
    end

    it 'matches the list for every card as administrator' do
      result = contract
      filters = result[:filters]

      expect(list_count(**filters[:front_participations])).to eq(result[:front_participations_count])
      expect(list_count(**filters[:pending_front])).to eq(result[:pending_front_count])
      expect(list_count(**filters[:no_contact_7d])).to eq(result[:no_contact_7d_count])
      result[:by_temperature].each { |level, count| expect(list_count(**filters[:by_temperature][level])).to eq(count), "level #{level}" }
    end

    it 'matches the list for the people card by distinct contacts' do
      result = contract
      rows = Rede::People::Query.new(account: account, user: admin, params: result[:filters][:people].merge(per_page: 100)).perform.rows

      expect(rows.map { |row| row[:contact][:id] }.uniq.size).to eq(result[:people_count])
    end

    it 'matches the list for an agent and for a single project' do
      create(:team_member, team: pe_team, user: agent)
      result = contract(user: agent)

      expect(list_count(user: agent, **result[:filters][:no_contact_7d])).to eq(result[:no_contact_7d_count])
      expect(list_count(user: agent, **result[:filters][:pending_front])).to eq(result[:pending_front_count])

      by_project = contract(project_id: pa.id)
      expect(by_project[:filters][:no_contact_7d]).to include(no_contact_days: 7, project_ids: [pa.id])
      expect(list_count(**by_project[:filters][:front_participations])).to eq(by_project[:front_participations_count])
    end

    it 'keeps the contract for a closed project requested by id' do
      pa.close!
      result = contract(project_id: pa.id)

      expect(list_count(**result[:filters][:by_temperature][:none])).to eq(result[:by_temperature][:none])
      expect(list_count(**result[:filters][:by_temperature][:quente])).to eq(1)
    end

    it 'exposes the documented example of the no contact filter' do
      expect(summary[:filters][:no_contact_7d]).to eq(no_contact_days: 7, project_ids: [pe.id, pa.id].sort)
    end
  end

  describe 'recent_changes' do
    it 'lists temperature changes, new participations and started assignments with the contact' do
      ana_pe.update_columns(joined_at: 20.days.ago) # rubocop:disable Rails/SkipsModelValidations
      bruna_pe.update_columns(joined_at: 20.days.ago) # rubocop:disable Rails/SkipsModelValidations
      ana_pa.update_columns(joined_at: 1.day.ago) # rubocop:disable Rails/SkipsModelValidations
      ana_campo.update_columns(started_at: 20.days.ago) # rubocop:disable Rails/SkipsModelValidations
      ana_digital.update_columns(started_at: 2.days.ago) # rubocop:disable Rails/SkipsModelValidations
      evaluate(ana, pe, campo, 'morno', at: 3.days.ago)

      changes = summary[:recent_changes]

      expect(changes.map { |c| c[:type] }).to eq(%w[participation_joined assignment_change temperature_change])
      expect(changes.first).to include(contact: { id: ana.id, name: 'Ana' }, front: nil, author: nil)
      expect(changes.first[:project]).to eq(id: pa.id, name: pa.name, color: pa.color)
      expect(changes.second[:data]).to include(assignment_id: ana_digital.id, action: 'started', front: { id: digital.id, name: 'Digital' })
      expect(changes.third[:data]).to include(from: nil, to: 'morno', note: nil)
    end

    it 'shows from as the previous level of the same context' do
      evaluate(ana, pe, campo, 'quente', at: 5.days.ago)
      second = evaluate(ana, pe, campo, 'morno', at: 1.day.ago)
      evaluate(ana, pe, digital, 'frio', at: 12.hours.ago)

      changes = summary[:recent_changes].select { |c| c[:type] == 'temperature_change' }
      by_id = changes.index_by { |c| c[:data][:evaluation_id] }

      expect(by_id[second.id][:data]).to include(from: 'quente', to: 'morno')
      expect(changes.map { |c| c[:data][:from] }).to contain_exactly(nil, nil, 'quente')
    end

    it 'excludes events older than 7 days' do
      [ana_pe, ana_pa, bruna_pe].each { |p| p.update_columns(joined_at: 30.days.ago) } # rubocop:disable Rails/SkipsModelValidations
      [ana_campo, ana_digital].each { |a| a.update_columns(started_at: 30.days.ago) } # rubocop:disable Rails/SkipsModelValidations
      evaluate(ana, pe, campo, 'quente', at: 8.days.ago)

      expect(summary[:recent_changes]).to eq([])
    end

    it 'returns at most 10 events, newest first' do
      12.times { |i| evaluate(ana, pe, campo, i.even? ? 'quente' : 'morno', at: (i + 1).minutes.ago) }

      changes = summary[:recent_changes]
      times = changes.map { |c| c[:occurred_at] }

      expect(changes.size).to eq(10)
      expect(times).to eq(times.sort.reverse)
    end

    it 'keeps events inside the scope of an agent and of the project filter' do
      create(:team_member, team: pe_team, user: agent)
      evaluate(ana, pa, nil, 'quente')
      evaluate(ana, pe, campo, 'morno')

      agent_changes = summary(user: agent)[:recent_changes]
      expect(agent_changes.map { |c| c[:project][:id] }.uniq).to eq([pe.id])

      pa_changes = summary(project_id: pa.id)[:recent_changes]
      expect(pa_changes.map { |c| c[:project][:id] }.uniq).to eq([pa.id])
    end

    it 'does not run queries per event' do
      evaluate(ana, pe, campo, 'morno')
      summary # warm up
      baseline = count_queries { summary }
      5.times { |i| evaluate(ana, pe, digital, i.even? ? 'frio' : 'quente', at: (i + 1).minutes.ago) }

      expect(count_queries { summary }).to eq(baseline)
    end

    def count_queries(&)
      count = 0
      counter = ->(*, payload) { count += 1 unless %w[SCHEMA TRANSACTION].include?(payload[:name]) || payload[:cached] }
      ActiveSupport::Notifications.subscribed(counter, 'sql.active_record', &)
      count
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
