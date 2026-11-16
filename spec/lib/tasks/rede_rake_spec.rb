require 'rake'
require 'rails_helper'

RSpec.describe 'rede:backfill_last_contact' do # rubocop:disable RSpec/DescribeClass
  subject(:task) { Rake::Task['rede:backfill_last_contact'] }

  let(:account) { create(:account) }
  let(:other_account) { create(:account) }
  let(:project) { create(:team, account: account).rede_project }
  let(:other_project) { create(:team, account: other_account).rede_project }
  let(:contact) { create(:contact, account: account) }
  let(:other_contact) { create(:contact, account: other_account) }
  let!(:participation) { create(:rede_participation, account: account, project: project, contact: contact) }
  let!(:other_participation) { create(:rede_participation, account: other_account, project: other_project, contact: other_contact) }

  before do
    Rails.application.load_tasks unless Rake::Task.task_defined?('rede:backfill_last_contact')
    task.reenable
    allow(Rails.logger).to receive(:info)
    allow($stdout).to receive(:puts)

    create(:rede_interaction, account: account, project: project, contact: contact, kind: :call, answered: true, occurred_at: 2.days.ago)
    # Valor antigo e errado, para provar que o backfill recalcula.
    Rede::Participation.update_all(last_contact_at: 1.year.ago) # rubocop:disable Rails/SkipsModelValidations
  end

  it 'recomputes only the given account' do
    task.invoke(account.id.to_s)

    expect(participation.reload.last_contact_at).to be_within(1.second).of(2.days.ago)
    expect(other_participation.reload.last_contact_at).to be_within(1.second).of(1.year.ago)
  end

  it 'recomputes every account without argument' do
    task.invoke

    expect(participation.reload.last_contact_at).to be_within(1.second).of(2.days.ago)
    expect(other_participation.reload.last_contact_at).to be_nil
  end

  it 'is idempotent' do
    task.invoke
    first = Rede::Participation.order(:id).pluck(:last_contact_at)
    task.reenable
    task.invoke

    expect(Rede::Participation.order(:id).pluck(:last_contact_at)).to eq(first)
  end

  it 'runs one update per batch' do
    updates = []
    callback = ->(*, payload) { updates << payload[:sql] if payload[:sql].start_with?('UPDATE "rede_participations"') }

    ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') { task.invoke }

    expect(updates.size).to eq(1)
  end
end
