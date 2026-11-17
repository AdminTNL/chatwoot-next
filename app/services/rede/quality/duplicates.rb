# Pares de contatos duplicados dentro de UM projeto (decisão 1 da spec 011).
#
# Estratégia: comparar a chave normalizada, calculada em SQL, em vez de expandir as variantes de cada
# telefone. A chave é o E.164 sem o nono dígito (celular brasileiro: +55 DDD 9 [6-9]xxxxxxx vira
# +55 DDD [6-9]xxxxxxx); qualquer outro número é a própria chave. Como o telefone é único por conta,
# duas chaves iguais só acontecem entre o formato com e sem o nono dígito. O SQL só remove o nono dígito
# quando seguido de 6-9, então é um subconjunto simétrico de Rede::Phone.variants. Uma auto-junção por projeto resolve tudo numa consulta,
# sem trazer os telefones para a memória, e o `a.id < b.id` já entrega o par ordenado e sem auto-par.
class Rede::Quality::Duplicates
  PAIRS_SQL = <<~SQL.squish.freeze
    WITH people AS (
      SELECT c.id,
             CASE WHEN c.phone_number ~ '^\\+55\\d{2}9[6-9]\\d{7}$'
                  THEN substr(c.phone_number, 1, 5) || substr(c.phone_number, 7)
                  ELSE c.phone_number END AS phone_key
        FROM rede_participations p
        JOIN contacts c ON c.id = p.contact_id
       WHERE p.project_id = :project_id
         AND p.status = :active
         AND c.account_id = :account_id
         AND c.phone_number IS NOT NULL
         AND c.phone_number <> ''
    )
    SELECT a.id AS contact_a_id, b.id AS contact_b_id
      FROM people a
      JOIN people b ON b.phone_key = a.phone_key AND a.id < b.id
     WHERE NOT EXISTS (
       SELECT 1 FROM rede_quality_resolutions r
        WHERE r.project_id = :project_id
          AND r.kind = :dismissed
          AND r.contact_a_id = a.id
          AND r.contact_b_id = b.id
     )
     ORDER BY a.id, b.id
  SQL

  def initialize(project:)
    @project = project
  end

  # [{ project_id:, contact_a: Contact, contact_b: Contact }]
  def perform
    rows = pair_rows
    contacts = Contact.where(id: rows.flat_map { |row| [row['contact_a_id'], row['contact_b_id']] }).index_by(&:id)
    rows.map do |row|
      { project_id: @project.id, contact_a: contacts[row['contact_a_id']], contact_b: contacts[row['contact_b_id']] }
    end
  end

  private

  def pair_rows
    sql = Rede::Participation.sanitize_sql_array(
      [PAIRS_SQL, { project_id: @project.id, account_id: @project.account_id, active: Rede::Participation.statuses[:active],
                    dismissed: Rede::QualityResolution.kinds[:dismissed] }]
    )
    ActiveRecord::Base.connection.select_all(sql).to_a
  end
end
