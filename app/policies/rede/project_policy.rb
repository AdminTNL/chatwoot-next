class Rede::ProjectPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      Rede::AccessScope.new(account: account, user: user, account_user: account_user).restrict_projects(scope)
    end
  end

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
