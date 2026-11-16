class Rede::InteractionPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      Rede::AccessScope.new(account: account, user: user, account_user: account_user).restrict_participations(scope)
    end
  end

  # Quem pode agir sobre qual projeto é decidido pelo Rede::AccessScope na busca (fora do escopo dá 404).
  def index?
    true
  end

  def create?
    true
  end

  # Só o autor edita, sem exceção para administrador. A janela de 24 h é validada no model.
  def update?
    record.author_user_id == user.id
  end
end
