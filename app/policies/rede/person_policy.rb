class Rede::PersonPolicy < ApplicationPolicy
  # Recurso virtual: o que cada usuário vê é decidido pelo Rede::AccessScope na consulta.
  def index?
    true
  end

  def filters?
    true
  end
end
