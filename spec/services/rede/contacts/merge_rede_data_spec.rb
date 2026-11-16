require 'rails_helper'

RSpec.describe Rede::Contacts::MergeRedeData do
  subject(:merge) { described_class.new(base_contact: base, mergee_contact: mergee).perform }

  let(:account) { create(:account) }
  let(:base) { create(:contact, account: account) }
  let(:mergee) { create(:contact, account: account) }
  let(:project) { create(:rede_project, account: account) }
  let(:other_project) { create(:rede_project, account: account) }

  def participate(contact, proj, attrs = {})
    create(:rede_participation, { account: account, contact: contact, project: proj }.merge(attrs))
  end

  context 'when only the mergee participates in a project' do
    it 'moves the participation with its assignments, evaluations and interactions' do
      participation = participate(mergee, project)
      assignment = create(:rede_assignment, account: account, participation: participation)
      evaluation = create(:rede_evaluation, account: account, contact: mergee, project: project)
      interaction = create(:rede_interaction, account: account, contact: mergee, project: project)

      merge

      expect(participation.reload.contact_id).to eq(base.id)
      expect(assignment.reload.participation_id).to eq(participation.id)
      expect(evaluation.reload.contact_id).to eq(base.id)
      expect(interaction.reload.contact_id).to eq(base.id)
    end

    it 'moves participations in every project' do
      first = participate(mergee, project)
      second = participate(mergee, other_project)

      merge

      expect([first.reload.contact_id, second.reload.contact_id]).to eq([base.id, base.id])
    end
  end

  context 'when both participate in the same project' do
    let!(:base_participation) { participate(base, project) }
    let!(:mergee_participation) { participate(mergee, project, next_step: 'Ligar na segunda') }

    it 'keeps only the base participation, completing its blank fields' do
      merge

      expect(Rede::Participation.where(project_id: project.id).pluck(:contact_id)).to eq([base.id])
      expect(base_participation.reload.next_step).to eq('Ligar na segunda')
    end

    it 'does not overwrite filled fields of the base' do
      base_participation.update!(next_step: 'Enviar material')

      merge

      expect(base_participation.reload.next_step).to eq('Enviar material')
    end

    it 'moves assignments, evaluations and interactions of the mergee to the base participation' do
      front = create(:rede_front, account: account, project: project)
      other_front = create(:rede_front, account: account, project: project)
      create(:rede_assignment, account: account, participation: base_participation, front: front)
      moved = create(:rede_assignment, account: account, participation: mergee_participation, front: other_front)
      evaluation = create(:rede_evaluation, account: account, contact: mergee, project: project, front: other_front, level: 'quente')
      interaction = create(:rede_interaction, account: account, contact: mergee, project: project)

      merge

      expect(moved.reload).to have_attributes(participation_id: base_participation.id, status: 'active')
      expect(evaluation.reload.contact_id).to eq(base.id)
      expect(interaction.reload.contact_id).to eq(base.id)
    end

    it 'keeps the base assignment and closes the mergee one on an active collision in the same front' do
      front = create(:rede_front, account: account, project: project)
      kept = create(:rede_assignment, account: account, participation: base_participation, front: front)
      collided = create(:rede_assignment, account: account, participation: mergee_participation, front: front)

      merge

      expect(kept.reload).to have_attributes(status: 'active', participation_id: base_participation.id)
      expect(collided.reload).to have_attributes(status: 'closed', participation_id: base_participation.id)
      expect(collided.ended_at).to be_present
    end

    it 'collides on assignments without front too' do
      kept = create(:rede_assignment, account: account, participation: base_participation)
      collided = create(:rede_assignment, account: account, participation: mergee_participation)

      merge

      expect([kept.reload.status, collided.reload.status]).to eq(%w[active closed])
    end

    it 'keeps both temperature lines with the most recent as the current one' do
      front = create(:rede_front, account: account, project: project)
      create(:rede_assignment, account: account, participation: base_participation, front: front)
      create(:rede_assignment, account: account, participation: mergee_participation, front: front)
      create(:rede_evaluation, account: account, contact: base, project: project, front: front, level: 'frio', evaluated_at: 3.days.ago)
      create(:rede_evaluation, account: account, contact: mergee, project: project, front: front, level: 'vapor', evaluated_at: 1.day.ago)

      merge

      lines = Rede::Evaluation.where(contact_id: base.id, project_id: project.id, front_id: front.id).order(:evaluated_at)
      expect(lines.map(&:level)).to eq(%w[frio vapor])
    end
  end

  context 'with references' do
    it 'repoints referred_by_contact_id and superior_contact_id to the base' do
      third = create(:contact, account: account)
      third_participation = participate(third, project, referred_by_contact_id: mergee.id)
      assignment = create(:rede_assignment, account: account, participation: third_participation, superior_contact_id: mergee.id)

      merge

      expect(third_participation.reload.referred_by_contact_id).to eq(base.id)
      expect(assignment.reload.superior_contact_id).to eq(base.id)
    end

    it 'does not leave a person referring to or supervised by themselves' do
      base_participation = participate(base, project)
      mergee_participation = participate(mergee, project, referred_by_contact_id: base.id)
      create(:rede_assignment, account: account, participation: mergee_participation, superior_contact_id: base.id)
      referring = participate(base, other_project, referred_by_contact_id: mergee.id)

      merge

      expect(base_participation.reload.referred_by_contact_id).to be_nil
      expect(Rede::Assignment.where(participation_id: base_participation.id).pluck(:superior_contact_id)).to eq([nil])
      expect(referring.reload.referred_by_contact_id).to be_nil
    end
  end

  it 'recomputes last_contact_at of the affected participations' do
    participation = participate(mergee, project)
    create(:rede_interaction, account: account, contact: mergee, project: project, answered: true, occurred_at: 2.hours.ago)
    participation.update_column(:last_contact_at, 10.days.ago) # rubocop:disable Rails/SkipsModelValidations

    merge

    expect(participation.reload.last_contact_at).to be_within(1.second).of(2.hours.ago)
  end

  it 'leaves no rede row pointing at the mergee' do
    participation = participate(mergee, project)
    create(:rede_assignment, account: account, participation: participation)
    create(:rede_evaluation, account: account, contact: mergee, project: project)
    create(:rede_interaction, account: account, contact: mergee, project: project)

    merge

    expect(Rede::Participation.where(contact_id: mergee.id)).to be_empty
    expect(Rede::Evaluation.where(contact_id: mergee.id)).to be_empty
    expect(Rede::Interaction.where(contact_id: mergee.id)).to be_empty
  end

  it 'does nothing when the mergee has no rede data' do
    expect { merge }.not_to raise_error
  end

  it 'recomputes last_contact_at of the base in projects where only the base participates' do
    base_participation = participate(base, project)
    inbox = create(:inbox, account: account, team_id: project.team_id)
    conversation = create(:conversation, account: account, inbox: inbox, contact: mergee,
                                         contact_inbox: create(:contact_inbox, contact: mergee, inbox: inbox))
    create(:message, account: account, conversation: conversation, inbox: inbox, message_type: :incoming, sender: mergee,
                     private: false, created_at: 1.day.ago)
    Conversation.where(id: conversation.id).update_all(contact_id: base.id) # rubocop:disable Rails/SkipsModelValidations

    merge

    expect(base_participation.reload.last_contact_at).to be_within(1.second).of(1.day.ago)
  end
end
