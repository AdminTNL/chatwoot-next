# Consulta GET {issuer}/allowed do tnl-auth com o Bearer do proprio usuario (o token recem-validado).
# Devolve o hash da resposta (email, name, role, status, metadata) ou nil em qualquer falha (falha fechada).
# Net::HTTP direto (e nao SafeFetch) porque o issuer vem de configuracao do operador, nao de input de usuario.
class TnlAuth::AllowedClient
  HTTP_TIMEOUT = 5

  def initialize(token)
    @token = token
  end

  def perform
    return nil if @token.blank? || issuer.blank?

    response = request
    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.info "[TnlAuth] /allowed respondeu #{response.code}"
      return nil
    end

    parsed = JSON.parse(response.body)
    parsed.is_a?(Hash) ? parsed : nil
  rescue StandardError => e
    Rails.logger.warn "[TnlAuth] falha ao consultar /allowed (#{e.class})"
    nil
  end

  private

  def request
    uri = URI.parse("#{issuer}/allowed")
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https',
                                        open_timeout: HTTP_TIMEOUT, read_timeout: HTTP_TIMEOUT) do |http|
      http.get(uri.request_uri, { 'Authorization' => "Bearer #{@token}", 'Accept' => 'application/json' })
    end
  end

  def issuer
    TnlAuth::Config.issuer
  end
end
