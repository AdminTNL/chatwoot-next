class Rede::FrontPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def create?
    @account_user.administrator?
  end

  def update?
    @account_user.administrator?
  end

  def close?
    @account_user.administrator?
  end

  def reopen?
    @account_user.administrator?
  end
end
