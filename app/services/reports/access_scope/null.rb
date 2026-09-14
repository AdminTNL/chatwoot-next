# frozen_string_literal: true

# Stand-in for callers that have not been threaded through with a real
# AccessScope yet. Behaves exactly like an unrestricted scope, so
# query points can call `access_scope.unrestricted?` / `.restrict`
# unconditionally without special-casing "no scope was given".
class Reports::AccessScope::Null
  def self.instance
    @instance ||= new
  end

  def unrestricted?
    true
  end

  def permits_dimension?(*)
    true
  end

  def restrict(target)
    target
  end

  def inbox_ids = nil
  def label_ids = nil
  def label_titles = nil
  def team_ids = nil
  def agent_ids = nil
end
