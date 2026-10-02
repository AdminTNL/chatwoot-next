require 'rails_helper'

RSpec.describe Labels::InheritFromContactJob do
  subject(:job) { described_class.perform_later(conversation_id: conversation_id) }

  let(:conversation_id) { 1 }

  it 'queues the job' do
    expect { job }.to have_enqueued_job(described_class)
      .with(conversation_id: conversation_id)
      .on_queue('default')
  end

  it 'delegates to Labels::ContactInheritanceService' do
    service = instance_double(Labels::ContactInheritanceService, perform: true)
    allow(Labels::ContactInheritanceService).to receive(:new)
      .with(conversation_id: conversation_id)
      .and_return(service)

    described_class.new.perform(conversation_id: conversation_id)

    expect(service).to have_received(:perform)
  end
end
