require 'rails_helper'

RSpec.describe Rede::Quality::Incompletes do
  let(:account) { create(:account) }
  let(:project) { create(:rede_project, account: account) }

  def participant(status: :active, **attrs)
    contact = create(:contact, { account: account, name: 'Pessoa', phone_number: '+5581988887777',
                                 additional_attributes: { 'city' => 'Recife' } }.merge(attrs))
    participation = create(:rede_participation, account: account, contact: contact, project: project, status: status)
    [contact, participation]
  end

  def items
    described_class.new(project: project).perform.map { |item| [item[:contact].id, item[:kind]] }
  end

  it 'reports a complete person as nothing' do
    participant
    expect(items).to be_empty
  end

  it 'reports missing_name' do
    contact, = participant(name: '')
    expect(items).to eq([[contact.id, 'missing_name']])
  end

  it 'reports missing_phone' do
    contact, = participant(phone_number: nil)
    expect(items).to eq([[contact.id, 'missing_phone']])
  end

  it 'reports missing_city' do
    contact, = participant(additional_attributes: {})
    expect(items).to eq([[contact.id, 'missing_city']])
  end

  it 'reports a blank city' do
    contact, = participant(additional_attributes: { 'city' => '  ' })
    expect(items).to eq([[contact.id, 'missing_city']])
  end

  it 'reports each problem as a separate item' do
    contact, = participant(name: '', phone_number: nil, additional_attributes: {})
    expect(items).to contain_exactly([contact.id, 'missing_name'], [contact.id, 'missing_phone'], [contact.id, 'missing_city'])
  end

  it 'ignores closed participations' do
    participant(name: '', status: :closed)
    expect(items).to be_empty
  end

  it 'ignores people of other projects' do
    contact = create(:contact, account: account, name: '', phone_number: '+5581988887770')
    create(:rede_participation, account: account, contact: contact, project: create(:rede_project, account: account))
    expect(items).to be_empty
  end

  describe 'pending_front' do
    let!(:front) { create(:rede_front, account: account, project: project) }

    it 'reports a person without an active assignment with a front' do
      contact, participation = participant
      create(:rede_assignment, account: account, participation: participation, front: nil)
      expect(items).to eq([[contact.id, 'pending_front']])
    end

    it 'reports a person without assignments at all' do
      contact, = participant
      expect(items).to eq([[contact.id, 'pending_front']])
    end

    it 'does not report a person with an active assignment in a front' do
      _contact, participation = participant
      create(:rede_assignment, account: account, participation: participation, front: front)
      expect(items).to be_empty
    end

    it 'reports a person whose assignment with front was closed' do
      contact, participation = participant
      create(:rede_assignment, account: account, participation: participation, front: front).close!
      expect(items).to eq([[contact.id, 'pending_front']])
    end

    it 'does not report anything when the project has no active fronts' do
      front.update!(status: :closed)
      participant
      expect(items).to be_empty
    end
  end
end
