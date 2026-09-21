require 'rails_helper'

RSpec.describe Labels::PropagateJob do
  let(:conversation_id) { 1 }
  let(:added_labels) { ['quente'] }
  let(:removed_labels) { ['frio'] }

  subject(:job) do
    described_class.perform_later(
      conversation_id: conversation_id,
      added_labels: added_labels,
      removed_labels: removed_labels
    )
  end

  it 'queues the job' do
    expect { job }.to have_enqueued_job(described_class)
      .with(conversation_id: conversation_id, added_labels: added_labels, removed_labels: removed_labels)
      .on_queue('default')
  end

  it 'delegates to Labels::PropagationService' do
    service = instance_double(Labels::PropagationService, perform: true)
    allow(Labels::PropagationService).to receive(:new)
      .with(conversation_id: conversation_id, added_labels: added_labels, removed_labels: removed_labels)
      .and_return(service)

    described_class.new.perform(conversation_id: conversation_id, added_labels: added_labels, removed_labels: removed_labels)

    expect(service).to have_received(:perform)
  end
end
