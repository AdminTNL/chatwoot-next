# Ficha da pessoa no CRM: dados do contato e uma participação por projeto visível ao usuário.
# Sem participação visível não há ficha (RecordNotFound -> 404), mesmo que o contato exista.
# Número de consultas constante: projetos, frentes, atuações, papéis e temperaturas são carregados em lote.
class Rede::People::Profile
  def initialize(account:, user:, contact:)
    @account = account
    @user = user
    @contact = contact
  end

  def perform
    raise ActiveRecord::RecordNotFound if @contact.account_id != @account.id || participations.empty?

    { contact: contact_hash, participations: participations.map { |participation| participation_hash(participation) } }
  end

  private

  def participations
    @participations ||= begin
      scope = Rede::AccessScope.new(account: @account, user: @user)
      scope.restrict_participations(Rede::Participation.where(account_id: @account.id, contact_id: @contact.id))
           .includes(:project, :responsible_user, :referred_by_contact, assignments: [:front, :role, :superior_contact])
           .sort_by { |participation| [participation.project.name.downcase, participation.id] }
    end
  end

  def projects_with_fronts
    @projects_with_fronts ||= Rede::Front.active.where(project_id: participations.map(&:project_id)).distinct.pluck(:project_id)
  end

  def temperatures
    @temperatures ||= Rede::Evaluations::Current.new(participations).perform
  end

  def contact_hash
    city = @contact.additional_attributes.to_h['city']
    { id: @contact.id, name: @contact.name, phone_number: @contact.phone_number, email: @contact.email,
      city: city, avatar_url: @contact.avatar_url.presence }
  end

  def participation_hash(participation) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
    has_fronts = projects_with_fronts.include?(participation.project_id)
    active = participation.assignments.select(&:active?).sort_by(&:id)
    {
      id: participation.id,
      project: project_hash(participation.project, has_fronts),
      status: participation.status, joined_at: participation.joined_at, origin: participation.origin,
      responsible: pair(participation.responsible_user),
      referred_by: { contact: pair(participation.referred_by_contact), text: participation.referred_by_text },
      next_step: participation.next_step, last_contact_at: participation.last_contact_at,
      assignments: active.map { |assignment| assignment_hash(participation, assignment, has_fronts) },
      project_temperature: has_fronts ? nil : temperature(participation, nil),
      front_pending: has_fronts && (active.empty? || active.any? { |assignment| assignment.front_id.nil? })
    }
  end

  def project_hash(project, has_fronts)
    { id: project.id, slug: project.slug, name: project.name, color: project.color, status: project.status, has_fronts: has_fronts }
  end

  # Atuação sem frente em projeto com frentes ("frente a definir") não tem temperatura.
  def assignment_hash(participation, assignment, has_fronts)
    {
      id: assignment.id,
      front: pair(assignment.front),
      role: pair(assignment.role),
      superior: pair(assignment.superior_contact),
      started_at: assignment.started_at,
      temperature: assignment.front_id.nil? && has_fronts ? nil : temperature(participation, assignment.front_id)
    }
  end

  def temperature(participation, front_id)
    temperatures[[participation.contact_id, participation.project_id, front_id]]
  end

  def pair(record)
    record && { id: record.id, name: record.name }
  end
end
