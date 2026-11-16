class Rede::EvaluationPolicy < ApplicationPolicy
  # Quem pode agir sobre qual projeto é decidido pelo Rede::AccessScope na busca do projeto (fora do escopo dá 404).
  def index?
    true
  end

  def create?
    true
  end
end
