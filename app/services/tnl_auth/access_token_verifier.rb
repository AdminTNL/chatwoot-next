# Valida o access token (JWT ES256) emitido pelo tnl-auth contra o JWKS do issuer.
# Configuracao lida na hora: TNL_AUTH_ISSUER e TNL_AUTH_CLIENT_ID (default 'chatwoot').
# Net::HTTP direto (e nao SafeFetch) porque o issuer vem de configuracao do operador, nao de input de usuario.
class TnlAuth::AccessTokenVerifier
  class InvalidToken < StandardError; end

  JWKS_CACHE_KEY = 'tnl_auth:jwks'.freeze
  JWKS_CACHE_TTL = 10.minutes
  HTTP_TIMEOUT = 5

  def initialize(token)
    @token = token
  end

  def perform
    raise InvalidToken, 'tnl-auth issuer not configured' if issuer.blank?

    claims = decode
    validate_claims!(claims)
    claims
  rescue JWT::DecodeError => e
    raise InvalidToken, e.message
  end

  private

  def decode
    claims, = JWT.decode(
      @token, nil, true,
      algorithms: ['ES256'], jwks: jwks_loader,
      iss: issuer, verify_iss: true,
      aud: client_id, verify_aud: true
    )
    claims
  end

  def validate_claims!(claims)
    raise InvalidToken, 'invalid mode' unless claims['mode'] == 'access'
    raise InvalidToken, 'invalid type' unless claims['type'] == 'user'
    raise InvalidToken, 'missing email' if claims.dig('properties', 'email').blank?
  end

  def issuer
    ENV.fetch('TNL_AUTH_ISSUER', '').to_s.chomp('/')
  end

  def client_id
    ENV.fetch('TNL_AUTH_CLIENT_ID', nil).presence || 'chatwoot'
  end

  # Chamado pelo gem jwt: primeiro sem invalidar (usa cache); se o kid nao existe, de novo com invalidate.
  def jwks_loader
    fetched = false
    lambda do |options|
      cached = Rails.cache.read(JWKS_CACHE_KEY) unless options[:invalidate]
      next JSON.parse(cached) if cached

      body = fetched ? Rails.cache.read(JWKS_CACHE_KEY) : fetch_jwks
      fetched = true
      JSON.parse(body)
    end
  end

  def fetch_jwks
    uri = URI.parse("#{issuer}/.well-known/jwks.json")
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https',
                                                   open_timeout: HTTP_TIMEOUT, read_timeout: HTTP_TIMEOUT) do |http|
      http.get(uri.request_uri)
    end
    raise InvalidToken, "jwks fetch failed (#{response.code})" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body) # garante JSON valido antes de cachear
    Rails.cache.write(JWKS_CACHE_KEY, response.body, expires_in: JWKS_CACHE_TTL)
    response.body
  rescue InvalidToken
    raise
  rescue StandardError => e
    raise InvalidToken, "jwks fetch failed (#{e.class})"
  end
end
