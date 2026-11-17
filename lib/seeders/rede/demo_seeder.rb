# Seeder de dados ficticios do CRM (spec 019).
#
# Uso:  ACCOUNT_ID=1 bundle exec rake db:seed:rede_data           (RESET=true apaga so o que o seeder criou)
#
# Tudo e criado pelos models e servicos da fatia (nunca por SQL), para os callbacks rodarem.
# Nomes e telefones sao ficticios. O que o seeder cria fica identificavel:
#   - contatos com additional_attributes.seed = 'rede_demo';
#   - projetos com slug mobiliza-demo-* (e os times, caixas e frentes ligados a eles).
# Os agentes demo (agente.*@demo.local) sao reaproveitados se ja existirem e nunca sao apagados pelo RESET.
# Se ja existir um time com o nome do demo que nao seja do seeder, ele recusa com uma mensagem (nao usa sufixo).
# rubocop:disable Metrics/ClassLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/ParameterLists
# rubocop:disable Metrics/MethodLength
class Seeders::Rede::DemoSeeder
  class Refused < StandardError; end

  SEED_MARK = 'rede_demo'.freeze
  DEMO_SLUGS = %w[mobiliza-demo-pe mobiliza-demo-pa].freeze
  INBOX_NAMES = ['Mobiliza Demo PE API', 'Mobiliza Demo PA API'].freeze
  PASSWORD = 'Demo@Rede2026'.freeze
  AGENT_EMAILS = { pe: 'agente.pe@demo.local', pa: 'agente.pa@demo.local', ambos: 'agente.ambos@demo.local' }.freeze
  PROJECT_NAMES = { pe: 'Mobiliza Demo PE', pa: 'Mobiliza Demo PA' }.freeze

  FIRST_NAMES = %w[Joana Marcos Tatiane Rafael Lucia Paulo Renata Caio Sonia Davi Helena Igor Marta Nilton Olga Pedro Quiteria Ruan Sara Tiago
                   Vitor Wanda].freeze
  LAST_NAMES = %w[Almeida Barros Cardoso Duarte Farias Guedes Holanda Macedo Nogueira Pontes Queiroz Rocha].freeze
  PE_CITIES = %w[Recife Olinda Caruaru Petrolina Garanhuns Jaboatão].freeze
  PA_CITIES = %w[Belém Santarém Marabá Ananindeua].freeze
  # Dias desde a ultima mensagem recebida: mistura recentes e com mais de 7 dias sem contato.
  LAST_INCOMING_DAYS = [1, 3, 9, 20, 2, 45, 5, 14, 58, 0.5].freeze
  LEVELS = %w[frio morno quente vapor].freeze

  def initialize(account:, reset: false, out: $stdout)
    @account = account
    @reset = reset
    @out = out
    @rng = Random.new(42)
    @contacts = {}
    @participations = {}
    @conversation_count = 0
  end

  def perform!
    ensure_allowed!

    ActiveRecord::Base.transaction do
      reset! if @reset
      ensure_free!
      create_agents
      create_projects
      create_people
      create_conversations
      create_evaluations
      create_interactions
      recompute_last_contact
    end
    print_summary
  end

  private

  # --- travas ---

  # A trava exige exatamente 'true' de proposito: qualquer outro valor ('1', 'yes', vazio) recusa em producao.
  def ensure_allowed!
    return unless Rails.env.production? && ENV['ENABLE_ACCOUNT_SEEDING'] != 'true'

    raise Refused, 'Recusado: em producao o seeder so roda com ENABLE_ACCOUNT_SEEDING=true.'
  end

  def ensure_free!
    if demo_projects.exists?
      unless seeder_signal?
        raise Refused, "A conta #{@account.id} ja tem um projeto #{DEMO_SLUGS.join(' ou ')} que nao foi criado pelo seeder " \
                       '(sem caixa nem contatos marcados). Nada foi alterado; renomeie ou resolva esse projeto manualmente.'
      end

      raise Refused, "A conta #{@account.id} ja tem o projeto #{DEMO_SLUGS.first}. Nada foi alterado. " \
                     'Use RESET=true para apagar so os dados do seeder e recriar.'
    end

    taken = @account.teams.where(name: PROJECT_NAMES.values.map(&:downcase)).pluck(:name)
    return if taken.empty?

    raise Refused, "Ja existe um time com o nome #{taken.join(', ')} que nao e do seeder. Renomeie ou apague esse time antes de rodar."
  end

  # --- reset (so o que o seeder marcou) ---

  def demo_projects
    @account.rede_projects.where(slug: DEMO_SLUGS)
  end

  # Caixas criadas pelo seeder: API, nome dado por ele, no time de um projeto demo.
  def demo_inboxes
    @account.inboxes.where(team_id: demo_projects.select(:team_id), channel_type: 'Channel::Api', name: INBOX_NAMES)
  end

  # So apaga projeto demo se houver sinal de que o seeder o criou.
  def seeder_signal?
    demo_contacts.exists? || demo_inboxes.exists?
  end

  def demo_contacts
    @account.contacts.where("additional_attributes->>'seed' = ?", SEED_MARK)
  end

  def reset!
    return unless seeder_signal?

    team_ids = demo_projects.pluck(:team_id)
    contact_ids = demo_contacts.ids
    inbox_ids = demo_inboxes.ids

    # Conversas: so as dos contatos marcados. Conversa de contato real, mesmo numa caixa demo, nunca e apagada.
    conversations = @account.conversations.where(contact_id: contact_ids)
    Message.where(conversation_id: conversations.select(:id)).destroy_all # a conversa apaga as mensagens de forma assincrona
    conversations.find_each(&:destroy!)
    ContactInbox.where(contact_id: contact_ids).destroy_all
    TeamMember.where(team_id: team_ids).destroy_all
    @account.teams.where(id: team_ids).find_each(&:destroy!) # leva o projeto, frentes, participacoes, temperaturas e interacoes
    # Caixa com conversa de contato real fica (so perde o time); as demais saem.
    @account.inboxes.where(id: inbox_ids).where.not(id: Conversation.where(account_id: @account.id).select(:inbox_id)).find_each(&:destroy!)
    Contact.where(id: contact_ids).find_each(&:destroy!)
  end

  # --- agentes, projetos e caixas ---

  def create_agents
    @agents = AGENT_EMAILS.transform_values { |email| find_or_create_agent(email) }
  end

  def find_or_create_agent(email)
    user = User.from_email(email) || User.create!(
      name: "Agente Demo #{email.split('@').first.split('.').last.upcase}", email: email,
      password: PASSWORD, password_confirmation: PASSWORD, confirmed_at: Time.current
    )
    AccountUser.find_or_create_by!(account: @account, user: user) { |account_user| account_user.role = :agent }
    user
  end

  def create_projects
    @pe = create_project(:pe, [@agents[:pe], @agents[:ambos]])
    @pa = create_project(:pa, [@agents[:pa], @agents[:ambos]])
    @fronts = {
      campo: create_front(@pe, 'Campo', true),
      digital: create_front(@pe, 'Digital', true),
      formacao: create_front(@pe, 'Formação', false)
    }
    @roles = @account.rede_roles.index_by(&:key)
  end

  def create_project(key, members)
    team = @account.teams.create!(name: PROJECT_NAMES[key])
    members.each { |user| TeamMember.find_or_create_by!(team: team, user: user) }
    project = team.rede_project
    project.update!(name: PROJECT_NAMES[key])
    channel = Channel::Api.create!(account: @account)
    inbox = @account.inboxes.create!(name: "#{PROJECT_NAMES[key]} API", channel: channel, team_id: team.id)
    (@inboxes ||= {})[project.id] = inbox
    project
  end

  def create_front(project, name, has_temperature)
    project.fronts.create!(account: @account, name: name, has_temperature: has_temperature)
  end

  # --- pessoas ---

  def person(key, name, phone, city)
    attrs = { 'seed' => SEED_MARK }
    attrs['city'] = city if city
    @contacts[key] = @account.contacts.create!(name: name, phone_number: phone, additional_attributes: attrs)
  end

  def create_people
    create_key_cases
    create_generic_pe
    create_generic_pa
  end

  def create_key_cases
    person(:ana, 'Ana Beatriz Moura', '+5581988100001', 'Recife')
    person(:carla, 'Carla Menezes', '+5581988100002', 'Olinda')
    person(:bruno_a, 'Bruno Lima', '+5581987650001', 'Caruaru')
    person(:bruno_b, 'Bruno Lima Neto', '+558187650001', 'Caruaru') # mesmo número sem o nono dígito
    person(:diego, 'Diego Fontes', '+5581988100003', 'Petrolina')
    person(:elisa, 'Elisa Cavalcanti', '+5581988100004', 'Garanhuns')
    person(:fabio, 'Fábio Tenório', '+5581988100005', nil)
    person(:sem_nome, '', '+5581988100006', nil)
    person(:gabi_pe, 'Gabriela Torres', '+5591988770001', 'Belém') # mesmo número normalizado, projetos diferentes
    person(:gabi_pa, 'Gabriela Torres', '+559188770001', 'Belém')

    join(:carla, @pe, front: :campo, role: 'coordenador', responsible: @agents[:pe], next_step: 'Fechar o calendário do mês')
    join(:ana, @pe, front: :campo, role: 'ponto_focal', superior: :carla, responsible: @agents[:ambos], referred_by: :carla,
                    next_step: 'Confirmar agenda do mutirão')
    add_assignment(:ana, @pe, front: :digital, role: 'mobilizador', superior: :carla)
    join(:ana, @pa, role: 'mobilizador', responsible: @agents[:ambos])
    join(:bruno_a, @pe, front: :campo, role: 'mobilizador', superior: :ana, responsible: @agents[:pe])
    join(:bruno_b, @pe, front: :campo, role: 'mobilizador', superior: :ana, referred_text: 'Indicado em reunião de bairro')
    join(:diego, @pe, referred_text: 'Indicado em evento')
    join(:elisa, @pe, front: :formacao, role: 'entrevistador', responsible: @agents[:pe])
    join(:fabio, @pe, front: :digital, role: 'mobilizador')
    join(:sem_nome, @pe, front: :campo, role: 'entrevistador')
    join(:gabi_pe, @pe, front: :digital, role: 'ponto_focal', superior: :carla)
    join(:gabi_pa, @pa, role: 'ponto_focal', responsible: @agents[:pa])
  end

  def create_generic_pe
    fronts = [:campo, :digital, :formacao, nil]
    12.times do |i|
      key = :"pe_#{i}"
      person(key, generic_name, format('+55819%08d', 81_000_000 + i), (i % 5 == 4 ? nil : PE_CITIES[i % PE_CITIES.size]))
      front = fronts[i % fronts.size]
      join(key, @pe, front: front, role: front && %w[mobilizador entrevistador ponto_focal][i % 3],
                     superior: (front == :campo ? :ana : nil), responsible: (i.even? ? @agents[:pe] : nil),
                     referred_by: (i == 2 ? :ana : nil), referred_text: (i == 3 ? 'Indicada por liderança local' : nil))
    end
  end

  def create_generic_pa
    9.times do |i|
      key = :"pa_#{i}"
      person(key, generic_name, format('+55919%08d', 82_000_000 + i), (i % 4 == 3 ? nil : PA_CITIES[i % PA_CITIES.size]))
      join(key, @pa, role: %w[mobilizador entrevistador ponto_focal][i % 3], superior: (i.zero? ? nil : :gabi_pa),
                     responsible: (i.even? ? @agents[:pa] : nil), referred_by: (i == 1 ? :ana : nil))
    end
  end

  def generic_name
    "#{FIRST_NAMES[@rng.rand(FIRST_NAMES.size)]} #{LAST_NAMES[@rng.rand(LAST_NAMES.size)]}"
  end

  # --- participacoes e atuacoes (pelo servico da fatia) ---

  def join(key, project, front: nil, role: nil, superior: nil, responsible: nil, referred_by: nil, referred_text: nil, next_step: nil)
    params = { contact_id: @contacts.fetch(key).id }
    if front || role || superior
      params[:assignment] = { front_id: (front && @fronts.fetch(front).id), role_id: (role && @roles.fetch(role).id),
                              superior_contact_id: (superior && @contacts.fetch(superior).id) }
    end
    participation = ::Rede::Participations::Create.new(account: @account, project: project, params: params).perform
    participation.update!(responsible_user: responsible, next_step: next_step, referred_by_text: referred_text,
                          referred_by_contact: (referred_by && @contacts.fetch(referred_by)),
                          joined_at: @rng.rand(10..90).days.ago)
    @participations[[key, project.id]] = participation
  end

  def add_assignment(key, project, front:, role:, superior: nil)
    @participations.fetch([key, project.id]).assignments.create!(
      account: @account, front: @fronts.fetch(front), role: @roles.fetch(role), superior_contact: (superior && @contacts.fetch(superior))
    )
  end

  # --- conversas e mensagens ---

  def create_conversations
    @participations.each_value.with_index do |participation, index|
      next if (index % 4) == 3 # uma parte das pessoas nunca falou com o time

      create_conversation(participation, LAST_INCOMING_DAYS[index % LAST_INCOMING_DAYS.size])
    end
  end

  def create_conversation(participation, last_incoming_days)
    inbox = @inboxes.fetch(participation.project_id)
    contact = participation.contact
    agent = participation.project_id == @pe.id ? @agents[:pe] : @agents[:pa]
    contact_inbox = ContactInbox.create!(contact: contact, inbox: inbox, source_id: SecureRandom.uuid)
    started = [last_incoming_days + @rng.rand(0..5), 59].min.days.ago
    conversation = @account.conversations.create!(inbox: inbox, contact: contact, contact_inbox: contact_inbox, created_at: started)
    @conversation_count += 1

    add_message(conversation, contact, :incoming, 'Oi, tudo bem? Quero saber da próxima atividade.', started)
    add_message(conversation, agent, :outgoing, 'Olá! Passo o calendário ainda hoje.', started + 2.hours)
    add_message(conversation, contact, :incoming, 'Combinado, aguardo.', last_incoming_days.days.ago)
    if last_incoming_days >= 1
      add_message(conversation, agent, :outgoing, 'Enviado. Qualquer dúvida é só chamar.', last_incoming_days.days.ago + 1.hour)
    end
    # Nota privada recente: nao pode contar como contato.
    add_message(conversation, agent, :outgoing, 'Nota interna: retomar contato.', 1.hour.ago, private: true) if note_target?(participation)
  end

  def note_target?(participation)
    participation.contact_id == @contacts[:ana].id && participation.project_id == @pe.id
  end

  def add_message(conversation, sender, type, content, at, private: false)
    Message.create!(account: @account, inbox: conversation.inbox, conversation: conversation, message_type: type,
                    content: content, sender: sender, private: private, created_at: [at, Time.current].min)
  end

  # --- temperaturas ---

  def create_evaluations
    @participations.each_value.with_index do |participation, index|
      next if (index % 5) == 4 # fica "sem temperatura"

      if participation.project_id == @pa.id
        evaluate(participation, nil, index)
      else
        participation.assignments.active.includes(:front).each do |assignment|
          evaluate(participation, assignment.front, index) if assignment.front&.has_temperature?
        end
      end
    end
  end

  def evaluate(participation, front, index)
    history = ana_campo?(participation, front) ? [['frio', 50], ['morno', 30], ['quente', 5]] : random_history(index)
    history.each do |level, days_ago|
      ::Rede::Evaluation.create!(account: @account, contact: participation.contact, project: participation.project, front: front,
                                 level: level, author_user: (participation.project_id == @pe.id ? @agents[:pe] : @agents[:pa]),
                                 evaluated_at: days_ago.days.ago)
    end
  end

  def ana_campo?(participation, front)
    participation.contact_id == @contacts[:ana].id && front == @fronts[:campo]
  end

  def random_history(index)
    count = (index % 3).zero? ? 2 : 1
    levels = LEVELS.sample(count, random: @rng) # niveis distintos: toda mudanca e real
    levels.each_with_index.map { |level, i| [level, (count - i) * @rng.rand(3..20)] }
  end

  # --- ligacoes e notas ---

  def create_interactions
    @participations.each_value.with_index do |participation, index|
      author = participation.project_id == @pe.id ? @agents[:pe] : @agents[:pa]
      create_interaction(participation, author, :call, true, @rng.rand(1..30)) if (index % 3).zero?
      create_interaction(participation, author, :call, false, @rng.rand(1..10)) if (index % 5).zero?
      create_interaction(participation, author, :note, nil, @rng.rand(1..15)) if (index % 4).zero?
    end
  end

  def create_interaction(participation, author, kind, answered, days_ago)
    summary = interaction_summary(kind, answered)
    ::Rede::Interaction.create!(account: @account, contact: participation.contact, project: participation.project, author_user: author,
                                kind: kind, answered: answered, summary: summary, occurred_at: days_ago.days.ago)
  end

  def interaction_summary(kind, answered)
    return 'Pessoa pediu material impresso.' if kind == :note

    answered ? 'Conversamos sobre a agenda do mês.' : 'Não atendeu, tentar de novo à tarde.'
  end

  # --- ultimo contato (mesmo servico do rede:backfill_last_contact) ---

  def recompute_last_contact
    ::Rede::LastContact::Recompute.new(::Rede::Participation.where(account_id: @account.id, project_id: demo_projects.select(:id))).perform
  end

  # --- resumo ---

  def print_summary
    @out.puts "Seeder do CRM concluido na conta #{@account.id} (#{@account.name})"
    @out.puts "Projetos: #{demo_projects.pluck(:name, :slug).map { |name, slug| "#{name} (#{slug})" }.join(', ')}"
    @out.puts 'ATENCAO: a senha abaixo e publica (esta no codigo). Use so em dev/homologacao e nunca em dados reais.'
    @out.puts "Agentes (senha: #{PASSWORD}; usuarios que ja existiam mantem a senha atual):"
    AGENT_EMAILS.each_value { |email| @out.puts "  #{email}" }
    @out.puts "Contatos: #{demo_contacts.count} | Participacoes: #{participations_count}"
    @out.puts "Conversas: #{@conversation_count} | Temperaturas: #{evaluations_count} | Interacoes: #{interactions_count}"
  end

  def participations_count
    ::Rede::Participation.where(account_id: @account.id, project_id: demo_projects.select(:id)).count
  end

  def evaluations_count
    ::Rede::Evaluation.where(account_id: @account.id, project_id: demo_projects.select(:id)).count
  end

  def interactions_count
    ::Rede::Interaction.where(account_id: @account.id, project_id: demo_projects.select(:id)).count
  end
end
# rubocop:enable Metrics/MethodLength
# rubocop:enable Metrics/ClassLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/ParameterLists
