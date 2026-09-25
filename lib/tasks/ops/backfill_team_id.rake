# frozen_string_literal: true

# Run with:
#   bundle exec rake chatwoot:ops:team_id_divergence_report
#   bundle exec rake "chatwoot:ops:backfill_team_id[nome do time]"
#   bundle exec rake chatwoot:ops:backfill_chega_junto_team_id   (atalho para o time chega junto)
#
# Context: spec 008 (conversation-team-derived-from-inbox) faz conversations.team_id
# ser derivado automaticamente de conversations.inbox.team_id em todo create/update, mas
# decidiu explicitamente não fazer backfill de conversas existentes. Isso é inofensivo
# para controle de acesso (que depende da inbox, não do team_id), mas features depois
# passaram a depender de conversations.team_id estar correto: propagação de etiquetas
# entre conversas irmãs/contato (Labels::PropagationService, Labels::ContactPropagationService)
# e qualquer listagem/relatório filtrado por time. Rodamos primeiro o relatório (somente
# leitura) para ver quais times têm divergência antes de corrigir time a time.
#
# Safety da correção: antes de atualizar qualquer coisa, salva {id, inbox_id, team_id_before}
# de cada conversa que vai mudar num JSON com timestamp em tmp/, e imprime o caminho. Use
# chatwoot:ops:backfill_team_id_rollback com esse arquivo para desfazer. A atualização em si
# é um único update_all em massa, que propositalmente pula callbacks do model (sem mensagens
# de atividade / eventos de websocket "conversation updated" / ruído de contagem de não lidos)
# e não toca em label_list, então não dispara propagação de etiquetas.

namespace :chatwoot do
  namespace :ops do
    desc 'Relatório (somente leitura) de conversas com team_id divergente do team_id da inbox, para todos os times'
    task team_id_divergence_report: :environment do
      teams = Team.order(:name)
      puts "Times encontrados: #{teams.count}"
      puts '-' * 60

      total_divergent = 0
      teams.each do |team|
        inbox_ids = Inbox.where(team_id: team.id).pluck(:id)
        next if inbox_ids.empty?

        total = Conversation.where(inbox_id: inbox_ids).count
        divergent = Conversation.where(inbox_id: inbox_ids).where.not(team_id: team.id).count
        total_divergent += divergent

        status = divergent.zero? ? 'OK' : 'DIVERGENTE'
        puts format('Time: %-30s (id %s) — %s inboxes — %s/%s conversas divergentes [%s]',
                     team.name, team.id, inbox_ids.size, divergent, total, status)
      end

      puts '-' * 60
      puts "Total de conversas divergentes em todos os times: #{total_divergent}"
      puts(total_divergent.zero? ? 'Nada para corrigir em nenhum time.' : 'Use chatwoot:ops:backfill_team_id[nome do time] para corrigir um time por vez.')
    end

    desc 'Backfill conversations.team_id para um time específico (uso: backfill_team_id[nome do time])'
    task :backfill_team_id, [:team_name] => :environment do |_, args|
      raise 'Uso: bundle exec rake "chatwoot:ops:backfill_team_id[nome do time]"' unless args[:team_name]

      team = Team.find_by!(name: args[:team_name])
      inbox_ids = Inbox.where(team_id: team.id).pluck(:id)
      puts "Time: #{team.name} (id #{team.id}) — #{inbox_ids.size} inboxes"

      stale = Conversation.where(inbox_id: inbox_ids).where.not(team_id: team.id)
      count = stale.count
      puts "Conversas com team_id divergente: #{count}"

      if count.zero?
        puts 'Nada para corrigir.'
        next
      end

      backup_path = Rails.root.join('tmp', "team_id_backup_#{team.name.parameterize}_#{Time.current.strftime('%Y%m%d%H%M%S')}.json")
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

    desc 'Atalho: bundle exec rake chatwoot:ops:backfill_chega_junto_team_id (equivale a backfill_team_id[chega junto])'
    task backfill_chega_junto_team_id: :environment do
      Rake::Task['chatwoot:ops:backfill_team_id'].invoke('chega junto')
    end

    desc 'Rollback de chatwoot:ops:backfill_team_id usando o arquivo de backup JSON gerado por ele'
    task :backfill_team_id_rollback, [:backup_file] => :environment do |_, args|
      raise 'Uso: bundle exec rake "chatwoot:ops:backfill_team_id_rollback[caminho/do/backup.json]"' unless args[:backup_file]

      data = JSON.parse(File.read(args[:backup_file]))
      puts "Revertendo #{data.size} conversas a partir de #{args[:backup_file]}"

      data.each do |row|
        Conversation.where(id: row['id']).update_all(team_id: row['team_id_before']) # rubocop:disable Rails/SkipsModelValidations
      end
      puts "Revertidos: #{data.size} registros"
    end
  end
end
