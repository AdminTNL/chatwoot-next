# Spec 007: API de leitura de projetos para ferramentas externas

## Execução

Igual à 001:
- Fluxo TDD: testes, provar que falham, implementar, verificar, code review.
- Papéis: implementador `sonnet`, testador `haiku` (espera cada comando), revisor `opus` separado.
- rspec sempre com `-e RAILS_ENV=test`, sem worktree, branch saindo da `develop`.
- Parar e reportar se faltar arquivo de produção.
- `db/schema.rb` no commit.

## Contexto

- **Primeiro consumidor:** a ferramenta de formulários do Abib (um clone da Prancheta). Ela precisa **ver os projetos e as frentes** para atribuir um formulário a um deles. Ela guarda só o id público e nunca escreve.
- **Precedente do ecossistema** (`lucastnl/stack-ce`, leitura externa do Mobiliza PA):
  - o token é guardado só como hash;
  - aparece completo apenas na criação;
  - pode ser substituído ou revogado;
  - a leitura expõe o mínimo.
- **No Chatwoot:** a autenticação de usuário usa o `api_access_token` de cada usuário. **Não serve**: um token de usuário dá o acesso inteiro daquele usuário.
- **Swagger:** `swagger/paths/index.yml`, os fragmentos em `swagger/paths/application/...`, build com `bundle exec rake swagger:build`. `spec/swagger/openapi_spec.rb` valida o documento inteiro.

## Decisões fechadas (não reinterpretar)

1. **Token próprio por conta** (`rede_api_tokens`):
   - `name`, `token_digest` (SHA-256 do valor), `token_prefix` (os 8 primeiros caracteres, para identificar na tela);
   - `scopes` (array de strings; nesta fatia só `projects:read`);
   - `created_by_user_id`, `last_used_at`, `revoked_at`.
2. **O valor:**
   - Tem o formato `rede_` + 40 caracteres aleatórios (`SecureRandom.alphanumeric(40)`).
   - Aparece **uma vez**, na resposta de criação. Não há como ler de novo: para trocar, cria-se outro e revoga-se o antigo.
3. **Só o admin** cria, lista (sem o valor) e revoga tokens, pela API da conta.
4. **A rota externa fica fora de `/api/v1/accounts`**, desenhada como se fosse outro serviço:
   - `GET /api/rede/v1/projects`, com o cabeçalho `Authorization: Bearer <token>`;
   - a conta é a do token;
   - sem sessão e sem cookies.
5. **O que a rota devolve**, para cada projeto da conta (ativos e encerrados):
   - `id` = o **slug** (o id interno não sai), `name`, `status`, `color`, `updated_at`;
   - `fronts: [{ id: public_id, name, status, has_temperature, updated_at }]`.

   Nada sobre pessoas, membros, inboxes ou contagens.
6. **Erros:**
   - sem token, token inválido ou revogado: **401** com `{ "error": "invalid_token" }`;
   - token sem o escopo: **403**.
   - Nunca dizer se um token existe.
7. **Controle de uso:**
   - `last_used_at` é atualizado no máximo uma vez por minuto por token;
   - resposta com `ETag`; `If-None-Match` igual devolve **304**.
8. **Contrato versionado (`v1`)** e documentado no Swagger. Mudança incompatível exige `v2`.

## Escopo

**Entra:**
- Migração `create_rede_api_tokens` (índice único em `token_digest`) e o model `Rede::ApiToken`, com:
  - `Rede::ApiToken.generate!(account:, name:, user:)`, que devolve `[record, plain_value]`;
  - `authenticate(plain)`;
  - `revoke!`.
- **API da conta (admin):**
  - `GET .../rede/api_tokens` (sem o valor);
  - `POST .../rede/api_tokens` (devolve o valor uma vez);
  - `POST .../rede/api_tokens/:id/revoke`.
- **API externa:** `Api::Rede::V1::ProjectsController` (`< ActionController::API`, sem os filtros do dashboard), com uma autenticação própria em `before_action`.
- **Rotas:** `namespace :api { namespace :rede { namespace :v1 { resources :projects, only: :index } } }`. Conferir se não colide com algum `namespace :api` existente; se colidir, aninhar corretamente.
- Fragmentos do Swagger (`swagger/paths/rede/v1/projects.yml` e a definição do recurso), registrados no `index.yml`. Rodar `rake swagger:build` e incluir o `swagger.json` gerado.

