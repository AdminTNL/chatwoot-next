class Labels::PropagateFromContactJob < ApplicationJob
  queue_as :default

  def perform(contact_id:, team_id:, added_labels:, removed_labels:)
    Labels::ContactPropagationService.new(
      contact_id: contact_id,
      team_id: team_id,
      added_labels: added_labels,
      removed_labels: removed_labels
    ).perform
  end
end
