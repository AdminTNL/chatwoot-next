require 'rails_helper'

RSpec.describe Rede::Evaluation do
  let(:account) { create(:account) }
  let(:pe) { create(:team, account: account, name: 'pe').rede_project }
  let(:pa) { create(:team, account: account, name: 'pa').rede_project }
  let(:ana) { create(:contact, account: account) }
  let!(:pe_campo) { create(:rede_front, account: account, project: pe, name: 'PE Campo') }
  let!(:pe_participation) { create(:rede_participation, account: account, project: pe, contact: ana) }
  let!(:pa_participation) { create(:rede_participation, account: account, project: pa, contact: ana) }

  def build_evaluation(attrs = {})
    described_class.new({ account: account, contact: ana, project: pe, front: pe_campo, level: 'quente' }.merge(attrs))
  end

  before { create(:rede_assignment, account: account, participation: pe_participation, front: pe_campo) }

  it 'is valid in a project with fronts, with an active assignment in the front' do
    expect(build_evaluation).to be_valid
  end

  it 'defaults the dimension to temperatura and evaluated_at to now' do
    evaluation = build_evaluation
    evaluation.validate

    expect(evaluation.dimension).to eq('temperatura')
    expect(evaluation.evaluated_at).to be_within(5.seconds).of(Time.current)
  end

  it 'maps the scale to frio, morno, quente and vapor' do
    expect(described_class.levels).to eq('frio' => 0, 'morno' => 1, 'quente' => 2, 'vapor' => 3)
  end

  it 'accepts a nil level (temperature removed)' do
    expect(build_evaluation(level: nil)).to be_valid
  end

  it 'rejects an invalid level without raising' do
    evaluation = build_evaluation(level: 'fervendo')

    expect(evaluation).not_to be_valid
    expect(evaluation.errors).to include(:level)
  end

  it 'accepts only the temperatura dimension' do
    expect(build_evaluation(dimension: 'engajamento')).not_to be_valid
  end

  it 'requires the front in a project with active fronts' do
    expect(build_evaluation(front: nil)).not_to be_valid
  end

  it 'rejects a front in a project without active fronts' do
    pa_front = create(:rede_front, account: account, project: pa)
    pa_front.close!

    expect(build_evaluation(project: pa, front: pa_front)).not_to be_valid
  end

  it 'accepts a nil front in a project without fronts' do
    expect(build_evaluation(project: pa, front: nil)).to be_valid
  end

  it 'accepts a nil front in a project whose fronts are all closed' do
    pa_front = create(:rede_front, account: account, project: pa)
    pa_front.close!

    expect(build_evaluation(project: pa, front: nil)).to be_valid
  end

  it 'rejects a front of another project' do
    other = create(:rede_front, account: account, project: pa)

    expect(build_evaluation(front: other)).not_to be_valid
  end

  it 'rejects a closed front' do
    create(:rede_front, account: account, project: pe, name: 'PE Outra')
    pe_campo.close!

    expect(build_evaluation).not_to be_valid
  end

  it 'rejects a front without temperature' do
    pe_campo.update!(has_temperature: false)

    expect(build_evaluation).not_to be_valid
  end

  it 'rejects a person without an active assignment in the front' do
    digital = create(:rede_front, account: account, project: pe, name: 'PE Digital')

    expect(build_evaluation(front: digital)).not_to be_valid
  end

  it 'rejects a person whose only assignment is "frente a definir"' do
    other = create(:contact, account: account)
    participation = create(:rede_participation, account: account, project: pe, contact: other)
    create(:rede_assignment, account: account, participation: participation)

    expect(build_evaluation(contact: other)).not_to be_valid
  end

  it 'rejects a closed assignment' do
    pe_participation.assignments.first.close!

    expect(build_evaluation).not_to be_valid
  end

  it 'rejects a person without participation in the project' do
    stranger = create(:contact, account: account)

    expect(build_evaluation(contact: stranger)).not_to be_valid
  end

  it 'rejects a closed participation' do
    pa_participation.update!(status: :closed)

    expect(build_evaluation(project: pa, front: nil)).not_to be_valid
  end

  it 'rejects a contact of another account' do
    expect(build_evaluation(contact: create(:contact))).not_to be_valid
  end

  it 'uses translated messages for rejections' do
    stranger = create(:contact, account: account)
    evaluation = build_evaluation(contact: stranger)
    evaluation.validate

    expect(evaluation.errors[:contact]).to include(I18n.t('errors.rede.evaluation.not_participating'))
  end

  it 'refuses to update a saved evaluation' do
    evaluation = build_evaluation
    evaluation.save!

    expect { evaluation.update!(level: 'frio') }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end

  it 'keeps history: every change is a new row' do
    build_evaluation(evaluated_at: 2.days.ago).save!
    build_evaluation(level: 'morno').save!

    expect(described_class.where(contact_id: ana.id).count).to eq(2)
  end
end
