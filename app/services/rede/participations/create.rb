class Rede::Participations::Create
  class AlreadyParticipating < StandardError
    attr_reader :participation

    def initialize(participation)
      @participation = participation
      super('Person already participates in this project')
    end
  end

  # params: contact_id | contact: { name, phone_number }, e opcionalmente assignment: { front_id, role_id, superior_contact_id }
  def initialize(account:, project:, params:)
    @account = account
    @project = project
    @params = params
  end

  def perform
    ActiveRecord::Base.transaction do
      contact = resolve_contact
      existing = @project.participations.find_by(contact_id: contact.id)
      raise AlreadyParticipating, existing if existing

      participation = create_participation(contact)
      create_assignment(participation)
      participation
    end
  end

  private

  # Dois POSTs simultâneos para o mesmo contato passam pelo find_by; o índice único pega o segundo.
  def create_participation(contact)
    @project.participations.create!(account: @account, contact: contact, origin: :manual)
  rescue ActiveRecord::RecordNotUnique
    raise AlreadyParticipating, @project.participations.find_by!(contact_id: contact.id)
  end

  def resolve_contact
    return @account.contacts.find(@params[:contact_id]) if @params[:contact_id].present?

    attrs = @params[:contact]
    raise ActionController::ParameterMissing, :contact if attrs.blank?

    phone = Rede::Phone.normalize(attrs[:phone_number])
    raise_invalid_phone(attrs) if phone.nil?

    find_by_variants(phone) || @account.contacts.create!(name: attrs[:name], phone_number: phone)
  end

  # Mais de um candidato: o que bate exatamente com o número informado; senão, o mais antigo.
  def find_by_variants(phone)
    candidates = @account.contacts.where(phone_number: Rede::Phone.variants(phone)).order(:created_at, :id).to_a
    candidates.find { |contact| contact.phone_number == phone } || candidates.first
  end

  # Nunca cria contato com telefone descartado: o Contact apaga em silêncio o telefone inválido.
  def raise_invalid_phone(attrs)
    contact = @account.contacts.new(name: attrs[:name], phone_number: attrs[:phone_number])
    contact.errors.add(:phone_number, I18n.t('errors.contacts.phone_number.invalid'))
    raise ActiveRecord::RecordInvalid, contact
  end

  def create_assignment(participation)
    attrs = @params[:assignment]
    return if attrs.nil?

    participation.assignments.create!(
      account: @account,
      front_id: attrs[:front_id].presence,
      role_id: attrs[:role_id].presence,
      superior_contact_id: attrs[:superior_contact_id].presence
    )
  end
end
