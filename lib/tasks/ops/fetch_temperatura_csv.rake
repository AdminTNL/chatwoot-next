# frozen_string_literal: true

# TEMPORÁRIO. Existe só para poupar o export manual do CSV enquanto o backfill de temperatura
# (spec 029) estiver em uso ativo. Apague este arquivo quando não for mais necessário.
#
# Run with:
#   bundle exec rake "chatwoot:ops:fetch_temperatura_csv[tmp/engajamento_contatos.csv]"
#
# Busca remote_jid, temperatura e nome da tabela engajamento_contatos do Supabase (API REST/PostgREST,
# somente GET, paginado) e grava o CSV local consumido por chatwoot:ops:temperatura_report e
# chatwoot:ops:backfill_temperatura. Exige as variáveis de ambiente SUPABASE_URL e
# SUPABASE_SERVICE_ROLE_KEY no container.

require 'csv'
require 'net/http'

namespace :chatwoot do
  namespace :ops do
    desc 'TEMPORÁRIO: baixa engajamento_contatos do Supabase para um CSV local (uso: fetch_temperatura_csv[caminho_de_saida])'
    task :fetch_temperatura_csv, [:output_file] => :environment do |_, args|
      supabase_url = ENV.fetch('SUPABASE_URL') { raise 'SUPABASE_URL não configurada' }
      service_key = ENV.fetch('SUPABASE_SERVICE_ROLE_KEY') { raise 'SUPABASE_SERVICE_ROLE_KEY não configurada' }
      output_file = args[:output_file] || 'tmp/engajamento_contatos.csv'
      page_size = 1000

      uri = URI.join("#{supabase_url.chomp('/')}/", 'rest/v1/engajamento_contatos')
      uri.query = URI.encode_www_form(select: 'remote_jid,temperatura,nome')

      rows = []
      loop do
        request = Net::HTTP::Get.new(uri)
        request['apikey'] = service_key
        request['Authorization'] = "Bearer #{service_key}"
        request['Range-Unit'] = 'items'
        request['Range'] = "#{rows.size}-#{rows.size + page_size - 1}"

        response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') { |http| http.request(request) }
        raise "Supabase respondeu #{response.code}: #{response.body}" unless response.is_a?(Net::HTTPSuccess)

        page = JSON.parse(response.body)
        rows.concat(page)
        break if page.size < page_size
      end

      CSV.open(output_file, 'w') do |csv|
        csv << %w[remote_jid temperatura nome]
        rows.each { |row| csv << row.values_at('remote_jid', 'temperatura', 'nome') }
      end

      puts "Linhas baixadas: #{rows.size}"
      puts "CSV gerado em: #{output_file}"
    end
  end
end
