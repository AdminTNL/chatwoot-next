class Rede::ProjectPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope if @account_user.administrator?

      scope.where(team_id: user.teams.select(:id))
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
