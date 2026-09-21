class Api::V1::Accounts::Contacts::LabelsController < Api::V1::Accounts::Contacts::BaseController
  include LabelConcern

  def create
    previous_titles = model.label_list.dup
    super
    propagate_to_team_conversations(previous_titles)
  end

  private

  def model
    @model ||= @contact
  end

  def permitted_params
    params.permit(:team_id, labels: [])
  end

  def propagate_to_team_conversations(previous_titles)
    team_id = permitted_params[:team_id]
    return if team_id.blank?

    current_titles = model.label_list
    added = current_titles - previous_titles
    removed = previous_titles - current_titles
    return if added.blank? && removed.blank?

    Labels::PropagateFromContactJob.perform_later(
      contact_id: model.id, team_id: team_id, added_labels: added, removed_labels: removed
    )
  end
end
