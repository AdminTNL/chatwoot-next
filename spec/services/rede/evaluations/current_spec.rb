require 'rails_helper'

RSpec.describe Rede::Evaluations::Current do
  let(:account) { create(:account) }
  let(:pe) { create(:team, account: account, name: 'pe').rede_project }
  let(:pa) { create(:team, account: account, name: 'pa').rede_project }
  let(:ana) { create(:contact, account: account) }
  let!(:campo) { create(:rede_front, account: account, project: pe, name: 'PE Campo') }
  let!(:digital) { create(:rede_front, account: account, project: pe, name: 'PE Digital') }
  let!(:pe_participation) { create(:rede_participation, account: account, project: pe, contact: ana) }

  before do
    create(:rede_participation, account: account, project: pa, contact: ana)
    create(:rede_assignment, account: account, participation: pe_participation, front: campo)
    create(:rede_assignment, account: account, participation: pe_participation, front: digital)
  end

  def evaluate(project, front, level, at)
    create(:rede_evaluation, account: account, contact: ana, project: project, front: front, level: level, evaluated_at: at)
  end

  def participations
    Rede::Participation.where(contact_id: ana.id)
  end

  it 'returns the most recent level of each context' do
    evaluate(pe, campo, 'quente', 2.days.ago)
    evaluate(pe, campo, 'morno', 1.day.ago)

    expect(described_class.new(participations).perform).to eq([ana.id, pe.id, campo.id] => 'morno')
  end

  it 'does not mix contexts' do
    evaluate(pe, campo, 'quente', 1.day.ago)
    evaluate(pe, digital, 'frio', 2.days.ago)
    evaluate(pa, nil, 'vapor', 3.days.ago)

    expect(described_class.new(participations).perform).to eq(
      [ana.id, pe.id, campo.id] => 'quente', [ana.id, pe.id, digital.id] => 'frio', [ana.id, pa.id, nil] => 'vapor'
    )
  end

  it 'reports a nil level as "sem temperatura"' do
    evaluate(pe, campo, 'quente', 2.days.ago)
    evaluate(pe, campo, nil, 1.day.ago)

    result = described_class.new(participations).perform

    expect(result).to have_key([ana.id, pe.id, campo.id])
    expect(result[[ana.id, pe.id, campo.id]]).to be_nil
  end

  it 'breaks ties on evaluated_at by id' do
    at = 1.day.ago
    evaluate(pe, campo, 'quente', at)
    evaluate(pe, campo, 'frio', at)

    expect(described_class.new(participations).perform[[ana.id, pe.id, campo.id]]).to eq('frio')
  end

  it 'ignores evaluations of people outside the given participations' do
    other = create(:contact, account: account)
    create(:rede_evaluation, account: account, contact: other, project: pa, level: 'quente')

    expect(described_class.new(participations).perform).to eq({})
  end

  it 'accepts an array of participations' do
    evaluate(pa, nil, 'frio', 1.day.ago)

    expect(described_class.new(participations.to_a).perform).to eq([ana.id, pa.id, nil] => 'frio')
  end

  it 'returns an empty hash for no participations' do
    expect(described_class.new(Rede::Participation.none).perform).to eq({})
  end

  it 'runs a single query for 50 participations' do
    contacts = create_list(:contact, 50, account: account)
    contacts.each { |contact| create(:rede_evaluation, account: account, contact: contact, project: pa, level: 'quente') }
    loaded = Rede::Participation.where(contact_id: contacts.map(&:id)).to_a

    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name] == 'SCHEMA' }
    result = ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') { described_class.new(loaded).perform }

    expect(count).to eq(1)
    expect(result.size).to eq(50)
  end
end
