# Cria o agente (User confirmado + AccountUser + TeamMembers) no primeiro login pelo tnl-auth,
# a partir do hash liberado pelo /allowed. O papel e definido so na criacao.
# Devolve o User, ou nil se a conta alvo nao existe. Erros de validacao sobem (a transacao desfaz tudo).
class TnlAuth::ProvisionAgent
  ADMIN_ROLES = %w[master admin].freeze

  def initialize(email:, allowed:, account_id:)
    @email = email.to_s.downcase
    @allowed = allowed || {}
    @account_id = account_id
  end

  def perform
    account = Account.find_by(id: @account_id)
    if account.nil?
      Rails.logger.error "[TnlAuth] conta alvo #{@account_id} nao existe; agente #{@email} nao criado"
      return nil
    end

    user = create_user_with_membership(account)
    Rails.logger.info "[TnlAuth] agente criado: email=#{@email} conta=#{account.id} papel=#{role}"
    user
  rescue ActiveRecord::RecordNotUnique
    # Corrida: outro login da mesma pessoa criou o usuario primeiro.
    User.from_email(@email)
  end

  private

  def create_user_with_membership(account)
    ActiveRecord::Base.transaction do
      user = build_user
      user.save!
      AccountUser.create!(account: account, user: user, role: role, inviter_id: nil)
      add_teams(user, account)
      user
    end
  end

  def build_user
    user = User.new(email: @email, name: display_name, password: "#{SecureRandom.hex(16)}aA1!")
    user.skip_confirmation!
    user
  end

  def display_name
    @allowed['name'].to_s.strip.presence || @email.split('@').first
  end

  def role
    ADMIN_ROLES.include?(@allowed['role']) ? :administrator : :agent
  end

  def add_teams(user, account)
    requested_team_ids.each do |team_id|
      team = account.teams.find_by(id: team_id)
      if team
        TeamMember.create!(team: team, user: user)
      else
        Rails.logger.warn "[TnlAuth] time #{team_id} ignorado (nao pertence a conta #{account.id}): #{@email}"
      end
    end
  end

  def requested_team_ids
    metadata = @allowed['metadata']
    ids = metadata.is_a?(Hash) ? metadata['chatwoot_team_ids'] : nil
    return [] unless ids.is_a?(Array)

    ids.select { |id| id.is_a?(Integer) }.uniq
  end
end
