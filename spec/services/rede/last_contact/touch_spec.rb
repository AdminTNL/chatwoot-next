require 'rails_helper'

RSpec.describe Rede::LastContact::Touch do
  let(:account) { create(:account) }
  let(:project) { create(:team, account: account).rede_project }
  let(:other_project) { create(:team, account: account).rede_project }
  let(:contact) { create(:contact, account: account) }
  let!(:participation) { create(:rede_participation, account: account, project: project, contact: contact) }
  let!(:other_participation) { create(:rede_participation, account: account, project: other_project, contact: contact) }

  def run_touch(**attrs)
    described_class.new(contact_id: contact.id, team_id: project.team_id, at: 1.hour.ago, **attrs).perform
  end

  it 'sets the value when it is empty (by team)' do
    at = 2.hours.ago

    run_touch(at: at)

    expect(participation.reload.last_contact_at).to be_within(1.second).of(at)
  end

  it 'sets the value by project id' do
    at = 2.hours.ago

    run_touch(team_id: nil, project_id: project.id, at: at)

    expect(participation.reload.last_contact_at).to be_within(1.second).of(at)
  end

  it 'does not touch other projects of the same person' do
    run_touch

    expect(other_participation.reload.last_contact_at).to be_nil
  end

  it 'does not touch other people of the same project' do
    other = create(:rede_participation, account: account, project: project)

    run_touch

    expect(other.reload.last_contact_at).to be_nil
  end

  it 'only increases the value' do
    recent = 1.hour.ago
    participation.update_columns(last_contact_at: recent) # rubocop:disable Rails/SkipsModelValidations

    run_touch(at: 5.days.ago)
    expect(participation.reload.last_contact_at).to be_within(1.second).of(recent)

    newer = 5.minutes.ago
    run_touch(at: newer)
    expect(participation.reload.last_contact_at).to be_within(1.second).of(newer)
  end

  it 'does nothing for a person without participation' do
    expect { run_touch(contact_id: create(:contact, account: account).id) }.not_to raise_error
  end

  it 'does nothing without project or team' do
    run_touch(team_id: nil)

    expect(participation.reload.last_contact_at).to be_nil
  end

  it 'runs a single query' do
    queries = []
    callback = ->(*, payload) { queries << payload[:sql] unless %w[SCHEMA TRANSACTION].include?(payload[:name]) }

    ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') { run_touch }

    expect(queries.size).to eq(1)
  end
end
