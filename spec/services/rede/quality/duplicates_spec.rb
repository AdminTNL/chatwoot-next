require 'rails_helper'

RSpec.describe Rede::Quality::Duplicates do
  let(:account) { create(:account) }
  let(:project) { create(:rede_project, account: account) }
  let(:other_project) { create(:rede_project, account: account) }

  def person(phone, in_projects: [project], name: 'Pessoa')
    contact = create(:contact, account: account, name: name, phone_number: phone)
    in_projects.each { |proj| create(:rede_participation, account: account, contact: contact, project: proj) }
    contact
  end

  def pairs(for_project = project)
    described_class.new(project: for_project).perform.map { |pair| [pair[:contact_a].id, pair[:contact_b].id] }
  end

  it 'pairs the same number with and without the ninth digit' do
    a = person('+5581988887777')
    b = person('+558188887777')

    expect(pairs).to eq([[a.id, b.id].sort])
  end

  it 'orders the pair by contact id' do
    first = person('+558188887777')
    second = person('+5581988887777')

    expect(pairs).to eq([[first.id, second.id]])
  end

  it 'does not pair a contact with itself nor different numbers' do
    person('+5581988887777')
    person('+5581988886666')

    expect(pairs).to be_empty
  end

  it 'does not suggest pairs when one is in another project only' do
    person('+5581988887777')
    person('+558188887777', in_projects: [other_project])

    expect(pairs).to be_empty
    expect(pairs(other_project)).to be_empty
  end

  it 'only lists the pair in the projects where both participate' do
    a = person('+5581988887777', in_projects: [project, other_project])
    b = person('+558188887777', in_projects: [project, other_project])

    expect(pairs(project)).to eq([[a.id, b.id]])
    expect(pairs(other_project)).to eq([[a.id, b.id]])
  end

  it 'ignores closed participations' do
    person('+5581988887777')
    closed = person('+558188887777')
    Rede::Participation.find_by(contact_id: closed.id).update!(status: :closed)

    expect(pairs).to be_empty
  end

  it 'compares landlines only by exact number' do
    person('+558133334444')
    person('+55813333444')

    expect(pairs).to be_empty
  end

  it 'excludes dismissed pairs' do
    a = person('+5581988887777')
    b = person('+558188887777')
    Rede::QualityResolution.create!(account: account, project: project, kind: :dismissed, contact_a_id: a.id, contact_b_id: b.id)

    expect(pairs).to be_empty
  end

  it 'keeps a pair dismissed in one project in the others' do
    a = person('+5581988887777', in_projects: [project, other_project])
    b = person('+558188887777', in_projects: [project, other_project])
    Rede::QualityResolution.create!(account: account, project: project, kind: :dismissed, contact_a_id: a.id, contact_b_id: b.id)

    expect(pairs(other_project)).to eq([[a.id, b.id]])
  end

  it 'ignores participations of other projects when comparing' do
    person('+5581988887777')
    person('+558188887777', in_projects: [other_project])
    person('+5581977776666', in_projects: [other_project])

    expect(pairs).to be_empty
  end
end
