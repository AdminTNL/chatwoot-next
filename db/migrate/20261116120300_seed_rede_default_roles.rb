# Papéis padrão para as contas que já têm projeto. Idempotente.
class SeedRedeDefaultRoles < ActiveRecord::Migration[7.1]
  def up
    Rede::Role.reset_column_information
    Account.where(id: Rede::Project.select(:account_id)).find_each do |account|
      Rede::Roles::EnsureDefaults.new(account).perform
    end
  end

  def down; end
end
