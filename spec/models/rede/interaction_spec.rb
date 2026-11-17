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

  describe 'last contact hook' do
    let(:touch_service) { instance_double(Rede::LastContact::Touch, perform: nil) }
    let(:recompute) { instance_double(Rede::LastContact::Recompute, perform: nil) }

    def stub_hooks
      allow(Rede::LastContact::Touch).to receive(:new).and_return(touch_service)
      allow(Rede::LastContact::Recompute).to receive(:new).and_return(recompute)
    end

    it 'touches the project with occurred_at when an answered call is created' do
      stub_hooks
      interaction = build_interaction(occurred_at: 3.hours.ago)
      interaction.save!

      expect(Rede::LastContact::Touch).to have_received(:new)
        .with(contact_id: contact.id, project_id: project.id, at: interaction.occurred_at)
      expect(touch_service).to have_received(:perform)
    end

    it 'does nothing when an unanswered call or a note is created' do
      stub_hooks
      build_interaction(answered: false).save!
      build_interaction(kind: :note, answered: nil).save!

      expect(Rede::LastContact::Touch).not_to have_received(:new)
      expect(Rede::LastContact::Recompute).not_to have_received(:new)
    end

    it 'touches when an unanswered call is edited to answered' do
      interaction = build_interaction(answered: false).tap(&:save!)
      stub_hooks

      interaction.update!(answered: true)

      expect(Rede::LastContact::Touch).to have_received(:new)
        .with(contact_id: contact.id, project_id: project.id, at: interaction.occurred_at)
      expect(Rede::LastContact::Recompute).not_to have_received(:new)
    end

    it 'recomputes the participation when an answered call is edited to unanswered' do
      interaction = build_interaction.tap(&:save!)
      stub_hooks

      interaction.update!(answered: false)

      expect(Rede::LastContact::Recompute).to have_received(:new) do |relation|
        expect(relation.to_a).to eq([participation])
      end
      expect(recompute).to have_received(:perform)
    end

    it 'recomputes when the date of an answered call changes' do
      interaction = build_interaction.tap(&:save!)
      stub_hooks

      interaction.update!(occurred_at: 5.hours.ago)

      expect(Rede::LastContact::Recompute).to have_received(:new)
    end

    it 'does nothing when only the summary is edited' do
      interaction = build_interaction.tap(&:save!)
      stub_hooks

      interaction.update!(summary: 'Outro resumo')

      expect(Rede::LastContact::Touch).not_to have_received(:new)
      expect(Rede::LastContact::Recompute).not_to have_received(:new)
    end

    it 'saves the record and logs when the hook raises' do
      allow(Rede::LastContact::Touch).to receive(:new).and_raise(StandardError, 'boom')
      allow(Rails.logger).to receive(:error)

      interaction = build_interaction
      expect { interaction.save! }.not_to raise_error

      expect(interaction).to be_persisted
      expect(Rails.logger).to have_received(:error).with(/boom/)
    end
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
