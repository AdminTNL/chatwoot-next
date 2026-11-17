class Rede::ApiTokenPolicy < ApplicationPolicy
  def index?
    @account_user.administrator?
  end

  def create?
    @account_user.administrator?
  end

  def revoke?
    @account_user.administrator?
  end
end
