class Rede::AssignmentPolicy < ApplicationPolicy
  # Quem pode agir sobre qual projeto é decidido pelo Rede::AccessScope na busca da participação (fora do escopo dá 404).
  def create?
    true
  end

  def update?
    true
  end

  def close?
    true
  end
end
