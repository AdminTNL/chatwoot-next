require 'rails_helper'

RSpec.describe Rede::People::Timeline do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let!(:pe_team) { create(:team, account: account, name: 'pe') }
  let!(:pa_team) { create(:team, account: account, name: 'pa') }
  let(:pe) { pe_team.rede_project }
  let(:pa) { pa_team.rede_project }
  let(:campo) { create(:rede_front, account: account, project: pe, name: 'Campo') }
  let(:ana) { create(:contact, account: account, name: 'Ana') }
  let(:ana_pe) { create(:rede_participation, account: account, project: pe, contact: ana) }
  let(:ana_pa) { create(:rede_participation, account: account, project: pa, contact: ana) }
  let(:base) { Time.utc(2026, 5, 10, 12, 0, 0) }
  let(:campo_assignment) do
    create(:rede_assignment, account: account, participation: ana_pe, front: campo, started_at: Time.utc(2020, 1, 1))
  end

  before do
    create(:team_member, team: pe_team, user: agent)
    ana_pa
    campo_assignment
  end

  def run(user: admin, contact: ana, **params)
    described_class.new(account: account, user: user, contact: contact, params: params).perform
  end

  def types(result)
    result.events.pluck(:type)
  end

  def conversation_for(team, last_activity_at: base, contact: ana)
    inbox = create(:inbox, account: account, team_id: team&.id)
    conversation = create(:conversation, account: account, inbox: inbox, contact: contact,
                                         contact_inbox: create(:contact_inbox, contact: contact, inbox: inbox))
    conversation.update_columns(last_activity_at: last_activity_at) # rubocop:disable Rails/SkipsModelValidations
    conversation
  end

  def call_at(project, time, answered: true, **attrs)
    create(:rede_interaction, account: account, project: project, contact: ana, kind: :call, answered: answered, occurred_at: time, **attrs)
  end

  def note_at(project, time)
    create(:rede_interaction, :note, account: account, project: project, contact: ana, occurred_at: time)
  end

  def evaluate(level, time, project: pe, front: campo, note: nil)
    create(:rede_evaluation, account: account, contact: ana, project: project, front: front, level: level, evaluated_at: time, note: note)
  end

  def key_of(event)
    [event[:type], event[:data].values.first]
  end

  describe 'event shapes' do
    it 'returns one conversation entry per conversation with its data' do # rubocop:disable RSpec/MultipleExpectations
      conversation = conversation_for(pe_team, last_activity_at: base)
      3.times do |i|
        create(:message, account: account, conversation: conversation, inbox: conversation.inbox, message_type: :incoming,
                         sender: ana, created_at: base - (i + 1).hours)
      end
      create(:message, account: account, conversation: conversation, inbox: conversation.inbox, message_type: :incoming,
                       private: true, sender: ana, created_at: base)

      events = run.events
      event = events.find { |item| item[:type] == 'conversation' }

      expect(events.count { |item| item[:type] == 'conversation' }).to eq(1)
      expect(event[:occurred_at]).to be_within(1.second).of(base)
      expect(event[:project]).to eq(id: pe.id, name: pe.name, color: pe.color)
      expect(event[:front]).to be_nil
      expect(event[:author]).to be_nil
      expect(event[:data]).to include(conversation_id: conversation.id, display_id: conversation.display_id, status: 'open')
      expect(event[:data][:inbox]).to eq(id: conversation.inbox_id, name: conversation.inbox.name)
      expect(event[:data][:last_incoming_at]).to be_within(1.second).of(base - 1.hour)
    end

    it 'returns calls and notes with front and author' do
      author = create(:user, account: account)
      call = call_at(pe, base, answered: false, front: campo, author_user: author, summary: 'Sem resposta')
      note = note_at(pe, base - 1.hour)

      result = run.events

      call_event = result.find { |item| item[:type] == 'call' }
      expect(call_event[:data]).to eq(interaction_id: call.id, answered: false, summary: 'Sem resposta')
      expect(call_event[:front]).to eq(id: campo.id, name: 'Campo')
      expect(call_event[:author]).to eq(id: author.id, name: author.name)
      expect(result.find { |item| item[:type] == 'note' }[:data]).to eq(interaction_id: note.id, summary: note.summary)
    end

    it 'returns temperature changes with the previous level of the same context' do
      first = evaluate('quente', base - 3.hours, note: 'Animada')
      second = evaluate('morno', base - 2.hours)
      other_context = create(:rede_evaluation, account: account, contact: ana, project: pa, level: 'frio', evaluated_at: base - 1.hour)

      events = run.events.select { |item| item[:type] == 'temperature_change' }.index_by { |item| item[:data][:evaluation_id] }

      expect(events[first.id][:data]).to eq(evaluation_id: first.id, from: nil, to: 'quente', note: 'Animada')
      expect(events[second.id][:data]).to include(from: 'quente', to: 'morno')
      expect(events[other_context.id][:data]).to include(from: nil, to: 'frio')
      expect(events[first.id][:front]).to eq(id: campo.id, name: 'Campo')
    end

    it 'returns assignment started and closed events' do
      role = create(:rede_role, account: account, key: 'lider', name: 'Lider')
      digital = create(:rede_front, account: account, project: pe, name: 'Digital')
      assignment = create(:rede_assignment, account: account, participation: ana_pe, front: digital, role: role, started_at: base - 5.hours)
      assignment.update!(status: :closed, ended_at: base - 1.hour)

      events = run.events.select { |item| item[:data][:assignment_id] == assignment.id }

      expect(events.map { |item| item[:data][:action] }).to eq(%w[closed started])
      expect(events.first[:data]).to include(assignment_id: assignment.id, front: { id: digital.id, name: 'Digital' })
      expect(events.first[:data][:role]).to include(name: 'Lider')
      expect(events.first[:occurred_at]).to be_within(1.second).of(base - 1.hour)
    end
  end

  describe 'ordering and scope' do
    before do
      conversation_for(pe_team, last_activity_at: base)
      call_at(pe, base - 1.hour)
      call_at(pe, base - 2.hours, answered: false)
      note_at(pe, base - 3.hours)
      evaluate('quente', base - 4.hours)
      evaluate('morno', base - 5.hours)
    end

    it 'orders from newest to oldest' do
      result = run

      expect(types(result)).to eq(%w[conversation call call note temperature_change temperature_change assignment_change])
      times = result.events.pluck(:occurred_at)
      expect(times).to eq(times.sort.reverse)
    end

    it 'never returns conversations from other teams or inboxes without a team' do
      conversation_for(pa_team, last_activity_at: base)
      conversation_for(nil, last_activity_at: base)

      expect(run(user: agent).events.count { |item| item[:type] == 'conversation' }).to eq(1)
      expect(run.events.count { |item| item[:type] == 'conversation' }).to eq(2)
    end

    it 'does not leak other projects to an agent' do
      call_at(pa, base - 10.minutes)
      note_at(pa, base - 10.minutes)
      evaluate('vapor', base - 10.minutes, project: pa, front: nil)

      result = run(user: agent)

      expect(result.events.map { |item| item[:project][:id] }.uniq).to eq([pe.id])
      expect(result.events.size).to eq(7)
    end

    it 'does not return conversations of other contacts' do
      conversation_for(pe_team, contact: create(:contact, account: account))

      expect(run.events.count { |item| item[:type] == 'conversation' }).to eq(1)
    end

    it 'raises not found when the user sees no participation of the person' do
      only_pa = create(:contact, account: account)
      create(:rede_participation, account: account, project: pa, contact: only_pa)

      expect { run(user: agent, contact: only_pa) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'raises not found for a project filter outside the scope' do
      expect { run(user: agent, project_id: pa.id) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'filters by project' do
      call_at(pa, base - 10.minutes)

      expect(types(run(project_id: pa.id))).to eq(%w[call])
    end

    it 'includes the history of a closed participation' do
      ana_pe.update!(status: :closed)

      expect(run.events.size).to eq(7)
    end
  end

  describe 'filters' do
    before do
      call_at(pe, Time.utc(2026, 5, 1, 23, 30))
      call_at(pe, Time.utc(2026, 5, 2, 0, 30))
      call_at(pe, Time.utc(2026, 5, 3, 23, 59, 59))
      note_at(pe, Time.utc(2026, 5, 2, 10))
    end

    it 'cuts by from and to, inclusive, in UTC when the account has no timezone' do
      expect(types(run(from: '2026-05-02', to: '2026-05-03'))).to eq(%w[call note call])
    end

    it 'uses the account timezone for from and to' do
      account.update!(reporting_timezone: 'America/Sao_Paulo') # UTC-3: o dia 2 vai de 03:00Z do dia 2 a 02:59:59Z do dia 3

      expect(types(run(from: '2026-05-02', to: '2026-05-02'))).to eq(%w[note])
    end

    it 'filters by types' do
      expect(types(run(types: ['call']))).to eq(%w[call call call])
      expect(types(run(types: %w[note temperature_change]))).to eq(%w[note])
    end

    it 'raises on from after to' do
      expect { run(from: '2026-05-03', to: '2026-05-02') }.to raise_error(described_class::InvalidParams)
    end

    it 'raises on invalid dates and cursors' do
      expect { run(from: 'abc') }.to raise_error(described_class::InvalidParams)
      expect { run(before: 'abc') }.to raise_error(described_class::InvalidParams)
    end
  end

  describe 'cursor pagination' do
    it 'pages without repetition or loss, including ties on the same instant' do
      conversation_for(pe_team, last_activity_at: base)
      2.times { call_at(pe, base) }
      note_at(pe, base)
      2.times { |i| evaluate(%w[frio morno][i], base) }
      call_at(pe, base - 1.hour)
      note_at(pe, base - 2.hours)
      all = run(limit: 100).events

      seen = []
      cursor = nil
      loop do
        page = run(limit: 2, before: cursor)
        seen.concat(page.events)
        cursor = page.next_cursor
        break if cursor.nil?
      end

      expect(all.size).to eq(9)
      expect(seen.map { |item| key_of(item) }).to eq(all.map { |item| key_of(item) })
    end

    it 'accepts a plain ISO8601 before as a strict bound' do
      call_at(pe, base)
      older = call_at(pe, base - 1.hour)

      expect(run(before: base.iso8601, types: ['call']).events.map { |item| item[:data][:interaction_id] }).to eq([older.id])
    end

    it 'defaults the limit to 30 and caps it at 100' do
      expect(run.limit).to eq(30)
      expect(run(limit: 500).limit).to eq(100)
      expect(run(limit: 0).limit).to eq(30)
    end

    it 'has no next cursor on the last page' do
      call_at(pe, base)

      expect(run(limit: 5).next_cursor).to be_nil
    end
  end

  describe 'queries' do
    def count_queries(&)
      count = 0
      counter = ->(_n, _s, _f, _i, payload) { count += 1 unless %w[SCHEMA TRANSACTION].include?(payload[:name]) || payload[:cached] }
      ActiveSupport::Notifications.subscribed(counter, 'sql.active_record', &)
      count
    end

    def populate(times) # rubocop:disable Metrics/AbcSize
      times.times do |i|
        conversation_for(pe_team, last_activity_at: base - i.minutes)
        call_at(pe, base - i.minutes, front: campo)
        note_at(pe, base - i.minutes)
        evaluate(%w[frio morno quente][i % 3], base - i.minutes)
        create(:rede_assignment, account: account, participation: ana_pe, front: nil).close!
      end
    end

    it 'keeps the number of queries constant regardless of the number of events' do
      populate(1)
      run
      baseline = count_queries { run }
      populate(4)

      expect(count_queries { run }).to eq(baseline)
    end
  end
end
