# Temperatura atual de um conjunto de participações, numa consulta só (DISTINCT ON).
# Devolve { [contact_id, project_id, front_id] => 'frio'|'morno'|'quente'|'vapor'|nil }.
# Contexto sem nenhuma avaliação fica fora do hash; nil quer dizer "sem temperatura" (a temperatura foi retirada).
class Rede::Evaluations::Current
  def initialize(participations)
    @participations = participations
  end

  def perform
    pairs = pairs_condition
    return {} if pairs.nil?

    rows = Rede::Evaluation.where(pairs)
                           .select('DISTINCT ON (contact_id, project_id, front_id) contact_id, project_id, front_id, level')
                           .order(Arel.sql('contact_id, project_id, front_id, evaluated_at DESC, id DESC'))
    rows.to_h { |row| [[row.contact_id, row.project_id, row.front_id], row.level] }
  end

  private

  # Com relation, vira subconsulta (uma consulta só); com array, usa os pares já carregados.
  def pairs_condition
    if @participations.is_a?(ActiveRecord::Relation)
      ['(contact_id, project_id) IN (?)', @participations.select(:contact_id, :project_id)]
    else
      pairs = @participations.map { |participation| [participation.contact_id, participation.project_id] }.uniq
      return nil if pairs.empty?

      ["(contact_id, project_id) IN (#{(['(?, ?)'] * pairs.size).join(', ')})", *pairs.flatten]
    end
  end
end
