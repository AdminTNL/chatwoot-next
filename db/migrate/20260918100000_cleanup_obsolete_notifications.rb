class CleanupObsoleteNotifications < ActiveRecord::Migration[7.0]
  def up
    Notifications::ObsoleteCleanupService.new.perform
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
