# Cria o projeto dos times que ainda não têm um. Idempotente: rodar de novo não cria nada.
class BackfillRedeProjects < ActiveRecord::Migration[7.1]
  def up
    Rede::Project.reset_column_information
    Team.where.missing(:rede_project).find_each do |team|
      Rede::Projects::Builder.for_team(team)
    end
  end

  def down; end
end
