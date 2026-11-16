require 'rails_helper'
# rubocop:disable RSpec/MultipleMemoizedHelpers

RSpec.describe Rede::People::Query do
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
  let(:ana) { create(:contact, account: account, name: 'Ana', phone_number: '+5511988998899', additional_attributes: { 'city' => 'Recife' }) }
  let(:bruna) { create(:contact, account: account, name: 'Bruna', phone_number: '+5511977771111', additional_attributes: { 'city' => 'Olinda' }) }

  let!(:ana_pe) { create(:rede_participation, account: account, project: pe, contact: ana) }
  let!(:ana_pa) { create(:rede_participation, account: account, project: pa, contact: ana) }
  let!(:bruna_pe) { create(:rede_participation, account: account, project: pe, contact: bruna) }
  let!(:ana_campo) { create(:rede_assignment, account: account, participation: ana_pe, front: campo, role: lider) }
  let!(:ana_digital) { create(:rede_assignment, account: account, participation: ana_pe, front: digital) }

  def run(user: admin, **params)
    described_class.new(account: account, user: user, params: params).perform
  end

  def keys(result)
    result.rows.map { |row| row[:row_key] }
  end

  def evaluate(contact, project, front, level)
    create(:rede_evaluation, account: account, contact: contact, project: project, front: front, level: level)
  end

  describe 'row generation' do
    it 'creates one row per active assignment and one for a participation without assignments' do
      result = run

      expect(result.count).to eq(4)
      expect(keys(result)).to contain_exactly("#{ana_pe.id}-#{ana_campo.id}", "#{ana_pe.id}-#{ana_digital.id}",
                                              "#{ana_pa.id}-none", "#{bruna_pe.id}-none")
    end

    it 'fills the row fields' do
      row = run(project_ids: [pe.id], front_ids: [campo.id]).rows.first

      expect(row).to include(participation_id: ana_pe.id, assignment_id: ana_campo.id, front_pending: false, role: { id: lider.id, name: 'Lider' },
                             front: { id: campo.id, name: 'Campo' }, responsible: nil, next_step: nil)
      expect(row[:contact]).to include(id: ana.id, name: 'Ana', phone_number: '+5511988998899', city: 'Recife')
      expect(row[:project]).to include(id: pe.id, slug: pe.slug, name: pe.name, color: pe.color, status: 'active')
    end

    it 'marks front_pending for a person without assignment in a project with fronts' do
      row = run.rows.find { |r| r[:participation_id] == bruna_pe.id }

      expect(row).to include(front: nil, role: nil, front_pending: true, temperature: nil, assignment_id: nil)
    end

    it 'does not mark front_pending in a project without fronts' do
      row = run.rows.find { |r| r[:participation_id] == ana_pa.id }

      expect(row).to include(front: nil, front_pending: false)
    end

    it 'ignores closed assignments and inactive participations' do
      ana_digital.close!
      create(:rede_participation, account: account, project: pe, contact: create(:contact, account: account), status: :closed)

      expect(run.count).to eq(3)
    end

    it 'keeps showing an active assignment in a closed front, without front_pending' do
      campo.close!
      row = run.rows.find { |r| r[:assignment_id] == ana_campo.id }

      expect(row).to include(front: { id: campo.id, name: 'Campo' }, front_pending: false)
    end

    it 'returns name null for a contact without name' do
      ana.update_columns(name: nil) # rubocop:disable Rails/SkipsModelValidations

      expect(run.rows.find { |r| r[:participation_id] == ana_pa.id }[:contact][:name]).to be_nil
    end

    it 'shows the responsible even when they left the team' do
      create(:team_member, team: pe_team, user: agent)
      bruna_pe.update!(responsible_user: agent)
      pe_team.team_members.destroy_all

      row = run.rows.find { |r| r[:participation_id] == bruna_pe.id }
      expect(row[:responsible]).to eq(id: agent.id, name: agent.name)
    end
  end

  describe 'temperature' do
    it 'uses the temperature of the front when the project has fronts' do
      evaluate(ana, pe, campo, 'quente')
      evaluate(ana, pe, digital, 'frio')

      rows = run(project_ids: [pe.id]).rows
      expect(rows.find { |r| r[:assignment_id] == ana_campo.id }[:temperature]).to eq('quente')
      expect(rows.find { |r| r[:assignment_id] == ana_digital.id }[:temperature]).to eq('frio')
    end

    it 'uses the most recent evaluation and treats a withdrawn temperature as null' do
      evaluate(ana, pe, campo, 'quente')
      create(:rede_evaluation, account: account, contact: ana, project: pe, front: campo, level: nil, evaluated_at: 1.minute.from_now)

      expect(run(front_ids: [campo.id]).rows.first[:temperature]).to be_nil
    end

    it 'uses the temperature of the project when it has no active fronts' do
      evaluate(ana, pa, nil, 'vapor')

      expect(run(project_ids: [pa.id]).rows.first[:temperature]).to eq('vapor')
    end

    it 'leaves a "front to define" row without temperature' do
      expect(run(project_ids: [pe.id]).rows.find { |r| r[:assignment_id].nil? }[:temperature]).to be_nil
    end
  end

  describe 'filters' do
    before do
      evaluate(ana, pe, campo, 'quente')
      evaluate(ana, pe, digital, 'frio')
      evaluate(ana, pa, nil, 'morno')
    end

    it 'filters by project' do
      expect(run(project_ids: [pa.id]).count).to eq(1)
    end

    it 'filters by front, accepting none' do
      expect(keys(run(front_ids: [campo.id]))).to eq(["#{ana_pe.id}-#{ana_campo.id}"])
      expect(keys(run(front_ids: ['none']))).to contain_exactly("#{ana_pa.id}-none", "#{bruna_pe.id}-none")
      expect(run(front_ids: [campo.id, 'none']).count).to eq(3)
    end

    it 'filters by temperature, accepting none' do
      expect(keys(run(temperatures: ['quente'], project_ids: [pe.id]))).to eq(["#{ana_pe.id}-#{ana_campo.id}"])
      expect(keys(run(temperatures: ['none']))).to eq(["#{bruna_pe.id}-none"])
      expect(run(temperatures: %w[frio morno]).count).to eq(2)
    end

    it 'filters by responsible, accepting none' do
      ana_pa.update!(responsible_user: admin)

      expect(keys(run(responsible_ids: [admin.id]))).to eq(["#{ana_pa.id}-none"])
      expect(run(responsible_ids: ['none']).count).to eq(3)
    end

    it 'filters by city ignoring case' do
      expect(keys(run(city: 'olinda'))).to eq(["#{bruna_pe.id}-none"])
      expect(run(city: 'RECIFE').count).to eq(3)
    end

    it 'filters by days without contact (null or older)' do
      ana_pe.update!(last_contact_at: 2.days.ago)
      ana_pa.update!(last_contact_at: 10.days.ago)

      expect(keys(run(no_contact_days: 7))).to contain_exactly("#{ana_pa.id}-none", "#{bruna_pe.id}-none")
    end

    it 'searches by name or by part of the phone' do
      expect(run(q: 'bru').count).to eq(1)
      expect(run(q: '8899').count).to eq(3)
      expect(run(q: '(11) 97777').count).to eq(1)
    end

    it 'escapes special characters in the search' do
      expect(run(q: '%').count).to eq(0)
      expect(run(q: '_').count).to eq(0)
    end

    it 'combines filters with AND' do
      expect(keys(run(project_ids: [pe.id], temperatures: ['quente'], city: 'recife', q: 'ana'))).to eq(["#{ana_pe.id}-#{ana_campo.id}"])
      expect(run(project_ids: [pa.id], temperatures: ['quente']).count).to eq(0)
    end
  end

  describe 'sort' do
    before do
      evaluate(ana, pe, campo, 'quente')
      evaluate(ana, pe, digital, 'frio')
      ana_pe.update!(last_contact_at: 3.days.ago)
      ana_pa.update!(last_contact_at: 1.day.ago)
    end

    def participation_ids(result)
      result.rows.map { |r| r[:participation_id] }
    end

    it 'sorts by last_contact_at ascending with nulls first by default, tie-broken by row_key' do
      result = run

      expect(participation_ids(result)).to eq([bruna_pe.id, ana_pe.id, ana_pe.id, ana_pa.id])
      expect(keys(result)[1..2]).to eq(["#{ana_pe.id}-#{ana_campo.id}", "#{ana_pe.id}-#{ana_digital.id}"].sort)
    end

    it 'sorts by -last_contact_at with nulls last' do
      expect(participation_ids(run(sort: '-last_contact_at'))).to eq([ana_pa.id, ana_pe.id, ana_pe.id, bruna_pe.id])
    end

    it 'sorts by name and -name' do
      expect(run(sort: 'name').rows.first[:contact][:name]).to eq('Ana')
      expect(run(sort: '-name').rows.first[:contact][:name]).to eq('Bruna')
    end

    it 'sorts by temperature with nulls last when ascending and first when descending' do
      asc = run(sort: 'temperature').rows.map { |r| r[:temperature] }
      desc = run(sort: '-temperature').rows.map { |r| r[:temperature] }

      expect(asc).to eq(['frio', 'quente', nil, nil])
      expect(desc).to eq([nil, nil, 'quente', 'frio'])
    end

    it 'falls back to the default sort for an unknown value' do
      expect(run(sort: 'drop table').rows.first[:participation_id]).to eq(bruna_pe.id)
    end
  end

  describe 'pagination' do
    it 'paginates in a stable way without repeating or skipping rows' do
      page1 = run(per_page: 2, page: 1)
      page2 = run(per_page: 2, page: 2)

      expect(page1.count).to eq(4)
      expect(page2.page).to eq(2)
      expect(page2.per_page).to eq(2)
      expect(keys(page1).size).to eq(2)
      expect(keys(page1) + keys(page2)).to eq(keys(run))
    end

    it 'defaults to 25 per page and caps at 100' do
      expect(run.per_page).to eq(25)
      expect(run(per_page: 1000).per_page).to eq(100)
      expect(run(per_page: 0).per_page).to eq(25)
      expect(run(page: -3).page).to eq(1)
    end
  end

  describe 'scope' do
    before { create(:team_member, team: pe_team, user: agent) }

    it 'limits an agent to the rows of their projects and counts only those' do
      result = run(user: agent)

      expect(result.count).to eq(3)
      expect(result.rows.map { |r| r[:project][:id] }.uniq).to eq([pe.id])
    end

    it 'silently ignores a project filter outside the scope' do
      expect(run(user: agent, project_ids: [pa.id]).count).to eq(0)
      expect(run(user: agent, project_ids: [pa.id, pe.id]).count).to eq(3)
    end

    it 'shows nothing to a user outside the account' do
      expect(run(user: create(:user)).count).to eq(0)
    end

    it 'does not leak people from other accounts' do
      other = create(:account)
      other_team = create(:team, account: other)
      create(:rede_participation, account: other, project: other_team.rede_project, contact: create(:contact, account: other))

      expect(run.count).to eq(4)
    end
  end

  describe 'include_closed' do
    before { pa.close! }

    it 'hides closed projects by default and shows them with include_closed' do
      expect(run.count).to eq(3)
      expect(run(include_closed: 'true').count).to eq(4)
    end
  end

  describe 'query count' do
    def query_count
      count = 0
      callback = lambda do |*, payload|
        count += 1 unless payload[:name] == 'SCHEMA' || payload[:sql].match?(/\A\s*(BEGIN|COMMIT|SAVEPOINT|RELEASE)/)
      end
      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') { run(per_page: 100) }
      count
    end

    def add_people(amount)
      amount.times do
        contact = create(:contact, account: account)
        participation = create(:rede_participation, account: account, project: pe, contact: contact, responsible_user: admin)
        create(:rede_assignment, account: account, participation: participation, front: campo, role: lider)
        evaluate(contact, pe, campo, 'morno')
      end
    end

    it 'does not grow with the number of people' do
      add_people(10)
      with_ten = query_count
      add_people(40)
      with_fifty = query_count

      expect(with_fifty).to eq(with_ten)
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
