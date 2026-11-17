class Rede::OverviewPolicy < ApplicationPolicy
  # Recurso virtual: o que cada usuário vê é decidido pelo Rede::AccessScope na consulta.
  def show?
    true
  end
end
