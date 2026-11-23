# OmniAuth configuration
# Sets the full host URL for callbacks and proper redirect handling
OmniAuth.config.full_host = ENV.fetch('FRONTEND_URL', 'http://localhost:3000')

# lib/omniauth esta fora do autoload do Zeitwerk (ver config/application.rb)
require Rails.root.join('lib/omniauth/strategies/tnl_auth').to_s

# O on_failure do Devise usa o controller padrao do Devise (o mapping nao recebe os controllers do
# devise_token_auth), entao falhas iriam para /app/login?error=access-denied. Para o tnl_auth redirecionamos
# direto para a tela de login com um erro proprio; os demais provedores seguem o fluxo original.
# devise/omniauth define o on_failure so quando e carregado (pelo model User); carregar antes evita ser sobrescrito.
require 'devise/omniauth'
devise_on_failure = OmniAuth.config.on_failure
OmniAuth.config.on_failure = proc do |env|
  if env['omniauth.error.strategy']&.name.to_s == 'tnl_auth'
    location = "#{ENV.fetch('FRONTEND_URL', '').chomp('/')}/app/login?error=tnl-auth-failed"
    Rack::Response.new(['302 Moved'], 302, 'Location' => location).finish
  else
    devise_on_failure.call(env)
  end
end

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2, ENV.fetch('GOOGLE_OAUTH_CLIENT_ID', nil), ENV.fetch('GOOGLE_OAUTH_CLIENT_SECRET', nil), {
    provider_ignores_state: true
  }
  # Sempre registrado; a configuracao (TNL_AUTH_ISSUER etc.) e lida a cada requisicao pela estrategia
  provider OmniAuth::Strategies::TnlAuth
end
