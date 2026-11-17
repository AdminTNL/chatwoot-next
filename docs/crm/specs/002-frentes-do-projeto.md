# Spec 002: frentes do projeto (`Rede::Front`)

## Execução

Igual à 001:
- Fluxo TDD: testes, provar que falham, implementar, verificar, code review.
- Papéis: implementador `sonnet`, testador `haiku` (espera cada comando), revisor `opus` separado.
- rspec sempre com `-e RAILS_ENV=test`, sem worktree, branch saindo da `develop`.
- Parar e reportar se faltar arquivo de produção.
- `db/schema.rb` no commit.

Comandos gerais na `000-visao-geral-fatia-1-crm.md`.

## Contexto

- A spec 001 criou `Rede::Project` (1:1 com `Team`) e o bloco `namespace :rede` em `config/routes.rb`, com `projects`.
- A frente é uma subdivisão do projeto: "PE Digital", "PE Campo". Ela organiza pessoas e temperatura, **mas não dá acesso**: quem é membro do projeto vê todas as frentes dele.
- O documento do modelo de dados previa ainda um catálogo comum `TIPO_FRENTE`. **Ele fica fora desta fatia.**

## Decisões fechadas (não reinterpretar)

1. A frente pertence a um projeto só. O nome é único dentro do projeto, sem diferenciar maiúsculas.
2. `public_id` é um uuid gerado na criação, **imutável**. É o id que ferramentas externas guardam (spec 007).
3. `has_temperature` (boolean, padrão `true`) indica se a frente usa temperatura. Frente com `false` não aceita temperatura (regra aplicada na 004).
4. A frente nunca é apagada: `active` ou `closed`, com `closed_at`. Uma frente encerrada:
   - continua visível no histórico e nas atuações antigas;
   - não aceita atuação nova nem temperatura nova (regras aplicadas na 003 e na 004);
   - pode ser reaberta.
5. Projeto sem frentes é válido, e todos os comportamentos da fatia lidam com ele.
6. Só o admin cria, edita, encerra e reabre. Os membros do projeto leem.

## Escopo

**Entra:**
- Migração `create_rede_fronts` com:
  - `account_id`, `project_id` (FK, null: false);
  - `name` (null: false);
  - `public_id` (uuid, null: false, default `gen_random_uuid()`, índice único);
  - `has_temperature` (boolean, default true, null: false);
  - `status` (integer, default 0), `closed_at`;
  - timestamps;
  - índice único `[project_id, lower(name)]`.
- Model `Rede::Front`. `Rede::Project has_many :fronts, dependent: :destroy`, mais os helpers `has_fronts?` (existe frente ativa?) e `active_fronts`.
- API aninhada em `api/v1/accounts/rede/fronts_controller.rb`:
  - `GET .../rede/projects/:project_id/fronts`: admin ou membro; projeto fora do escopo, 404;
  - `POST .../rede/projects/:project_id/fronts` (admin): `{ name, has_temperature }`;
  - `PATCH .../rede/projects/:project_id/fronts/:id` (admin): `name` e `has_temperature`; `public_id` é ignorado;
  - `POST .../fronts/:id/close` e `POST .../fronts/:id/reopen` (admin).
- O partial `_project.json.jbuilder` (da 001) ganha `fronts: [...]` com `id`, `public_id`, `name`, `has_temperature`, `status` e `closed_at`, nesta ordem: ativas por nome, depois encerradas.
- `Rede::FrontPolicy` e as views jbuilder.

**Fica de fora:** catálogo de tipos de frente; qualquer efeito sobre atuação e temperatura (003 e 004).

## Comportamento esperado

- Criar "PE Digital" e "PE Campo" no projeto PE.
- Criar "pe digital" de novo no mesmo projeto: 422. O mesmo nome em outro projeto: permitido.
- Frente de outro projeto ou de outra conta: 404.
- `PATCH` mantém o `public_id` igual.
- `close` e `reopen` são idempotentes.
- Agente membro: o `index` funciona, a escrita responde 401. Agente não membro: 404 no `index`.
- `GET /rede/projects/:id` traz as frentes no partial.

## Testes primeiro

- **`spec/models/rede/front_spec.rb`:**
  - presença do nome;
  - unicidade sem diferenciar maiúsculas dentro do projeto, e permitida entre projetos;
  - `public_id` gerado e imutável;
  - enum de status.
- **`spec/models/rede/project_spec.rb`** (acrescentar): `has_fronts?` e `active_fronts`, ignorando as encerradas.
- **`spec/controllers/api/v1/accounts/rede/fronts_controller_spec.rb`:** todos os casos acima, por papel.
- **`spec/controllers/api/v1/accounts/rede/projects_controller_spec.rb`** (acrescentar): `fronts` no `show`, na ordem certa.

## Arquivos a mudar

- `db/migrate/<ts>_create_rede_fronts.rb` (novo) e `db/schema.rb`.
- `app/models/rede/front.rb` (novo) e `app/models/rede/project.rb`.
- `app/controllers/api/v1/accounts/rede/fronts_controller.rb` (novo).
- `app/policies/rede/front_policy.rb` (novo).
- `app/views/api/v1/accounts/rede/fronts/{index,show}.json.jbuilder` e `app/views/api/v1/models/rede/_front.json.jbuilder` (novos); `app/views/api/v1/models/rede/_project.json.jbuilder`.
- `config/routes.rb`: `resources :fronts` aninhado em `projects`, com `close` e `reopen`.
- `config/locales/en.yml`.
- Os specs e `spec/factories/rede/fronts.rb` (novo).

## Casos de borda

- Projeto encerrado ainda aceita frente nova? **Sim:** encerrar o projeto não trava a administração dele.
- Nome com espaços nas pontas é limpo antes de validar.
- Ao reabrir uma frente com nome igual a outra ativa: impossível, porque a unicidade já vale para frentes encerradas também.

## Dependências

001.

## Comandos de verificação

```
docker exec chatwoot-next-rails-1 bundle exec rails db:migrate
MSYS_NO_PATHCONV=1 docker exec -e RAILS_ENV=test chatwoot-next-rails-1 bundle exec rails db:drop db:create db:schema:load
MSYS_NO_PATHCONV=1 docker exec -e RAILS_ENV=test chatwoot-next-rails-1 bundle exec rspec spec/models/rede/front_spec.rb spec/models/rede/project_spec.rb spec/controllers/api/v1/accounts/rede/fronts_controller_spec.rb spec/controllers/api/v1/accounts/rede/projects_controller_spec.rb
docker exec chatwoot-next-rails-1 bundle exec rubocop app/models/rede app/controllers/api/v1/accounts/rede app/policies/rede
```

## Revisão

- [ ] `public_id` imutável: nem `update` direto muda.
- [ ] Índice único com `lower(name)` na migração (não só validação).
- [ ] Nenhum endpoint de exclusão.
- [ ] Projeto fora do escopo do agente dá 404 também nas rotas aninhadas.
- [ ] Sem N+1 ao montar `fronts` no `index` de projetos (usar `includes`).

## Commit sugerido

`feat: adiciona frentes aos projetos do crm`
