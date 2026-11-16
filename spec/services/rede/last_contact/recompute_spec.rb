require 'rails_helper'

RSpec.describe Rede::LastContact::Recompute do
  let(:account) { create(:account) }
  let(:project) { create(:team, account: account).rede_project }
  let(:other_project) { create(:team, account: account).rede_project }
  let(:contact) { create(:contact, account: account) }
  let(:author) { create(:user, account: account) }
  let!(:participation) { create(:rede_participation, account: account, project: project, contact: contact) }
  let!(:other_participation) { create(:rede_participation, account: account, project: other_project, contact: contact) }

  def conversation_in(inbox)
    create(:conversation, account: account, inbox: inbox, contact: contact,
                          contact_inbox: create(:contact_inbox, contact: contact, inbox: inbox))
  end

  def conversation_for(proj)
    conversation_in(create(:inbox, account: account, team_id: proj.team_id))
  end

  def message(conversation, at:, **attrs)
    attrs = { message_type: :incoming, sender: contact, private: false }.merge(attrs)
    create(:message, account: account, conversation: conversation, inbox: conversation.inbox, created_at: at, **attrs)
  end

  def call(proj, at:, answered: true)
    create(:rede_interaction, account: account, project: proj, contact: contact, author_user: author,
                              kind: :call, answered: answered, occurred_at: at)
  end

  def recompute(*records)
    described_class.new(records).perform
    records.each(&:reload)
  end

  # Isola o hook de criação: o valor só deve vir do Recompute.
  before { allow(Rede::LastContact::Touch).to receive(:new).and_return(instance_double(Rede::LastContact::Touch, perform: nil)) }

  it 'uses the latest incoming message when it is the greatest' do
    conversation = conversation_for(project)
    message(conversation, at: 3.days.ago)
    newest = message(conversation, at: 2.days.ago)
    call(project, at: 5.days.ago)

    recompute(participation)

    expect(participation.last_contact_at).to be_within(1.second).of(newest.created_at)
  end

  it 'uses the latest answered call when it is the greatest' do
    message(conversation_for(project), at: 5.days.ago)
    at = 1.day.ago
    call(project, at: at)

    recompute(participation)

    expect(participation.last_contact_at).to be_within(1.second).of(at)
  end

  it 'ignores outgoing, private, activity messages and unanswered calls' do
    conversation = conversation_for(project)
    message(conversation, at: 1.hour.ago, message_type: :outgoing, sender: author)
    message(conversation, at: 2.hours.ago, private: true)
    message(conversation, at: 3.hours.ago, message_type: :activity, sender: nil)
    call(project, at: 4.hours.ago, answered: false)
    create(:rede_interaction, account: account, project: project, contact: contact, author_user: author,
                              kind: :note, occurred_at: 5.hours.ago)

    recompute(participation)

    expect(participation.last_contact_at).to be_nil
  end

  it 'scopes by the project of the conversation team' do
    message(conversation_for(other_project), at: 1.hour.ago)

    recompute(participation, other_participation)

    expect(participation.last_contact_at).to be_nil
    expect(other_participation.last_contact_at).to be_present
  end

  it 'ignores conversations of inboxes without team' do
    message(conversation_in(create(:inbox, account: account)), at: 1.hour.ago)

    recompute(participation)

    expect(participation.last_contact_at).to be_nil
  end

  it 'goes back to null and to the next greatest value' do
    participation.update_columns(last_contact_at: 1.minute.ago) # rubocop:disable Rails/SkipsModelValidations
    recompute(participation)
    expect(participation.last_contact_at).to be_nil

    older = message(conversation_for(project), at: 2.days.ago)
    participation.update_columns(last_contact_at: 1.minute.ago) # rubocop:disable Rails/SkipsModelValidations
    recompute(participation)
    expect(participation.last_contact_at).to be_within(1.second).of(older.created_at)
  end

  it 'accepts a relation and runs a single query' do
    message(conversation_for(project), at: 1.hour.ago)
    queries = []
    callback = ->(*, payload) { queries << payload[:sql] unless %w[SCHEMA TRANSACTION].include?(payload[:name]) }

    ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
      described_class.new(Rede::Participation.where(account_id: account.id)).perform
    end

    expect(queries.size).to eq(1)
    expect(participation.reload.last_contact_at).to be_present
  end
end
