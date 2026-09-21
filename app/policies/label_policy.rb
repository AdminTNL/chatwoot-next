class LabelPolicy < ApplicationPolicy
  def index?
    @account_user.administrator? || @account_user.agent?
  end

  def update?
    @account_user.administrator?
  end

  def show?
    @account_user.administrator?
  end

  def create?
    @account_user.administrator?
  end

  def destroy?
    @account_user.administrator?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope if account_user.administrator?

      team_ids = user.teams.where(account_id: account.id).pluck(:id)
      scope.where('labels.team_id IS NULL OR labels.team_id IN (?)', team_ids)
    end
  end
end
