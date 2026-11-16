# Qualidade dos dados é só para administradores. O record é [:rede, :quality].
class Rede::QualityPolicy < ApplicationPolicy
  def index?
    @account_user.administrator?
  end

  def dismiss?
    @account_user.administrator?
  end

  def merge?
    @account_user.administrator?
  end
end
