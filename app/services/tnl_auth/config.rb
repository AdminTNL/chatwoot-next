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

  def self.callback_url
    "#{ENV.fetch('FRONTEND_URL', '').chomp('/')}/omniauth/tnl_auth/callback"
  end
end
