class Rede::ParticipationPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      Rede::AccessScope.new(account: account, user: user, account_user: account_user).restrict_participations(scope)
    end
  end

  # Quem pode agir sobre qual projeto é decidido pelo Rede::AccessScope na busca (fora do escopo dá 404).
  def create?
    true
  end

  def update?
    true
  end
end
