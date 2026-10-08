require 'rails_helper'

RSpec.describe TeamMember do
  include ActiveJob::TestHelper

  describe 'associations' do
    it { is_expected.to belong_to(:team) }
    it { is_expected.to belong_to(:user) }
  end

  describe 'account cache invalidation' do
    let(:account) { create(:account) }
    let(:other_account) { create(:account) }
    let(:team) { create(:team, account: account) }
    let(:user) { create(:user) }

    before do
      team
      other_account
      allow(Rails.configuration.dispatcher).to receive(:dispatch)
      allow(Time).to receive(:now).and_return(Time.now + 5.seconds) # rubocop:disable Rails/TimeZone
    end

    it 'renews team, inbox and label keys when a member is added' do
      before_keys = account.cache_keys
      create(:team_member, team: team, user: user)
      after_keys = account.cache_keys

      expect(after_keys[:inbox]).not_to eq(before_keys[:inbox])
      expect(after_keys[:label]).not_to eq(before_keys[:label])
      expect(after_keys[:team]).not_to eq(before_keys[:team])
    end

    it 'dispatches a single cache invalidation event when a member is added' do
      create(:team_member, team: team, user: user)

      expect(Rails.configuration.dispatcher).to have_received(:dispatch)
        .with('account.cache_invalidated', anything, hash_including(account: account)).once
    end

    it 'renews inbox and label keys when a member is removed' do
      team_member = create(:team_member, team: team, user: user)
      before_keys = account.cache_keys
      allow(Time).to receive(:now).and_return(Time.now + 10.seconds) # rubocop:disable Rails/TimeZone
      team_member.destroy!
      after_keys = account.cache_keys

      expect(after_keys[:inbox]).not_to eq(before_keys[:inbox])
      expect(after_keys[:label]).not_to eq(before_keys[:label])
    end

    it 'does not change keys of another account' do
      before_keys = other_account.cache_keys
      create(:team_member, team: team, user: user)

      expect(other_account.cache_keys).to eq(before_keys)
    end

    it 'does not raise when the team no longer exists' do
      team_member = create(:team_member, team: team, user: user)
      Team.where(id: team.id).delete_all

      expect { team_member.destroy! }.not_to raise_error
    end
  end

  describe 'notification access cleanup' do
    let(:account) { create(:account) }
    let(:team) { create(:team, account: account) }
    let(:user) { create(:user) }

    it 'enqueues the cleanup job with account and user when a member is removed' do
      team_member = create(:team_member, team: team, user: user)

      expect { team_member.destroy! }
        .to have_enqueued_job(Notification::AccessCleanupJob).with(account.id, [user.id])
    end

    it 'does not raise when the whole team is destroyed' do
      create(:team_member, team: team, user: user)

      expect { perform_enqueued_jobs { team.destroy! } }.not_to raise_error
    end
  end

  describe 'filtered unread count invalidation' do
    let(:account) { create(:account) }
    let(:team) { create(:team, account: account) }
    let(:user) { create(:user) }
    let(:store) { Conversations::UnreadCounts::FilteredCountStore }

    before do
      account.enable_features!(:unread_count_for_filters)
    end

    it 'invalidates the user built-in filter version when team access is added' do
      expect do
        create(:team_member, team: team, user: user)
      end.to change { store.built_in_filter_version(account_id: account.id, user_id: user.id) }.by(1)
    end

    it 'invalidates the user built-in filter version when team access is removed' do
      team_member = create(:team_member, team: team, user: user)

      expect do
        team_member.destroy!
      end.to change { store.built_in_filter_version(account_id: account.id, user_id: user.id) }.by(1)
    end

    it 'invalidates the user built-in filter version when the parent team is removed' do
      create(:team_member, team: team, user: user)

      expect do
        perform_enqueued_jobs { team.destroy! }
      end.to change { store.built_in_filter_version(account_id: account.id, user_id: user.id) }.by(1)
    end

    it 'invalidates saved filter snapshots when the parent team is removed' do
      create(:conversation, account: account, team: team)

      expect do
        perform_enqueued_jobs { team.destroy! }
      end.to change { store.conversation_version(account.id) }.by(1)
    end
  end
end