**Fica de fora:**
- tela de tokens (vai na 012);
- qualquer escrita externa;
- leitura de pessoas;
- tokens por projeto (todos os tokens leem todos os projetos da conta, ativos e encerrados).

## Comportamento esperado

- **O admin cria o token "Formulários Central":** recebe `{ id, name, token_prefix, token: "rede_...", scopes, created_at }`. O `GET` seguinte lista o token sem o campo `token`.
- **`GET /api/rede/v1/projects` com o token:** 200 com a lista do item 5, ordenada por nome. O id do projeto é o slug e o id da frente é o `public_id`.
- **Depois de renomear o projeto:** o `id` continua o mesmo.
- **Token revogado:** 401. Token de outra conta: lê só a própria conta.
- **Agente tentando criar token:** 401.
- **Mesma requisição com `If-None-Match`** e nada mudou: 304. Depois de editar uma frente: 200 com um ETag novo.
- **O banco** nunca contém o valor puro do token: o teste procura o valor em `rede_api_tokens`.

## Testes primeiro

- `spec/models/rede/api_token_spec.rb`: geração, hash, autenticação, revogação, `last_used_at` com o limite de 1 por minuto (`travel_to`).
- `spec/controllers/api/v1/accounts/rede/api_tokens_controller_spec.rb`: por papel.
- `spec/controllers/api/rede/v1/projects_controller_spec.rb` (`type: :request`): todos os casos acima, incluindo 401, 403, 304, o isolamento entre contas, e `conform_schema(200)` se o Swagger estiver registrado.
- `spec/swagger/openapi_spec.rb` continua verde.

## Arquivos a mudar

- `db/migrate/<ts>_create_rede_api_tokens.rb` (novo) e `db/schema.rb`.
- `app/models/rede/api_token.rb` (novo).
- `app/controllers/api/v1/accounts/rede/api_tokens_controller.rb` (novo), `app/policies/rede/api_token_policy.rb` (novo) e as views.
- `app/controllers/api/rede/v1/projects_controller.rb` (novo) e a view `app/views/api/rede/v1/projects/index.json.jbuilder`.
- `config/routes.rb` e `config/locales/en.yml`.
- `swagger/paths/...`, `swagger/definitions/...`, `swagger/paths/index.yml` e `swagger/swagger.json` (gerado).
- Os specs e `spec/factories/rede/api_tokens.rb`.

## Casos de borda

- **Cabeçalho `Authorization` com outro esquema** (`Token ...`): 401.
- **Comparação do hash em tempo constante** (`ActiveSupport::SecurityUtils.secure_compare`, ou lookup pelo digest).
- **Projeto sem frentes:** `fronts: []`.
- **Rate limit:** se o repo tem `rack-attack` configurado, acrescentar uma regra por token (60/min). Se não tiver, registrar como pendência no relatório e não adicionar gem.

## Dependências

001 e 002.

## Comandos de verificação

```
docker exec chatwoot-next-rails-1 bundle exec rails db:migrate
MSYS_NO_PATHCONV=1 docker exec -e RAILS_ENV=test chatwoot-next-rails-1 bundle exec rails db:drop db:create db:schema:load
docker exec chatwoot-next-rails-1 bundle exec rake swagger:build
MSYS_NO_PATHCONV=1 docker exec -e RAILS_ENV=test chatwoot-next-rails-1 bundle exec rspec spec/models/rede/api_token_spec.rb spec/controllers/api/v1/accounts/rede/api_tokens_controller_spec.rb spec/controllers/api/rede spec/swagger/openapi_spec.rb
docker exec chatwoot-next-rails-1 bundle exec rubocop app/models/rede app/controllers/api/rede app/controllers/api/v1/accounts/rede app/policies/rede
```

## Revisão

- [ ] O valor puro nunca é persistido nem logado. Conferir os logs de request: filtrar o `Authorization` (`filter_parameters`).
- [ ] O controller externo não herda autenticação de usuário nem `Current.user`.
- [ ] Nenhum dado de pessoa, membro ou inbox na resposta.
- [ ] 401 genérico, sem dizer se o token existe.
- [ ] Swagger válido e `swagger.json` regenerado.
- [ ] ETag estável: mesma entrada, mesmo ETag.

## Commit sugerido

`feat: expoe leitura de projetos do crm para ferramentas externas`
