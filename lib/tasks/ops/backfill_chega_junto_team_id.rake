# frozen_string_literal: true

# Run with:
#   bundle exec rake chatwoot:ops:backfill_chega_junto_team_id
#
# Context: spec 008 (conversation-team-derived-from-inbox) made conversations.team_id
# derive automatically from conversations.inbox.team_id on every create/update, but
# explicitly decided not to backfill existing conversations. That is fine for access
# (which depends on the inbox, not on team_id), but later features started depending
# on conversations.team_id being accurate: label propagation between sibling
# conversations/contact (Labels::PropagationService, Labels::ContactPropagationService)
# and any team-scoped conversation listing/reporting. This task closes that gap for a
# single team (Chega Junto) instead of backfilling the whole account at once.
#
# Safety: before updating anything, it dumps {id, inbox_id, team_id_before} for every
# conversation that is about to change into a timestamped JSON file under tmp/, and
# prints that path. Use chatwoot:ops:backfill_chega_junto_team_id_rollback with that
# file to undo. The actual update is a single bulk update_all, which intentionally
# skips model callbacks (no activity messages / websocket "conversation updated"
# events / unread-count invalidation noise) and does not touch label_list, so it does
# not trigger label propagation.

namespace :chatwoot do
  namespace :ops do
    desc 'Backfill conversations.team_id for the Chega Junto team conversations whose inbox already has a team but the conversation itself was never re-saved since'
    task backfill_chega_junto_team_id: :environment do
      team = Team.find_by!(name: 'Chega Junto')
      inbox_ids = Inbox.where(team_id: team.id).pluck(:id)
      puts "Time: #{team.name} (id #{team.id}) — #{inbox_ids.size} inboxes"

      stale = Conversation.where(inbox_id: inbox_ids).where.not(team_id: team.id)
      count = stale.count
      puts "Conversas com team_id divergente: #{count}"

      if count.zero?
        puts 'Nada para corrigir.'
        next
      end

      backup_path = Rails.root.join('tmp', "chega_junto_team_id_backup_#{Time.current.strftime('%Y%m%d%H%M%S')}.json")
      backup_data = stale.pluck(:id, :inbox_id, :team_id).map do |id, inbox_id, team_id_before|
        { id: id, inbox_id: inbox_id, team_id_before: team_id_before }
      end
      File.write(backup_path, JSON.pretty_generate(backup_data))
      puts "Backup salvo em: #{backup_path} (#{backup_data.size} registros)"

      print "Aplicar team_id=#{team.id} em #{count} conversas agora? (y/N): "
      confirm = $stdin.gets.strip.downcase
      unless %w[y yes].include?(confirm)
        puts 'Nada foi atualizado.'
        next
      end

      updated = stale.update_all(team_id: team.id) # rubocop:disable Rails/SkipsModelValidations
      puts "Conversas atualizadas: #{updated}"

      remaining = Conversation.where(inbox_id: inbox_ids).where.not(team_id: team.id).count
      puts "Restantes com team_id divergente: #{remaining}"
    end

    desc 'Rollback chatwoot:ops:backfill_chega_junto_team_id using its backup JSON file'
    task :backfill_chega_junto_team_id_rollback, [:backup_file] => :environment do |_, args|
      raise 'Uso: bundle exec rake "chatwoot:ops:backfill_chega_junto_team_id_rollback[caminho/do/backup.json]"' unless args[:backup_file]

      data = JSON.parse(File.read(args[:backup_file]))
      puts "Revertendo #{data.size} conversas a partir de #{args[:backup_file]}"

      data.each do |row|
        Conversation.where(id: row['id']).update_all(team_id: row['team_id_before']) # rubocop:disable Rails/SkipsModelValidations
      end
      puts "Revertidos: #{data.size} registros"
    end
  end
end
