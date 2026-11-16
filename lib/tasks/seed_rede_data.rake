namespace :db do
  namespace :seed do
    desc 'Cria dados ficticios do CRM numa conta. Uso: ACCOUNT_ID=1 [RESET=true] bundle exec rake db:seed:rede_data'
    task rede_data: :environment do
      if ENV['ACCOUNT_ID'].blank?
        puts 'Informe ACCOUNT_ID. Uso: ACCOUNT_ID=1 bundle exec rake db:seed:rede_data'
        exit 1
      end

      account = Account.find_by(id: ENV.fetch('ACCOUNT_ID'))
      if account.nil?
        puts "Conta #{ENV.fetch('ACCOUNT_ID')} nao encontrada."
        exit 1
      end

      begin
        Seeders::Rede::DemoSeeder.new(account: account, reset: ENV['RESET'] == 'true').perform!
      rescue Seeders::Rede::DemoSeeder::Refused => e
        puts e.message
        exit 1
      end
    end
  end
end
