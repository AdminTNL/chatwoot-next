# Inicio do login pelo tnl-auth: gera state e PKCE no servidor, guarda na sessao do Rails
# (chaves que o omniauth-oauth2 le no callback) e redireciona para o /authorize do tnl-auth.
# ActionController::Base de proposito: so precisa de sessao, sem autenticacao, locale ou Pundit do ApplicationController.
class TnlAuth::LoginController < ActionController::Base # rubocop:disable Rails/ApplicationController
  def start
    return head :not_found unless TnlAuth::Config.enabled?

    state = SecureRandom.hex(24)
    verifier = SecureRandom.hex(64)
    session['omniauth.state'] = state
    session['omniauth.pkce.verifier'] = verifier

    response.headers['Cache-Control'] = 'no-store'
    redirect_to authorize_url(state, verifier), allow_other_host: true
  end

  private

  def authorize_url(state, verifier)
    params = {
      client_id: TnlAuth::Config.client_id,
      redirect_uri: TnlAuth::Config.callback_url,
      response_type: 'code',
      state: state,
      code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false),
      code_challenge_method: 'S256'
    }
    params[:provider] = TnlAuth::Config.provider if TnlAuth::Config.provider.present?
    "#{TnlAuth::Config.issuer}/authorize?#{params.to_query}"
  end
end
