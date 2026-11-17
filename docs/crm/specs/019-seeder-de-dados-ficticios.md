# Spec 019: Seeder de dados fictícios do CRM

## Execução

Igual à 001:
- Fluxo TDD: testes, provar que falham, implementar, verificar, code review.
- Papéis: implementador `sonnet`, testador `haiku`, revisor `opus`.
- rspec com `-e RAILS_ENV=test`, sem worktree.

## Contexto

- **Padrão do repo:** `lib/tasks/seed_reports_data.rake` (exige `ACCOUNT_ID` e liga `ENABLE_ACCOUNT_SEEDING`), que chama `Seeders::Reports::ReportDataSeeder` em `lib/seeders/reports/`. Ver também `lib/seeders/account_seeder.rb`, `inbox_seeder.rb` e `message_seeder.rb`.
- **Para que serve:**
  - o percurso manual de cada spec de front (014 a 018);
  - a revisão final (021);
  - a homologação (020).

  Precisa cobrir todos os casos visíveis da fatia.
- **Os dados reais nunca entram aqui.** Os nomes e os telefones são fictícios.

## Decisões fechadas (não reinterpretar)

1. **Rake** `db:seed:rede_data ACCOUNT_ID=<id>`.
   - Recusa rodar se `Rails.env.production?` e `ENABLE_ACCOUNT_SEEDING` não for `true`.
   - Recusa rodar se a conta já tiver um projeto com o slug `mobiliza-demo-pe`, a não ser que `RESET=true`, que apaga **só** os dados criados pelo seeder (marcados como explicado na decisão 3).
2. **O seeder `Seeders::Rede::DemoSeeder`** (`lib/seeders/rede/demo_seeder.rb`) cria, pelos models e serviços da fatia (nunca por SQL direto, para exercitar os callbacks):
   - **dois times e projetos:**
     - "Mobiliza Demo PE", com as frentes Campo (`has_temperature`), Digital (`has_temperature`) e Formação (sem temperatura);
     - "Mobiliza Demo PA", sem frentes;
   - **uma caixa API por time** (`Channel::Api`), cada uma no seu time;
   - **agentes:**
     - `agente.pe@demo.local` (membro do PE);
     - `agente.pa@demo.local` (membro do PA);
     - `agente.ambos@demo.local` (membro dos dois).

     Todos com uma senha de demonstração impressa no fim.
   - **cerca de 30 contatos**, com telefones `+55819…` e `+55919…` fictícios e cidades variadas. **Ao menos estes casos:**
     - a pessoa em PE com duas atuações (Campo e Digital) e também no PA;
     - a pessoa em PE sem atuação ("frente a definir");
     - a pessoa em PE só em Formação (sem temperatura);
     - um par duplicado no PE (o mesmo número com e sem o nono dígito, com nomes parecidos);
     - um par com o mesmo número normalizado, mas um no PE e outro no PA (**não** pode aparecer como duplicado);
     - contatos sem cidade e um sem nome;
     - indicação (`referred_by`) e superior em algumas atuações;
   - **conversas** nas caixas, com mensagens recebidas e enviadas em datas espalhadas pelos últimos 60 dias (algumas com mais de 7 dias sem mensagem recebida), mais uma nota privada recente que **não** pode contar como contato;
   - **temperaturas** com histórico (pelo menos uma pessoa com três mudanças);
   - **ligações** atendidas e não atendidas, e notas;
   - **o último contato** calculado no fim (`rede:backfill_last_contact`, ou o serviço da 006).
3. **Marcação:** os registros criados ficam identificáveis (contatos com `additional_attributes.seed = 'rede_demo'`; projetos pelos slugs `mobiliza-demo-*`), para o `RESET` apagar só eles.
4. **Determinismo:** usar uma semente fixa (`Random.new(42)`) e datas relativas a `Time.current`, para que duas execuções deem o mesmo formato de dados.

## Escopo

**Entra:** o seeder, a rake e o spec.

**Fica de fora:** volume de carga (milhares de linhas) e dados de formulário.

## Comportamento esperado

- **`ACCOUNT_ID=1 bundle exec rake db:seed:rede_data`** no dev: termina em menos de 1 minuto e imprime um resumo com os projetos, os agentes e a senha, e as contagens.
- **Depois dele:**
  - a visão geral mostra números não nulos em todos os cartões;
  - a qualidade do PE mostra 1 duplicado e os incompletos;
  - a qualidade do PA não mostra o par entre projetos.
- **Rodar de novo sem `RESET`:** sai com uma mensagem, sem duplicar.

## Testes primeiro

`spec/lib/seeders/rede/demo_seeder_spec.rb`:
- cria o que a decisão 2 lista (contar por tipo);
- os casos-chave existem (duplicado no mesmo projeto e o par entre projetos);
- a nota privada não muda `last_contact_at`;
- `RESET` apaga só os marcados (criar antes um contato não marcado e conferir que ele fica);
- a trava de produção.

## Arquivos a mudar

- `lib/seeders/rede/demo_seeder.rb` (novo).
- `lib/tasks/seed_rede_data.rake` (novo).
- `spec/lib/seeders/rede/demo_seeder_spec.rb` (novo).

## Casos de borda

- **A conta já tem um time com o nome "mobiliza demo pe":** o seeder usa outro nome (sufixo) ou recusa com uma mensagem clara. Escolher e documentar.
- **Os e-mails dos agentes já existem em outra conta:** reaproveitar o usuário e só adicionar à conta.

## Dependências

001 a 006 (e 011, para conferir os duplicados).

## Comandos de verificação

```
MSYS_NO_PATHCONV=1 docker exec -e RAILS_ENV=test chatwoot-next-rails-1 bundle exec rspec spec/lib/seeders/rede
docker exec -e ACCOUNT_ID=1 chatwoot-next-rails-1 bundle exec rake db:seed:rede_data
docker exec chatwoot-next-rails-1 bundle exec rubocop lib/seeders/rede lib/tasks/seed_rede_data.rake
```

## Revisão

- [ ] Nenhum dado real (nome, telefone) no código.
- [ ] Usa os models e os serviços, não SQL: os callbacks da fatia rodam.
- [ ] Trava de produção e `RESET` seguro.
- [ ] Todos os casos da decisão 2 presentes.

## Commit sugerido

`feat: cria seeder de dados ficticios do crm`
