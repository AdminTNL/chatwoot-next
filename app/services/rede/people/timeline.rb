# Histórico da pessoa no CRM: conversas, ligações, notas, mudanças de temperatura e de atuação,
# do mais novo para o mais antigo, restrito aos projetos visíveis ao usuário (Rede::AccessScope).
#
# Estratégia: uma consulta por fonte, cada uma já filtrada, ordenada e limitada a `limit + 1`, mescladas em Ruby.
# É mais simples que um UNION ALL entre tabelas de formatos diferentes e o número de consultas não depende
# da quantidade de eventos (vínculos como frente, autor e inbox entram por preload, em lote).
#
# Ordem total: occurred_at desc, depois a posição da fonte em KINDS, depois id desc. O cursor (`before`) carrega
# essa tripla ("ISO8601|fonte|id"), então eventos no mesmo instante não se repetem nem se perdem entre páginas.
# Um `before` só com ISO8601 vale como limite estrito (occurred_at < before).
#
# Filtros `from` e `to` são datas inclusivas no fuso da conta (`reporting_timezone`, UTC se vazio).
class Rede::People::Timeline
  class InvalidParams < StandardError; end

  DEFAULT_LIMIT = 30
  MAX_LIMIT = 100
  # A posição define o desempate entre eventos no mesmo instante.
  KINDS = %w[conversation call note temperature assignment_started assignment_closed].freeze
  TYPE_KINDS = {
    'conversation' => %w[conversation], 'call' => %w[call], 'note' => %w[note],
    'temperature_change' => %w[temperature], 'assignment_change' => %w[assignment_started assignment_closed]
  }.freeze
  CONVERSATION_TIME_SQL = 'COALESCE(conversations.last_activity_at, conversations.created_at)'.freeze
  PREVIOUS_LEVEL_SQL = 'rede_evaluations.*, LAG(level) OVER (PARTITION BY project_id, front_id ORDER BY evaluated_at, id) AS previous_level'.freeze

  Event = Struct.new(:kind, :id, :time, :project_id, :front, :author, :data)
  Result = Struct.new(:events, :limit, :next_cursor)

  def initialize(account:, user:, contact:, params: {})
    @account = account
    @user = user
    @contact = contact
    @params = (params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h).with_indifferent_access
  end

  def perform
    raise ActiveRecord::RecordNotFound if @contact.account_id != @account.id || visible_projects.empty?

    parse_params
    found = kinds.flat_map { |kind| send("#{kind}_events") }.sort { |a, b| compare(a, b) }
    page = found.first(limit)
    next_cursor = found.size > limit ? cursor_for(page.last) : nil
    Result.new(page.map { |event| build(event) }, limit, next_cursor)
  end

  def limit
    @limit ||= begin
      value = @params[:limit].to_i
      value.positive? ? [value, MAX_LIMIT].min : DEFAULT_LIMIT
    end
  end

  private

  # --- parâmetros e escopo ---

  def parse_params
    @from = parse_date(@params[:from])&.beginning_of_day
    @to = parse_date(@params[:to])&.end_of_day
    raise InvalidParams, I18n.t('errors.rede.timeline.invalid_range') if @from && @to && @from > @to

    @cursor = parse_cursor(@params[:before])
  end

  def zone
    @zone ||= ActiveSupport::TimeZone[@account.reporting_timezone.presence || 'UTC'] || ActiveSupport::TimeZone['UTC']
  end

  def parse_date(value)
    return nil if value.blank?

    zone.local(*Date.iso8601(value.to_s).then { |date| [date.year, date.month, date.day] })
  rescue Date::Error
    raise InvalidParams, I18n.t('errors.rede.timeline.invalid_date')
  end

  def parse_cursor(value)
    return nil if value.blank?

    time, kind, id = value.to_s.split('|')
    parsed = { time: Time.iso8601(time) }
    if kind
      raise ArgumentError unless KINDS.include?(kind) && id.to_s.match?(/\A\d+\z/)

      parsed[:kind] = kind
      parsed[:id] = id.to_i
    end
    parsed
  rescue ArgumentError
    raise InvalidParams, I18n.t('errors.rede.timeline.invalid_cursor')
  end

  def cursor_for(event)
    "#{event.time.utc.iso8601(6)}|#{event.kind}|#{event.id}"
  end

  def kinds
    selected = Array(@params[:types]).map(&:to_s).compact_blank
    return KINDS if selected.empty?

    KINDS & TYPE_KINDS.values_at(*selected).compact.flatten
  end

  def visible_participations
    @visible_participations ||= Rede::AccessScope.new(account: @account, user: @user)
                                                 .restrict_participations(Rede::Participation.where(account_id: @account.id, contact_id: @contact.id))
  end

  def visible_projects
    @visible_projects ||= begin
      projects = Rede::Project.where(account_id: @account.id, id: visible_participations.select(:project_id)).to_a
      filter_id = @params[:project_id].presence
      if filter_id
        projects = projects.select { |project| project.id.to_s == filter_id.to_s }
        raise ActiveRecord::RecordNotFound if projects.empty?
      end
      projects.index_by(&:id)
    end
  end

  def project_ids
    visible_projects.keys
  end

  # --- janela de cada fonte: período, cursor, ordem e limite ---

  def window(relation, kind, time_sql, id_sql)
    relation = relation.where("#{time_sql} >= ?", @from) if @from
    relation = relation.where("#{time_sql} <= ?", @to) if @to
    clause = cursor_clause(kind, time_sql, id_sql)
    relation = relation.where(*clause) if clause
    relation.reorder(Arel.sql("#{time_sql} DESC, #{id_sql} DESC")).limit(limit + 1)
  end

  def cursor_clause(kind, time_sql, id_sql)
    return nil unless @cursor
    return ["#{time_sql} < ?", @cursor[:time]] if @cursor[:kind].nil?

    case KINDS.index(kind) <=> KINDS.index(@cursor[:kind])
    when -1 then ["#{time_sql} < ?", @cursor[:time]]
    when 1 then ["#{time_sql} <= ?", @cursor[:time]]
    else ["#{time_sql} < ? OR (#{time_sql} = ? AND #{id_sql} < ?)", @cursor[:time], @cursor[:time], @cursor[:id]]
    end
  end

  def compare(first, second)
    (second.time <=> first.time).nonzero? || (KINDS.index(first.kind) <=> KINDS.index(second.kind)).nonzero? || (second.id <=> first.id)
  end

  # --- fontes ---

  # Só conversas do time de um projeto visível; inbox sem time ou de outro time nunca entra.
  def conversation_events # rubocop:disable Metrics/AbcSize
    team_ids = visible_projects.values.map(&:team_id)
    relation = Conversation.where(account_id: @account.id, contact_id: @contact.id, team_id: team_ids).includes(:inbox)
    conversations = window(relation, 'conversation', CONVERSATION_TIME_SQL, 'conversations.id').to_a
    incoming = last_incoming_at(conversations.map(&:id))
    projects_by_team = visible_projects.values.index_by(&:team_id)
    conversations.map do |conversation|
      data = { conversation_id: conversation.id, display_id: conversation.display_id, inbox: pair(conversation.inbox),
               status: conversation.status, last_incoming_at: incoming[conversation.id] }
      Event.new('conversation', conversation.id, conversation.last_activity_at, projects_by_team[conversation.team_id].id, nil, nil, data)
    end
  end

  def last_incoming_at(conversation_ids)
    return {} if conversation_ids.empty?

    Message.where(account_id: @account.id, conversation_id: conversation_ids, message_type: :incoming, private: false)
           .reorder(nil).group(:conversation_id).maximum(:created_at)
  end

  def call_events
    interaction_events('call') { |interaction| { interaction_id: interaction.id, answered: interaction.answered, summary: interaction.summary } }
  end

  def note_events
    interaction_events('note') { |interaction| { interaction_id: interaction.id, summary: interaction.summary } }
  end

  def interaction_events(kind)
    relation = Rede::Interaction.where(account_id: @account.id, contact_id: @contact.id, project_id: project_ids, kind: kind)
                                .includes(:front, :author_user)
    window(relation, kind, 'rede_interactions.occurred_at', 'rede_interactions.id').map do |interaction|
      Event.new(kind, interaction.id, interaction.occurred_at, interaction.project_id, pair(interaction.front),
                pair(interaction.author_user), yield(interaction))
    end
  end

  # O nível anterior vem de LAG sobre o histórico completo do contexto (projeto + frente), antes de qualquer filtro de período.
  def temperature_events
    history = Rede::Evaluation.where(account_id: @account.id, contact_id: @contact.id, project_id: project_ids)
                              .select(PREVIOUS_LEVEL_SQL)
    relation = Rede::Evaluation.from(history, :rede_evaluations).select('rede_evaluations.*').includes(:front, :author_user)
    window(relation, 'temperature', 'rede_evaluations.evaluated_at', 'rede_evaluations.id').map do |evaluation|
      data = { evaluation_id: evaluation.id, from: Rede::Evaluation.levels.key(evaluation.attributes['previous_level']),
               to: evaluation.level, note: evaluation.note }
      Event.new('temperature', evaluation.id, evaluation.evaluated_at, evaluation.project_id, pair(evaluation.front),
                pair(evaluation.author_user), data)
    end
  end

  def assignment_started_events
    assignment_events('assignment_started', 'started', 'rede_assignments.started_at', Rede::Assignment.all)
  end

  def assignment_closed_events
    assignment_events('assignment_closed', 'closed', 'rede_assignments.ended_at', Rede::Assignment.closed.where.not(ended_at: nil))
  end

  def assignment_events(kind, action, time_sql, base)
    relation = base.joins(:participation).where(rede_participations: { account_id: @account.id, contact_id: @contact.id, project_id: project_ids })
                   .includes(:front, :role, :participation)
    window(relation, kind, time_sql, 'rede_assignments.id').map do |assignment|
      data = { assignment_id: assignment.id, action: action, role: pair(assignment.role), front: pair(assignment.front) }
      time = action == 'started' ? assignment.started_at : assignment.ended_at
      Event.new(kind, assignment.id, time, assignment.participation.project_id, pair(assignment.front), nil, data)
    end
  end

  # --- saída ---

  def build(event)
    project = visible_projects.fetch(event.project_id)
    { type: public_type(event.kind), occurred_at: event.time, project: { id: project.id, name: project.name, color: project.color },
      front: event.front, author: event.author, data: event.data }
  end

  def public_type(kind)
    TYPE_KINDS.find { |_type, members| members.include?(kind) }.first
  end

  def pair(record)
    record && { id: record.id, name: record.name }
  end
end
