require 'omniauth-oauth2'

# Estrategia OmniAuth para o tnl-auth (OpenAuth). Fica fora do autoload do Zeitwerk
# (ver config/application.rb) e e carregada por config/initializers/omniauth.rb.
# A configuracao (TNL_AUTH_ISSUER, TNL_AUTH_CLIENT_ID, FRONTEND_URL) e lida a cada requisicao.
class OmniAuth::Strategies::TnlAuth < OmniAuth::Strategies::OAuth2
  option :name, 'tnl_auth'
  option :client_options, { authorize_url: '/authorize', token_url: '/token', auth_scheme: :request_body }
  option :client_secret, ''
  option :provider_ignores_state, true
  option :pkce, false

  uid { raw_info['sub'] }

  info do
    { email: raw_info.dig('properties', 'email').to_s.downcase, name: nil }
  end

  extra { { raw_info: raw_info } }

  # A instancia da estrategia vive uma requisicao, entao issuer/client_id sao lidos a cada uma.
  def client
    @client ||= ::OAuth2::Client.new(client_id, '', deep_symbolize(options.client_options).merge(site: issuer))
  end

  def callback_url
    "#{ENV.fetch('FRONTEND_URL', '').chomp('/')}/omniauth/tnl_auth/callback"
  end

  def callback_phase
    return fail!(:not_configured, StandardError.new('TNL_AUTH_ISSUER not set')) if issuer.blank?

    super
  end

  protected

  def build_access_token
    token = super
    @raw_info = ::TnlAuth::AccessTokenVerifier.new(token.token).perform
    token
  rescue ::TnlAuth::AccessTokenVerifier::InvalidToken => e
    raise CallbackError.new(:invalid_token, e.message)
  end

  private

  def raw_info
    @raw_info || {}
  end

  def issuer
    ENV.fetch('TNL_AUTH_ISSUER', '').to_s.chomp('/')
  end

  def client_id
    ENV.fetch('TNL_AUTH_CLIENT_ID', nil).presence || 'chatwoot'
  end
end
