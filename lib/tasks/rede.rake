namespace :rede do
  desc 'Recalcula o último contato das participações (uso: rede:backfill_last_contact[account_id]; sem argumento, todas as contas)'
  task :backfill_last_contact, [:account_id] => :environment do |_task, args|
    batch_size = 1000
    scope = Rede::Participation.order(:id)
    scope = scope.where(account_id: args[:account_id]) if args[:account_id].present?

    total = 0
    last_id = 0
    # Por lote: um pluck de ids (cursor) e uma única query UPDATE (Recompute). Sem N+1.
    loop do
      ids = scope.where('id > ?', last_id).limit(batch_size).pluck(:id)
      break if ids.empty?

      Rede::LastContact::Recompute.new(ids).perform
      last_id = ids.last
      total += ids.size
    end
    puts "rede:backfill_last_contact #{total} participações recalculadas"
  end
end
