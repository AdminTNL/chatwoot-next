# Spec 001: projeto ligado ao time (`Rede::Project`)

## Execução

- **Fluxo TDD** (ver `000-visao-geral-fatia-1-crm.md`):
  1. Escrever os testes de "Testes primeiro".
  2. Rodar e **provar que falham pelo motivo certo**, colando o resumo da saída.
  3. Implementar.
  4. Verificar.
  5. Code review.
- **Papéis:**
  - **Implementador** (`sonnet`): escreve os testes e o código. Não roda a suíte completa.
  - **Testador** (`haiku`): roda os "Comandos de verificação" e **espera cada comando terminar** antes de reportar. Não corrige código de produção.
  - **Revisor** (`opus`, agente separado): usa a seção "Revisão".
- **Ambiente.** Ruby só no container. rspec **sempre** com `-e RAILS_ENV=test`. Nunca dois rspec ao mesmo tempo. Sem `isolation: "worktree"`.
- **Branch.** O trabalho sai da `develop`.
- **Se a lista de arquivos não bastar.** Se o comportamento descrito exigir arquivos de produção fora da lista "Arquivos a mudar", **pare e reporte**. Não reduza o comportamento para caber na lista. Factories ou specs antigas que quebrarem como efeito colateral devem ser investigadas uma a uma (`.claude/lessons/test-fixtures-break-silently-on-scoped-behavior-changes.md`).
- **Migração.** `db/schema.rb` entra no commit; o ruído de annotate dos models não entra.
- Passou de ~100k tokens de contexto: rode `/compact`.

## Contexto

- `Team` (`app/models/team.rb`) é a fronteira de acesso do fork:
  - a inbox pertence a um time (`inboxes.team_id`, spec 006 antiga);
  - o agente herda acesso às inboxes do time (`User#accessible_inboxes`, `app/models/user.rb:140-149`);
  - a conversa deriva `team_id` da inbox.
- `Team#name` é limpo e **posto em minúsculas** (`app/models/team.rb:38-41`) e é único por conta. Por isso a interface usa `capitalize`. O time também tem `icon` e `icon_color` (hex, só preenchido quando o ícone é Lucide; `db/migrate/20260616120000_add_icon_to_teams.rb`). `Team#label_prefix` (linha ~78) gera um slug do nome.
- `Api::V1::Accounts::TeamsController` (`app/controllers/api/v1/accounts/teams_controller.rb`) faz o CRUD. O `destroy` (linhas 20-23) apaga o time. `TeamPolicy` deixa `create?`, `update?` e `destroy?` só para admin.
- Padrão de módulo com namespace a seguir: `app/models/integrations.rb` (`table_name_prefix`), `app/models/integrations/hook.rb`, `app/controllers/api/v1/accounts/integrations/hooks_controller.rb` e `app/policies/hook_policy.rb`. O namespace `Crm::` já existe (`app/services/crm/`) e **não deve ser usado**.
- Migrações do fork: `Migration[7.1]`, chaves `bigint`, `foreign_key: true`. A última versão do schema é `2026_10_19_110000`.

## Decisões fechadas (não reinterpretar)

1. **Todo time tem exatamente um projeto.** `rede_projects.team_id` é obrigatório e único. Criar um time, por qualquer caminho (API de times, seeder, console), cria o projeto na mesma transação.
2. **Nome de exibição:**
   - Fica em `rede_projects.name`, com maiúsculas e acentos preservados.
   - Ao criar o projeto a partir de um time, o valor inicial é `team.name.titleize`.
   - Mudar o nome do projeto pela API do CRM **atualiza também** `team.name` (que continua em minúsculas), para os dois não divergirem.
   - Mudar o nome do time por outro caminho (`PATCH /teams`, console) **atualiza o nome do projeto** com `titleize`. A exceção é quando a mudança veio do próprio projeto: usar uma flag de instância para não entrar em loop nem sobrescrever o nome com maiúsculas que o admin escreveu.
3. **Slug:**
   - Gerado na criação a partir do nome: `parameterize`, único por conta, com sufixo `-2`, `-3`... em caso de colisão.
   - **Imutável.** Nenhum endpoint aceita mudar.
4. **Cor:**
   - Fica em `rede_projects.color`, em hex `#RRGGBB`, obrigatória.
   - Ao criar a partir de um time, usa `team.icon_color` se for um hex válido. Senão, usa a próxima cor de uma paleta fixa de 8 cores (definir como constante no model; escolher cores legíveis em fundo claro e escuro).
5. **Status:**
   - `active` (ativo) ou `closed` (encerrado), com `closed_at`.
   - Projeto encerrado continua existindo, aparece nas listas de admin com o rótulo "encerrado" e mantém os dados.
   - Nesta spec, encerrar não muda membros nem inboxes.
