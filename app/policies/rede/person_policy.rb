class Rede::PersonPolicy < ApplicationPolicy
  # Recurso virtual: o que cada usuário vê é decidido pelo Rede::AccessScope na consulta.
  def index?
    true
  end

  def filters?
    true
  end

  def show?
    true
  end

  def timeline?
    true
  end
end
