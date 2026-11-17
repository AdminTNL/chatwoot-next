# Lista de pessoas do CRM: uma linha por participação ativa x atuação ativa (participação sem atuação ativa gera uma linha só).
# O escopo do usuário (Rede::AccessScope) é aplicado antes dos filtros e da contagem.
# Tudo (linhas, temperatura, filtros, ordenação) sai de uma consulta composta; só avatares e a contagem usam consultas extras, em lote.
class Rede::People::Query # rubocop:disable Metrics/ClassLength
  DEFAULT_PER_PAGE = 25
  MAX_PER_PAGE = 100
  NONE = 'none'.freeze
  ROW_KEY_SQL = "(rede_participations.id::text || '-' || COALESCE(ra.id::text, 'none'))".freeze
  HAS_ACTIVE_FRONTS_SQL = 'EXISTS (SELECT 1 FROM rede_fronts af WHERE af.project_id = rede_participations.project_id AND af.status = 0)'.freeze
  FRONT_PENDING_SQL = "(ra.front_id IS NULL AND #{HAS_ACTIVE_FRONTS_SQL})".freeze
  # Linha "frente a definir" fica sem temperatura; as demais usam a avaliação mais recente do contexto (contato, projeto, frente).
  TEMPERATURE_SQL = "(CASE WHEN #{FRONT_PENDING_SQL} THEN NULL ELSE ev.level END)".freeze
  LAST_CONTACT_SQL = 'rede_participations.last_contact_at'.freeze
  NAME_SQL = 'LOWER(contacts.name)'.freeze
  SORTS = {
    'last_contact_at' => "#{LAST_CONTACT_SQL} ASC NULLS FIRST",
    '-last_contact_at' => "#{LAST_CONTACT_SQL} DESC NULLS LAST",
    'name' => "#{NAME_SQL} ASC NULLS LAST",
    '-name' => "#{NAME_SQL} DESC NULLS FIRST",
    'temperature' => "#{TEMPERATURE_SQL} ASC NULLS LAST",
    '-temperature' => "#{TEMPERATURE_SQL} DESC NULLS FIRST"
  }.freeze
  DEFAULT_SORT = 'last_contact_at'.freeze

  Result = Struct.new(:rows, :count, :page, :per_page) # rubocop:disable Lint/StructNewOverride

  SELECT_SQL = <<~SQL.squish.freeze
    rede_participations.id AS participation_id, ra.id AS assignment_id, #{ROW_KEY_SQL} AS row_key,
    rede_participations.next_step AS next_step, rede_participations.last_contact_at AS last_contact_at,
    contacts.id AS contact_id, contacts.name AS contact_name, contacts.phone_number AS contact_phone_number,
    contacts.additional_attributes ->> 'city' AS contact_city,
    rede_projects.id AS project_id, rede_projects.slug AS project_slug, rede_projects.name AS project_name,
    rede_projects.color AS project_color, rede_projects.status AS project_status,
    rf.id AS front_id, rf.name AS front_name, rr.id AS role_id, rr.name AS role_name,
    ru.id AS responsible_id, ru.name AS responsible_name,
    #{FRONT_PENDING_SQL} AS front_pending, #{TEMPERATURE_SQL} AS temperature_level
  SQL

  JOINS_SQL = <<~SQL.squish.freeze
    INNER JOIN contacts ON contacts.id = rede_participations.contact_id
    INNER JOIN rede_projects ON rede_projects.id = rede_participations.project_id
    LEFT JOIN rede_assignments ra ON ra.participation_id = rede_participations.id AND ra.status = 0
    LEFT JOIN rede_fronts rf ON rf.id = ra.front_id
    LEFT JOIN rede_roles rr ON rr.id = ra.role_id
    LEFT JOIN users ru ON ru.id = rede_participations.responsible_user_id
    LEFT JOIN LATERAL (
      SELECT e.level FROM rede_evaluations e
      WHERE e.contact_id = rede_participations.contact_id AND e.project_id = rede_participations.project_id
        AND (e.front_id = ra.front_id OR (e.front_id IS NULL AND ra.front_id IS NULL))
      ORDER BY e.evaluated_at DESC, e.id DESC LIMIT 1
    ) ev ON TRUE
  SQL

  def initialize(account:, user:, params: {})
    @account = account
    @user = user
    @params = (params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h).with_indifferent_access
  end

  def perform
    relation = filtered(scoped_relation)
    total = relation.count
    rows = relation.reorder(Arel.sql("#{SORTS.fetch(sort)}, #{ROW_KEY_SQL} ASC"))
                   .select(SELECT_SQL).limit(per_page).offset((page - 1) * per_page).map(&:attributes)
    Result.new(build_rows(rows), total, page, per_page)
  end

  # Relação já com escopo e filtros, sem paginação nem seleção: base das contagens da visão geral (Rede::Overview::Summary).
  def filtered_relation
    filtered(scoped_relation)
  end

  def page
    @page ||= [[@params[:page].to_i, 1].max, 100_000].min
  end

  def per_page
    @per_page ||= begin
      value = @params[:per_page].to_i
      value.positive? ? [value, MAX_PER_PAGE].min : DEFAULT_PER_PAGE
    end
  end

  private

  def sort
    @sort ||= SORTS.key?(@params[:sort].to_s) ? @params[:sort].to_s : DEFAULT_SORT
  end

  def access_scope
    @access_scope ||= Rede::AccessScope.new(account: @account, user: @user)
  end

  # O escopo vem antes de qualquer filtro e da contagem.
  def scoped_relation
    relation = Rede::Participation.where(account_id: @account.id, status: :active).joins(JOINS_SQL)
    relation = relation.where(rede_projects: { status: Rede::Project.statuses[:active] }) unless include_closed?
    access_scope.restrict_participations(relation)
  end

  def include_closed? = flag?(:include_closed)

  def filtered(relation)
    relation = filter_projects(relation)
    relation = filter_fronts(relation)
    relation = filter_front_state(relation)
    relation = filter_temperatures(relation)
    relation = filter_responsibles(relation)
    relation = filter_city(relation)
    relation = filter_no_contact(relation)
    filter_search(relation)
  end

  def list(key)
    Array(@params[key]).map(&:to_s).compact_blank
  end

  # Projeto fora do escopo não dá erro: o filtro só encontra o que o escopo já permite.
  def filter_projects(relation)
    ids = list(:project_ids).grep(/\A\d+\z/).map(&:to_i)
    ids.empty? ? relation : relation.where(project_id: ids)
  end

  def filter_fronts(relation)
    with_none(relation, list(:front_ids), 'ra.front_id')
  end

  # Cartões da visão geral: `has_front` só linhas com frente; `front_pending` só linhas "frente a definir".
  def filter_front_state(relation)
    relation = relation.where.not(ra: { front_id: nil }) if flag?(:has_front)
    flag?(:front_pending) ? relation.where(FRONT_PENDING_SQL) : relation
  end

  def flag?(key) = ActiveModel::Type::Boolean.new.cast(@params[key]) || false

  def filter_responsibles(relation)
    with_none(relation, list(:responsible_ids), 'rede_participations.responsible_user_id')
  end

  def with_none(relation, values, column)
    return relation if values.empty?

    ids = values.grep(/\A\d+\z/).map(&:to_i)
    clauses = []
    clauses << "#{column} IN (:ids)" if ids.any?
    clauses << "#{column} IS NULL" if values.include?(NONE)
    return relation.none if clauses.empty?

    relation.where(clauses.join(' OR '), ids: ids)
  end

  def filter_temperatures(relation)
    values = list(:temperatures)
    return relation if values.empty?

    levels = values.filter_map { |value| Rede::Evaluation.levels[value] }
    clauses = []
    clauses << "#{TEMPERATURE_SQL} IN (:levels)" if levels.any?
    clauses << "#{TEMPERATURE_SQL} IS NULL" if values.include?(NONE)
    return relation.none if clauses.empty?

    relation.where(clauses.join(' OR '), levels: levels)
  end

  # O banco não tem a extensão unaccent: compara só sem diferenciar maiúsculas.
  def filter_city(relation)
    city = @params[:city].to_s.strip
    return relation if city.blank?

    relation.where("LOWER(contacts.additional_attributes ->> 'city') = LOWER(?)", city)
  end

  def filter_no_contact(relation)
    days = @params[:no_contact_days].to_s
    return relation unless days.match?(/\A\d+\z/)

    relation.where("#{LAST_CONTACT_SQL} IS NULL OR #{LAST_CONTACT_SQL} < ?", days.to_i.days.ago)
  end

  def filter_search(relation)
    term = @params[:q].to_s.strip
    return relation if term.blank?

    digits = term.gsub(/\D/, '')
    clauses = ['contacts.name ILIKE :name']
    clauses << "REGEXP_REPLACE(contacts.phone_number, '\\D', '', 'g') LIKE :phone" if digits.present?
    relation.where(clauses.join(' OR '),
                   name: "%#{ActiveRecord::Base.sanitize_sql_like(term)}%", phone: "%#{ActiveRecord::Base.sanitize_sql_like(digits)}%")
  end

  def build_rows(records)
    avatars = avatar_urls(records.pluck('contact_id'))
    records.map { |record| build_row(record, avatars) }
  end

  def avatar_urls(contact_ids)
    Contact.where(id: contact_ids.uniq).with_attached_avatar.to_h { |contact| [contact.id, contact.avatar_url.presence] }
  end

  def build_row(record, avatars)
    {
      row_key: record['row_key'],
      contact: contact_hash(record, avatars),
      project: project_hash(record),
      front: pair(record, 'front'),
      front_pending: record['front_pending'],
      role: pair(record, 'role'),
      temperature: record['temperature_level'] && Rede::Evaluation.levels.key(record['temperature_level']),
      responsible: pair(record, 'responsible'),
      last_contact_at: record['last_contact_at'],
      next_step: record['next_step'],
      participation_id: record['participation_id'],
      assignment_id: record['assignment_id']
    }
  end

  def contact_hash(record, avatars)
    { id: record['contact_id'], name: record['contact_name'], phone_number: record['contact_phone_number'],
      city: record['contact_city'], avatar_url: avatars[record['contact_id']] }
  end

  def project_hash(record)
    { id: record['project_id'], slug: record['project_slug'], name: record['project_name'], color: record['project_color'],
      status: Rede::Project.statuses.key(record['project_status']) }
  end

  def pair(record, prefix)
    return nil if record["#{prefix}_id"].nil?

    { id: record["#{prefix}_id"], name: record["#{prefix}_name"] }
  end
end
