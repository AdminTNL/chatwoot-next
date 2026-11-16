# Participações ativas do projeto com cadastro incompleto (decisão 4 da spec 011).
# Cada problema é um item separado: missing_name, missing_phone, missing_city, pending_front.
class Rede::Quality::Incompletes
  def initialize(project:)
    @project = project
  end

  # [{ kind:, contact: Contact }]
  def perform
    participations = @project.participations.active.includes(:contact).order(:contact_id)
    pending_ids = pending_front_contact_ids(participations)
    participations.flat_map do |participation|
      contact = participation.contact
      kinds_for(contact, pending_ids.include?(participation.contact_id)).map { |kind| { kind: kind, contact: contact } }
    end
  end

  private

  def kinds_for(contact, pending_front)
    kinds = []
    kinds << 'missing_name' if contact.name.blank?
    kinds << 'missing_phone' if contact.phone_number.blank?
    kinds << 'missing_city' if contact.additional_attributes.to_h['city'].to_s.strip.empty?
    kinds << 'pending_front' if pending_front
    kinds
  end

  # Só vale em projeto com frentes ativas: participação sem nenhuma atuação ativa com frente.
  def pending_front_contact_ids(participations)
    return Set.new unless @project.has_fronts?

    with_front = Rede::Assignment.active.where.not(front_id: nil).where(participation_id: participations.select(:id)).select(:participation_id)
    participations.where.not(id: with_front).pluck(:contact_id).to_set
  end
end
