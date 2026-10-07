require 'rails_helper'

RSpec.describe Notification::AccessCleanupJob do
  let(:account) { create(:account) }
  let(:service) { instance_double(Notifications::AccessCleanupService, perform: true) }

  it 'calls the cleanup service' do
    allow(Notifications::AccessCleanupService).to receive(:new).and_return(service)

    described_class.perform_now(account.id, [1, 2])

    expect(Notifications::AccessCleanupService).to have_received(:new).with(account: account, user_ids: [1, 2])
    expect(service).to have_received(:perform)
  end

  it 'exits silently when the account does not exist' do
    expect { described_class.perform_now(0, [1]) }.not_to raise_error
  end
end