6. **Apagar time deixa de existir:** `DELETE /teams/:id` responde **422** com a mensagem i18n "Projetos não são apagados; encerre o projeto". `Team#destroy` direto (console) continua funcionando, porque é contingência.
7. **Backfill:** uma migração de dados cria um projeto para cada time existente, seguindo as regras 2 a 4. Precisa ser idempotente, porque roda em produção.
8. **Escrita só por admin.** Agentes leem só os projetos de cujo time são membros. Admin lê todos.

## Escopo

**Entra:**
- `app/models/rede.rb` (módulo com `table_name_prefix 'rede_'`).
- Model `Rede::Project` e migração `create_rede_projects`:
  - `account_id` (FK, null: false);
  - `team_id` (FK, null: false, índice único);
  - `name` (string, null: false);
  - `slug` (string, null: false, índice único `[account_id, slug]`);
  - `color` (string, null: false);
  - `status` (integer, default 0, null: false);
  - `closed_at`;
  - timestamps.
- Migração de dados do backfill (separada da de criação).
- `Team has_one :rede_project, class_name: 'Rede::Project', dependent: :destroy`, mais o callback que cria o projeto. Usar `after_create`, dentro da transação, não `after_commit`. `Account has_many :rede_projects`.
- Serviço `Rede::Projects::Builder` (`for_team(team)`), com a lógica de nome, slug e cor, usado pelo callback e pelo backfill.
- `TeamsController#destroy` passa a responder 422.
- API do CRM, em `api/v1/accounts/rede/projects_controller.rb`:
  - `GET /api/v1/accounts/:account_id/rede/projects`: admin vê todos; agente vê os projetos dos times de que é membro (ativos e encerrados).
  - `GET .../rede/projects/:id`: fora do escopo do agente, **404**.
  - `POST .../rede/projects` (admin), com `{ name, color, description?, icon?, icon_color? }`. Cria o time (`name.downcase`, mais os campos de ícone) **e** o projeto numa transação, e devolve o projeto. Nome que colide com um time existente: 422.
  - `PATCH .../rede/projects/:id` (admin): `name`, `color`, `description`. **Ignora `slug`.**
  - `POST .../rede/projects/:id/close` e `POST .../rede/projects/:id/reopen` (admin).
- `Rede::ProjectPolicy` (com `Scope`) e views jbuilder: `index`, `show` e o partial `app/views/api/v1/models/rede/_project.json.jbuilder`, com os campos `id`, `slug`, `name`, `color`, `status`, `closed_at`, `team_id`, `team_name`, `is_member`, `inboxes_count`, `members_count`, `created_at` e `updated_at`.
- Strings i18n de erro em `config/locales/en.yml`.

**Fica de fora:**
- frentes (002);
- interface (012);
- API externa (007);
- qualquer efeito de "encerrado" sobre conversas, inboxes ou membros.

## Comportamento esperado

- Criar um time pela API antiga (`POST /teams`) cria um projeto com nome titleizado, slug, cor e status ativo. A resposta da API de times não muda.
- `POST /rede/projects { name: "Mobiliza Pará", color: "#1F93FF" }`:
  - cria o time `mobiliza pará`;
  - cria o projeto com nome `Mobiliza Pará`, slug `mobiliza-para` e cor `#1F93FF`;
  - responde 200 com o partial.
- Cor fora de `#RRGGBB`: 422. Nome vazio: 422.
- `PATCH` com `slug` no corpo: o slug não muda e a resposta é 200.
- `PATCH { name: "Mobiliza PA" }`: o projeto passa a se chamar `Mobiliza PA` e o time `mobiliza pa`.
- `close` marca `closed` e `closed_at`; `reopen` volta para `active` e limpa `closed_at`. Repetir a ação é idempotente (200).
- Agente:
  - `index` só traz projetos de times de que é membro;
  - `show` de outro projeto: 404;
  - `POST`, `PATCH`, `close` e `reopen`: 401 (padrão do repo para ação proibida).
- `DELETE /teams/:id`: 422 e o time continua existindo.
- Backfill: com N times sem projeto, cria N projetos. Rodar de novo cria 0.

## Testes primeiro

Escrever e ver falhar **antes** de implementar:

- **`spec/models/rede/project_spec.rb`:**
  - validações de presença, formato da cor, unicidade de slug por conta e unicidade de `team_id`;
  - enum de status;
  - o slug não muda num `update`.
- **`spec/services/rede/projects/builder_spec.rb`:**
  - titleize do nome;
  - slug com acento (`Pará` vira `para`);
  - colisão de slug (`-2`);
  - cor a partir de `icon_color` válido;
  - fallback da paleta quando `icon_color` está vazio ou inválido.
- **`spec/models/team_spec.rb`** (acrescentar):
  - criar um time cria um projeto;
  - se a criação do projeto falhar, o time também não é criado (rollback).
- **`spec/controllers/api/v1/accounts/rede/projects_controller_spec.rb`** (`type: :request`, padrão de `teams_controller_spec.rb`):
  - todos os casos de "Comportamento esperado", para admin, agente membro, agente não membro e não autenticado;
  - isolamento entre contas.
