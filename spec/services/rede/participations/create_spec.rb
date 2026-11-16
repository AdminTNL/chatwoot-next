require 'rails_helper'

RSpec.describe Rede::Participations::Create do
  let(:account) { create(:account) }
  let(:project) { create(:team, account: account).rede_project }
  let(:front) { create(:rede_front, account: account, project: project) }
  let(:role) { account.rede_roles.find_by!(key: 'mobilizador') }

  def perform(params)
    described_class.new(account: account, project: project, params: ActionController::Parameters.new(params).permit!).perform
  end

  it 'adds an existing contact' do
    contact = create(:contact, account: account)

    participation = perform(contact_id: contact.id)

    expect(participation).to be_persisted
    expect(participation.contact).to eq(contact)
    expect(participation).to be_origin_manual
    expect(participation).to be_active
  end

  it 'creates a new contact from name and phone' do
    expect { perform(contact: { name: 'Ana', phone_number: '(81) 9 8888-7777' }) }.to change(Contact, :count).by(1)

    contact = account.contacts.last
    expect(contact.name).to eq('Ana')
    expect(contact.phone_number).to eq('+5581988887777')
    expect(project.participations.pluck(:contact_id)).to eq([contact.id])
  end

  it 'reuses the contact found by the ninth digit variant' do
    existing = create(:contact, account: account, phone_number: '+558188887777')

    expect { perform(contact: { name: 'Ana', phone_number: '81988887777' }) }.not_to change(Contact, :count)
    expect(project.participations.last.contact).to eq(existing)
  end

  it 'prefers the exact match when both variants exist' do
    create(:contact, account: account, phone_number: '+558188887777')
    exact = create(:contact, account: account, phone_number: '+5581988887777')

    expect(perform(contact: { name: 'Ana', phone_number: '81988887777' }).contact).to eq(exact)
  end

  it 'raises with the existing participation when the contact already participates' do
    contact = create(:contact, account: account)
    existing = create(:rede_participation, account: account, project: project, contact: contact)

    expect { perform(contact_id: contact.id) }.to raise_error(Rede::Participations::Create::AlreadyParticipating) { |error|
      expect(error.participation).to eq(existing)
    }
  end

  it 'raises not found for a contact of another account' do
    foreign = create(:contact, account: create(:account))

    expect { perform(contact_id: foreign.id) }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it 'rejects an invalid phone without creating a contact' do
    expect { perform(contact: { name: 'Ana', phone_number: 'abc' }) }.to raise_error(ActiveRecord::RecordInvalid)
    expect(Contact.count).to eq(0)
  end

  it 'creates the first assignment in the same transaction' do
    participation = perform(contact: { name: 'Ana', phone_number: '81988887777' },
                            assignment: { front_id: front.id, role_id: role.id })

    assignment = participation.assignments.first
    expect(assignment).to be_active
    expect(assignment.front).to eq(front)
    expect(assignment.role).to eq(role)
  end

  it 'rolls everything back when the assignment is invalid' do
    other_front = create(:rede_front, account: account)

    expect { perform(contact: { name: 'Ana', phone_number: '81988887777' }, assignment: { front_id: other_front.id }) }
      .to raise_error(ActiveRecord::RecordInvalid)
    expect(Contact.count).to eq(0)
    expect(Rede::Participation.count).to eq(0)
    expect(Rede::Assignment.count).to eq(0)
  end

  it 'rejects a closed project' do
    project.close!

    expect { perform(contact: { name: 'Ana', phone_number: '81988887777' }) }.to raise_error(ActiveRecord::RecordInvalid)
    expect(Contact.count).to eq(0)
  end
end
