require 'rails_helper'

RSpec.describe Rede::Interaction do
  let(:account) { create(:account) }
  let(:author) { create(:user, account: account) }
  let(:project) { create(:team, account: account).rede_project }
  let(:contact) { create(:contact, account: account) }
  let!(:participation) { create(:rede_participation, account: account, project: project, contact: contact) }

  def build_interaction(**attrs)
    described_class.new({ account: account, contact: contact, project: project, author_user: author, kind: :call,
                          answered: true, summary: 'Conversa', occurred_at: 1.hour.ago }.merge(attrs))
  end

  it 'is a valid answered call' do
    expect(build_interaction).to be_valid
  end

  it 'defaults occurred_at to now' do
    interaction = build_interaction(occurred_at: nil)
    interaction.validate

    expect(interaction.occurred_at).to be_within(5.seconds).of(Time.current)
  end

  it 'requires summary' do
    expect(build_interaction(summary: '')).not_to be_valid
  end

  it 'requires answered on a call' do
    interaction = build_interaction(answered: nil)

    expect(interaction).not_to be_valid
    expect(interaction.errors).to include(:answered)
  end

  it 'accepts answered false on a call' do
    expect(build_interaction(answered: false)).to be_valid
  end

  it 'stores answered as nil on a note' do
    note = build_interaction(kind: :note, answered: true)
    note.validate

    expect(note).to be_valid
    expect(note.answered).to be_nil
  end

  it 'is invalid, not an error, with an unknown kind' do
    interaction = build_interaction(kind: 'sms')

    expect(interaction).not_to be_valid
    expect(interaction.errors).to include(:kind)
  end

  it 'rejects occurred_at in the future' do
    expect(build_interaction(occurred_at: 1.hour.from_now)).not_to be_valid
  end

  it 'accepts occurred_at in the past' do
    expect(build_interaction(occurred_at: 30.days.ago)).to be_valid
  end

  it 'requires the person to participate in the project' do
    other = create(:contact, account: account)
    interaction = build_interaction(contact: other)

    expect(interaction).not_to be_valid
    expect(interaction.errors).to include(:contact)
  end

  it 'still accepts an interaction for a closed participation' do
    participation.update!(status: :closed)

    expect(build_interaction).to be_valid
  end

  it 'accepts a front of the same project' do
    front = create(:rede_front, account: account, project: project)

    expect(build_interaction(front: front)).to be_valid
  end

  it 'rejects a front of another project' do
    other_front = create(:rede_front, account: account, project: create(:team, account: account).rede_project)
    interaction = build_interaction(front: other_front)

    expect(interaction).not_to be_valid
    expect(interaction.errors).to include(:front)
  end

  it 'rejects records from another account' do
    other_project = create(:team).rede_project

    expect(build_interaction(project: other_project)).not_to be_valid
  end

  it 'calls the last contact hook on create' do
    touch = instance_double(Rede::LastContact::Touch, perform: nil)
    allow(Rede::LastContact::Touch).to receive(:new).and_return(touch)

    build_interaction.save!

    expect(touch).to have_received(:perform)
  end

  describe 'editing' do
    let!(:interaction) { build_interaction.tap(&:save!) }

    it 'allows editing summary and answered within 24 hours' do
      travel_to(23.hours.from_now) do
        expect(interaction.update(summary: 'Corrigido', answered: false)).to be(true)
      end
    end

    it 'rejects editing after 24 hours' do
      travel_to(25.hours.from_now) do
        expect(interaction.update(summary: 'Tarde')).to be(false)
        expect(interaction.errors).to include(:base)
      end
    end
  end
end