- **`spec/controllers/api/v1/accounts/teams_controller_spec.rb`:** ajustar o teste de `destroy` para esperar 422.
- **`spec/db/rede_projects_backfill_spec.rb`** (ou no lugar onde o repo testa migrações de dados; se não houver padrão, testar o serviço que a migração chama): cria, é idempotente e respeita colisão de slug.

## Arquivos a mudar

- `app/models/rede.rb` (novo), `app/models/rede/project.rb` (novo).
- `app/models/team.rb`: `has_one`, mais o callback de criação.
- `app/models/account.rb`: `has_many :rede_projects`.
- `app/services/rede/projects/builder.rb` (novo).
- `db/migrate/<ts>_create_rede_projects.rb` e `db/migrate/<ts>_backfill_rede_projects.rb` (novos), mais `db/schema.rb`.
- `app/controllers/api/v1/accounts/rede/projects_controller.rb` (novo).
- `app/controllers/api/v1/accounts/teams_controller.rb`: `destroy`.
- `app/policies/rede/project_policy.rb` (novo).
- `app/views/api/v1/accounts/rede/projects/{index,show}.json.jbuilder` e `app/views/api/v1/models/rede/_project.json.jbuilder` (novos).
- `config/routes.rb`: bloco `namespace :rede do resources :projects, only: [:index, :show, :create, :update] do member { post :close; post :reopen } end end`, dentro de `accounts`.
- `config/locales/en.yml`: mensagens de erro.
- Os specs listados acima e `spec/factories/rede/projects.rb` (novo). A factory de `team` passa a gerar o projeto via callback; **não criar projeto duplicado na factory**.

## Casos de borda

- Time criado com `icon` emoji (`icon_color` vazio): a cor vem da paleta.
- Dois times cujo nome gera o mesmo slug (`São Paulo` e `sao paulo`): na prática é bloqueado pela unicidade do nome do time, mas o builder precisa garantir o sufixo mesmo assim.
- `PATCH` com um nome que colide com outro time: 422, e nada muda nem no projeto nem no time.
- Testes antigos que criam times em massa (factories, `seed_data.yml`, `AccountSeeder`) continuam passando: o projeto é criado automaticamente. Rodar `spec/models/team_spec.rb`, `spec/controllers/api/v1/accounts/teams_controller_spec.rb` e `spec/lib/seeders` (se existir).
- Apagar um time direto no console apaga o projeto (`dependent: :destroy`). As tabelas filhas das specs seguintes terão FK; conferir a ordem na 003.

## Dependências

Nenhuma. É a base da fatia.

## Comandos de verificação

```
docker exec chatwoot-next-rails-1 bundle exec rails db:migrate
MSYS_NO_PATHCONV=1 docker exec -e RAILS_ENV=test chatwoot-next-rails-1 bundle exec rails db:drop db:create db:schema:load
MSYS_NO_PATHCONV=1 docker exec -e RAILS_ENV=test chatwoot-next-rails-1 bundle exec rspec spec/models/rede/project_spec.rb spec/services/rede/projects/builder_spec.rb spec/models/team_spec.rb
MSYS_NO_PATHCONV=1 docker exec -e RAILS_ENV=test chatwoot-next-rails-1 bundle exec rspec spec/controllers/api/v1/accounts/rede/projects_controller_spec.rb spec/controllers/api/v1/accounts/teams_controller_spec.rb
docker exec chatwoot-next-rails-1 bundle exec rubocop app/models/rede.rb app/models/rede app/services/rede app/controllers/api/v1/accounts/rede app/policies/rede app/models/team.rb app/controllers/api/v1/accounts/teams_controller.rb
docker exec chatwoot-next-rails-1 bundle exec rails db:rollback STEP=2 && docker exec chatwoot-next-rails-1 bundle exec rails db:migrate
```

Os comandos de banco costumam ser barrados pelo classificador de permissões. Se isso acontecer, não contorne: peça ao Fabio para rodar (`.claude/lessons/schema-load-nao-apaga-tabelas-removidas.md`).

## Revisão

- [ ] Nenhum uso de `Crm::`; o namespace é `Rede::` com tabelas `rede_*`.
- [ ] Criação de time e de projeto atômica: sem time sem projeto em caso de erro.
- [ ] O slug não muda por nenhum caminho, nem por `update` direto no model.
- [ ] O nome do projeto e o do time ficam sincronizados nos dois sentidos (decisão 2), sem loop e sem perder as maiúsculas escritas no projeto.
- [ ] O agente não vê projeto de outro time em `index` nem em `show` (404, não 401).
- [ ] O backfill é idempotente e não depende de dados de exemplo.
- [ ] A migração é reversível, e `db/schema.rb` está no commit.
- [ ] Os testes antigos de times, factories e seeders continuam verdes.

## Commit sugerido

`feat: cria projeto do crm ligado a cada time`
