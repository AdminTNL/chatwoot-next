# Move os dados rede_* do contato absorvido para o base, em todos os projetos (decisão 3 da spec 011).
# Chamado de dentro da transação do ContactMergeAction, depois de mover conversas e mensagens
# e antes de apagar o contato absorvido. Usa update_columns/update_all de propósito: os dados já
# eram válidos e as validações dos models (ex.: avaliação exige atuação) não se aplicam a uma troca de dono.
class Rede::Contacts::MergeRedeData
  FILLABLE_FIELDS = %w[next_step responsible_user_id].freeze

  def initialize(base_contact:, mergee_contact:)
    @base = base_contact
    @mergee = mergee_contact
  end

  def perform
    merge_participations
    move_contact_rows
    repoint_references
    # Todas as do base: as conversas do absorvido já foram movidas para ele, mesmo em projeto onde só o base participa.
    Rede::LastContact::Recompute.new(Rede::Participation.where(contact_id: @base.id)).perform
  end

  private

  # Devolve os ids das participações do base afetadas (movidas ou absorvidas).
  def merge_participations
    Rede::Participation.where(contact_id: @mergee.id).order(:id).map do |participation|
      target = Rede::Participation.find_by(contact_id: @base.id, project_id: participation.project_id)
      target ? absorb(participation, target) : move(participation)
    end
  end

  def move(participation)
    participation.update_columns(contact_id: @base.id) # rubocop:disable Rails/SkipsModelValidations
    participation.id
  end

  def absorb(source, target)
    complete_blank_fields(source, target)
    transfer_assignments(source, target)
    Rede::Participation.where(id: source.id).destroy_all
    target.id
  end

  def complete_blank_fields(source, target)
    attrs = FILLABLE_FIELDS.select { |field| target[field].blank? && source[field].present? }.index_with { |field| source[field] }
    attrs.merge!(referral_attrs(source, target))
    target.update_columns(attrs) if attrs.any? # rubocop:disable Rails/SkipsModelValidations
  end

  # Só completa a origem da indicação se o base não tem nenhuma (texto e contato são excludentes).
  def referral_attrs(source, target)
    return {} if target.referred_by_text.present? || target.referred_by_contact_id.present?

    { 'referred_by_text' => source.referred_by_text, 'referred_by_contact_id' => source.referred_by_contact_id }.compact_blank
  end

  # Atuação ativa que colide (mesma frente, ou ambas sem frente) com uma ativa do base: a do base fica e a do outro é encerrada.
  def transfer_assignments(source, target)
    active_fronts = target.assignments.active.pluck(:front_id)
    source.assignments.each do |assignment|
      attrs = { participation_id: target.id }
      attrs.merge!(closing_attrs) if assignment.active? && active_fronts.include?(assignment.front_id)
      assignment.update_columns(attrs) # rubocop:disable Rails/SkipsModelValidations
    end
  end

  def closing_attrs
    { status: Rede::Assignment.statuses[:closed], ended_at: Time.current }
  end

  def move_contact_rows
    [Rede::Evaluation, Rede::Interaction].each do |model|
      model.where(contact_id: @mergee.id).update_all(contact_id: @base.id) # rubocop:disable Rails/SkipsModelValidations
    end
  end

  # Referências ao absorvido passam para o base; ninguém pode acabar indicando ou subordinado a si mesmo.
  def repoint_references
    Rede::Participation.where(referred_by_contact_id: @mergee.id).update_all(referred_by_contact_id: @base.id) # rubocop:disable Rails/SkipsModelValidations
    Rede::Assignment.where(superior_contact_id: @mergee.id).update_all(superior_contact_id: @base.id) # rubocop:disable Rails/SkipsModelValidations
    Rede::Participation.where(contact_id: @base.id, referred_by_contact_id: @base.id).update_all(referred_by_contact_id: nil) # rubocop:disable Rails/SkipsModelValidations
    own = Rede::Participation.where(contact_id: @base.id).select(:id)
    Rede::Assignment.where(participation_id: own, superior_contact_id: @base.id).update_all(superior_contact_id: nil) # rubocop:disable Rails/SkipsModelValidations
  end
end
