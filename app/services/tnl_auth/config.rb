# Configuracao do login pelo tnl-auth. Le o ENV na hora (nada e fixado no boot).
module TnlAuth::Config
  def self.issuer
    ENV.fetch('TNL_AUTH_ISSUER', '').to_s.chomp('/')
  end

  def self.enabled?
    issuer.present?
  end

  def self.client_id
    ENV.fetch('TNL_AUTH_CLIENT_ID', nil).presence || 'chatwoot'
  end

  # Vazio e valido e significa "sem provider" (mostra a tela de escolha do tnl-auth).
  def self.provider
    ENV.fetch('TNL_AUTH_PROVIDER', 'google').to_s
  end

  # Id da conta onde o primeiro login cria o agente (spec 067). nil = desligado.
  def self.auto_provision_account_id
    value = ENV.fetch('TNL_AUTH_AUTO_PROVISION_ACCOUNT_ID', '').to_s.strip
    value.match?(/\A\d+\z/) && value.to_i.positive? ? value.to_i : nil
  end

  def self.callback_url
    "#{ENV.fetch('FRONTEND_URL', '').chomp('/')}/omniauth/tnl_auth/callback"
  end
end
