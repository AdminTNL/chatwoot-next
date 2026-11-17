# Recalcula rede_participations.last_contact_at pelo histórico (decisão 1 da spec 006): o maior entre
# a última mensagem incoming não privada do contato numa conversa do time do projeto e a última
# ligação atendida do projeto. Uma única query UPDATE para todas as participações recebidas.
# Aceita uma relation de Rede::Participation ou uma lista de participações (ou de ids).
class Rede::LastContact::Recompute
  def initialize(participations)
    @participations = participations
  end

  def perform
    scope = Rede::Participation.where(id: ids_source)
    scope.update_all(recompute_sql) # rubocop:disable Rails/SkipsModelValidations
  end

  private

  def ids_source
    return @participations.select(:id) if @participations.is_a?(ActiveRecord::Relation)

    Array(@participations).map { |item| item.respond_to?(:id) ? item.id : item }
  end

  def recompute_sql
    Rede::Participation.sanitize_sql_array(
      ["last_contact_at = GREATEST((#{messages_sql}), (#{calls_sql}))".squish, Message.message_types[:incoming], Rede::Interaction.kinds[:call]]
    )
  end

  def messages_sql
    <<~SQL.squish
      SELECT MAX(m.created_at)
        FROM messages m
        JOIN conversations c ON c.id = m.conversation_id
        JOIN rede_projects pr ON pr.team_id = c.team_id
       WHERE pr.id = rede_participations.project_id
         AND c.contact_id = rede_participations.contact_id
         AND m.account_id = rede_participations.account_id
         AND m.message_type = ?
         AND m.private = FALSE
         AND m.sender_type = 'Contact'
    SQL
  end

  def calls_sql
    <<~SQL.squish
      SELECT MAX(i.occurred_at)
        FROM rede_interactions i
       WHERE i.project_id = rede_participations.project_id
         AND i.contact_id = rede_participations.contact_id
         AND i.kind = ?
         AND i.answered = TRUE
    SQL
  end
end
