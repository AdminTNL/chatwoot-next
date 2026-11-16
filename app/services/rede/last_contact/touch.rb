# Atualização incremental do último contato (decisão 4 da spec 006): uma única query UPDATE,
# sem carregar models, que só aumenta o valor. Informe project_id ou team_id (o projeto é o 1:1 do time).
class Rede::LastContact::Touch
  def initialize(contact_id:, at:, project_id: nil, team_id: nil)
    @contact_id = contact_id
    @project_id = project_id
    @team_id = team_id
    @at = at
  end

  def perform
    scope = project_scope
    return if scope.nil? || @at.nil?

    scope.where(contact_id: @contact_id)
         .where('last_contact_at IS NULL OR last_contact_at < ?', @at)
         .update_all(["last_contact_at = GREATEST(COALESCE(last_contact_at, '-infinity'::timestamp), ?)", @at]) # rubocop:disable Rails/SkipsModelValidations
  end

  private

  def project_scope
    if @project_id.present?
      Rede::Participation.where(project_id: @project_id)
    elsif @team_id.present?
      Rede::Participation.where(project_id: Rede::Project.where(team_id: @team_id).select(:id))
    end
  end
end
