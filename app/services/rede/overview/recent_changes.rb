# "O que mudou esta semana": os eventos mais recentes dos últimos 7 dias nos projetos informados (já restritos pelo escopo).
# Formato dos eventos da ficha (009) com `contact: {id,name}`. Três consultas em lote (uma por tipo), sem N+1:
# temperature_change, participation_joined (participação nova) e assignment_change com action started.
class Rede::Overview::RecentChanges
  WINDOW = 7.days
  LIMIT = 10
  ACTIVE = Rede::Participation.statuses[:active]
  PREVIOUS_LEVEL_SQL = <<~SQL.squish.freeze
    (SELECT p.level FROM rede_evaluations p
     WHERE p.contact_id = rede_evaluations.contact_id AND p.project_id = rede_evaluations.project_id
       AND p.front_id IS NOT DISTINCT FROM rede_evaluations.front_id
       AND (p.evaluated_at, p.id) < (rede_evaluations.evaluated_at, rede_evaluations.id)
     ORDER BY p.evaluated_at DESC, p.id DESC LIMIT 1) AS previous_level
  SQL

  def initialize(account:, project_ids:)
    @account = account
    @project_ids = project_ids
    @since = WINDOW.ago
  end

  def perform
    return [] if @project_ids.empty?

    entries = evaluation_events + participation_events + assignment_events
    entries.sort_by { |entry| [-entry[:event][:occurred_at].to_f, entry[:event][:type], -entry[:id]] }.first(LIMIT).pluck(:event)
  end

  private

  def evaluation_events
    Rede::Evaluation.where(account_id: @account.id, project_id: @project_ids, evaluated_at: @since..)
                    .select("rede_evaluations.*, #{PREVIOUS_LEVEL_SQL}")
                    .includes(:contact, :project, :front, :author_user)
                    .order(evaluated_at: :desc, id: :desc).limit(LIMIT).map { |record| evaluation_entry(record) }
  end

  def evaluation_entry(record)
    data = { evaluation_id: record.id, from: level_name(record.attributes['previous_level']), to: record.level, note: record.note }
    header = { type: 'temperature_change', occurred_at: record.evaluated_at, front: pair(record.front), author: pair(record.author_user) }
    entry(record, record, header, data)
  end

  def participation_events
    Rede::Participation.where(account_id: @account.id, project_id: @project_ids, status: ACTIVE, joined_at: @since..)
                       .includes(:contact, :project).order(joined_at: :desc, id: :desc).limit(LIMIT).map do |record|
      entry(record, record, { type: 'participation_joined', occurred_at: record.joined_at, front: nil, author: nil },
            { participation_id: record.id, origin: record.origin })
    end
  end

  def assignment_events
    Rede::Assignment.joins(:participation)
                    .where(rede_participations: { account_id: @account.id, project_id: @project_ids, status: ACTIVE })
                    .where(started_at: @since..).includes(:front, :role, participation: [:contact, :project])
                    .order(started_at: :desc, id: :desc).limit(LIMIT).map { |record| assignment_entry(record) }
  end

  def assignment_entry(record)
    data = { assignment_id: record.id, action: 'started', role: pair(record.role), front: pair(record.front) }
    entry(record, record.participation, { type: 'assignment_change', occurred_at: record.started_at, front: pair(record.front), author: nil }, data)
  end

  # `source` tem contact e project (avaliação ou participação).
  def entry(record, source, header, data)
    project = source.project
    event = header.merge(project: { id: project.id, name: project.name, color: project.color },
                         contact: { id: source.contact.id, name: source.contact.name }, data: data)
    { id: record.id, event: event }
  end

  def pair(record)
    record && { id: record.id, name: record.name }
  end

  def level_name(value)
    value && Rede::Evaluation.levels.key(value)
  end
end
