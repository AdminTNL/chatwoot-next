# frozen_string_literal: true

# Run with:
#   bundle exec rake "chatwoot:ops:temperatura_report[tmp/engajamento_contatos.csv]"
#   bundle exec rake "chatwoot:ops:backfill_temperatura[tmp/engajamento_contatos.csv]"
#   bundle exec rake "chatwoot:ops:backfill_temperatura_rollback[tmp/temperatura_backup_YYYYMMDDHHMMSS.json]"
#
# Context: spec 029. A temperatura das pessoas do Chega Junto (time id 1) vive numa tabela externa
# (engajamento_contatos, Supabase) e nunca foi refletida no Chatwoot. Estas tasks leem um CSV local
# (colunas remote_jid, temperatura, nome; o resto é ignorado) e aplicam a etiqueta
# "chega-junto-<temperatura>" no contato e nas conversas dele do time 1, casando por telefone
# (com e sem o nono dígito). Nunca criam etiqueta, contato ou time. Nenhuma delas fala com o Supabase.
#
# Safety: o relatório é somente leitura. A aplicação grava, antes de escrever, um JSON com timestamp em
# tmp/ com as etiquetas anteriores de cada contato e conversa afetados, e pede confirmação (y/N).
# Use chatwoot:ops:backfill_temperatura_rollback com esse arquivo para restaurar exatamente esse estado.
# A escrita usa Labels::TaggingWriter (sem callbacks: sem mensagens de atividade nem eventos) e é idempotente.
# A lógica vive em lib/ops/temperatura_backfill.rb; este arquivo só lê argumentos, imprime e confirma.

namespace :chatwoot do # rubocop:disable Metrics/BlockLength
  namespace :ops do # rubocop:disable Metrics/BlockLength
    desc 'Relatório (somente leitura) do backfill de etiquetas de temperatura (uso: temperatura_report[caminho_do_csv])'
    task :temperatura_report, [:csv_file] => :environment do |_, args|
      raise 'Uso: bundle exec rake "chatwoot:ops:temperatura_report[caminho/do.csv]"' unless args[:csv_file]

      puts Ops::TemperaturaBackfill.report_lines(Ops::TemperaturaBackfill.from_csv(args[:csv_file]).report)
    end

    desc 'Aplica as etiquetas de temperatura do Chega Junto a partir de um CSV, com backup e confirmação (uso: backfill_temperatura[caminho_do_csv])'
    task :backfill_temperatura, [:csv_file] => :environment do |_, args|
      raise 'Uso: bundle exec rake "chatwoot:ops:backfill_temperatura[caminho/do.csv]"' unless args[:csv_file]

      backfill = Ops::TemperaturaBackfill.from_csv(args[:csv_file])
      report = backfill.report
      puts Ops::TemperaturaBackfill.report_lines(report)

      if report[:to_change].zero?
        puts 'Nada para alterar.'
        next
      end

      backup_path = Rails.root.join('tmp', "temperatura_backup_#{Time.current.strftime('%Y%m%d%H%M%S')}.json")
      File.write(backup_path, JSON.pretty_generate(backfill.backup_data(report[:plan])))
      puts "Backup salvo em: #{backup_path}"

      print "Aplicar em #{report[:to_change]} contatos agora? (y/N): "
      unless %w[y yes].include?($stdin.gets.to_s.strip.downcase)
        puts 'Nada foi atualizado.'
        next
      end

      result = backfill.apply(report[:plan])
      puts "Contatos alterados: #{result[:contacts]}"
      puts "Conversas alteradas: #{result[:conversations]}"
    end

    desc 'Rollback de chatwoot:ops:backfill_temperatura usando o arquivo de backup JSON gerado por ele'
    task :backfill_temperatura_rollback, [:backup_file] => :environment do |_, args|
      raise 'Uso: bundle exec rake "chatwoot:ops:backfill_temperatura_rollback[caminho/do/backup.json]"' unless args[:backup_file]

      backup = JSON.parse(File.read(args[:backup_file]))
      puts "Revertendo #{backup.size} contatos a partir de #{args[:backup_file]}"

      result = Ops::TemperaturaBackfill.rollback(backup)
      puts "Revertidos: #{result[:contacts]} contatos e #{result[:conversations]} conversas"
    end
  end
end
