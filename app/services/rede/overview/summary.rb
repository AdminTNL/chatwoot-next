# Números da visão geral do CRM. Cada cartão sai de uma contagem SQL (count/group) sobre a mesma relação da lista de pessoas
# (Rede::People::Query#filtered_relation), então a regra de linhas, de temperatura e de escopo vive só na 008.
# `filters` traz, por cartão, os parâmetros da lista que reproduzem o número (o contrato entre as duas APIs).
# Unidade: a linha da lista (pessoa x projeto x frente), exceto `people_count`, que conta contatos distintos.
class Rede::Overview::Summary
  NO_CONTACT_DAYS = 7
  TEMPERATURES = %w[vapor quente morno frio].freeze
  NONE = Rede::People::Query::NONE

  def initialize(account:, user:, project_id: nil)
    @account = account
    @user = user
    @project_id = project_id.presence
  end

  # Levanta ActiveRecord::RecordNotFound para projeto inexistente, de outra conta ou fora do escopo do usuário.
  def perform
    base = query(project_params).filtered_relation
    {
      people_count: base.count('DISTINCT rede_participations.contact_id'),
      front_participations_count: query(front_participations_filter).filtered_relation.count,
      pending_front_count: query(pending_front_filter).filtered_relation.count,
      no_contact_7d_count: query(no_contact_filter).filtered_relation.count,
      by_temperature: by_temperature(base),
      filters: filters,
      recent_changes: Rede::Overview::RecentChanges.new(account: @account, project_ids: project_ids).perform
    }
  end

  private

  def project
    return @project if defined?(@project)

    @project = @project_id && access_scope.restrict_projects(@account.rede_projects).find(@project_id)
  end

  def access_scope
    @access_scope ||= Rede::AccessScope.new(account: @account, user: @user)
  end

  def project_ids
    @project_ids ||= project ? [project.id] : access_scope.restrict_projects(@account.rede_projects.active).order(:id).ids
  end

  # Projeto encerrado só entra quando pedido por id.
  def project_params
    params = { project_ids: project_ids }
    params[:include_closed] = true if project&.closed?
    params
  end

  def query(params)
    Rede::People::Query.new(account: @account, user: @user, params: params)
  end

  def front_participations_filter = project_params.merge(has_front: true)
  def pending_front_filter = project_params.merge(front_pending: true)
  def no_contact_filter = project_params.merge(no_contact_days: NO_CONTACT_DAYS)

  def by_temperature(base)
    counts = base.group(Arel.sql(Rede::People::Query::TEMPERATURE_SQL)).count
    result = TEMPERATURES.index_with { |level| counts[Rede::Evaluation.levels[level]] || 0 }
    result.merge(none: counts[nil] || 0).symbolize_keys
  end

  def filters
    {
      people: project_params,
      front_participations: front_participations_filter,
      pending_front: pending_front_filter,
      no_contact_7d: no_contact_filter,
      by_temperature: (TEMPERATURES + [NONE]).to_h { |level| [level.to_sym, project_params.merge(temperatures: [level])] }
    }
  end
end
