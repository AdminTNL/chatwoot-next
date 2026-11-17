class Rede::Roles::EnsureDefaults
  DEFAULTS = {
    'coordenador' => 'Coordenador',
    'ponto_focal' => 'Ponto focal',
    'mobilizador' => 'Mobilizador',
    'entrevistador' => 'Entrevistador'
  }.freeze

  def initialize(account)
    @account = account
  end

  # Idempotente: cria só o que falta e não sobrescreve nomes editados.
  def perform
    existing = @account.rede_roles.pluck(:key)
    DEFAULTS.except(*existing).each do |key, name|
      @account.rede_roles.create_or_find_by!(key: key) { |role| role.name = name }
    end
  end
end
