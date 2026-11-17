# Ponto único de "quais projetos este usuário vê" no CRM (Rede). Toda API do CRM usa este serviço.
# Admin vê tudo; agente vê os projetos dos times de que é membro nesta conta; quem não é da conta não vê nada.
class Rede::AccessScope
  def initialize(account:, user:, account_user: nil)
    @account = account
    @user = user
    @account_user = account_user || @account.account_users.find_by(user_id: @user.id)
  end

  def unrestricted?
    return @unrestricted if defined?(@unrestricted)

    @unrestricted = @account_user&.administrator? || false
  end

  # nil significa "todos os projetos da conta" (admin).
  def project_ids
    return nil if unrestricted?

    @project_ids ||= if @account_user.nil?
                       []
                     else
                       Rede::Project.where(account_id: @account.id, team_id: @user.teams.where(account_id: @account.id).select(:id)).ids
                     end
  end

  def restrict_projects(relation)
    return relation if unrestricted?

    relation.where(id: project_ids)
  end

  def restrict_participations(relation)
    return relation if unrestricted?

    relation.where(project_id: project_ids)
  end

  def can_access_project?(project)
    return project.account_id == @account.id if unrestricted?

    project_ids.include?(project.id)
  end
end
