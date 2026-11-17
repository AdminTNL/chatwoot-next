# Spec 004: temperatura por frente (`Rede::Evaluation`)

## Execução

Igual à 001:
- Fluxo TDD: testes, provar que falham, implementar, verificar, code review.
- Papéis: implementador `sonnet`, testador `haiku` (espera cada comando), revisor `opus` separado.
- rspec sempre com `-e RAILS_ENV=test`, sem worktree, branch saindo da `develop`.
- Parar e reportar se faltar arquivo de produção.
- `db/schema.rb` no commit.

## Contexto

- A participação e a atuação existem desde a 003, e o escopo de acesso é o `Rede::AccessScope`.
- **Hoje a temperatura já existe como etiqueta por time:**
  - um grupo de 4 etiquetas por time (`label_groups`, spec antiga 015);
  - uma etiqueta por contato por grupo (`app/services/labels/group_exclusivity_resolver.rb`);
  - propagada para as conversas (`app/services/labels/propagation_service.rb`);
  - backfill na spec antiga 029 (`lib/ops/temperatura_backfill.rb`).
- **Esta spec não toca em nada disso.** A temperatura do CRM é independente nesta fatia (decisão 8 da 000).
- O modelo de dados previa um catálogo de dimensões (`DIMENSAO`) e critérios calculados. Nesta fatia só existe a temperatura manual. A coluna `dimension` fica preparada para o futuro, mas aceita só `temperatura`.

## Decisões fechadas (não reinterpretar)

1. **Escala:** `frio` (0), `morno` (1), `quente` (2), `vapor` (3). **`level` nulo quer dizer "sem temperatura"**: é o registro de que a temperatura foi retirada.
2. **Contexto da temperatura:** pessoa, projeto e frente.
   - **Projeto com frentes ativas:** `front_id` é **obrigatório**, a frente está ativa e tem `has_temperature = true`.
   - **Projeto sem frentes ativas:** `front_id` precisa ser **nulo** (temperatura do projeto).
   - A pessoa precisa ter participação ativa no projeto. Em projeto com frentes, precisa também de uma atuação ativa **naquela frente**. Uma atuação "frente a definir" não aceita temperatura.
3. **Nunca sobrescreve.** Cada mudança é uma linha nova (`evaluated_at`, `author_user_id`, `note` opcional). A temperatura atual é a linha mais recente do contexto.
4. **Quem pode registrar:** o admin e qualquer membro do projeto, mesmo que não seja o responsável.
5. **Sem validade** (`valido_ate`) e sem cálculo automático nesta fatia.

## Escopo

**Entra:**
- **Migração `create_rede_evaluations`:**
  - `account_id`, `contact_id` (integer, FK), `project_id`, `front_id` (nullable), `author_user_id`;
  - `dimension` (string, default `'temperatura'`, null: false);
  - `level` (integer, nullable);
  - `note` (text);
  - `evaluated_at` (null: false);
  - timestamps;
  - índice `[contact_id, project_id, front_id, evaluated_at]`.
- **Model `Rede::Evaluation`** com as validações acima.
- **Consulta da temperatura atual:** `Rede::Evaluations::Current`, que para um conjunto de participações devolve `{[contact_id, project_id, front_id] => level}` numa consulta só (`DISTINCT ON`). As APIs 008, 009, 010 e 018 vão usá-la.
- **API:**
  - `POST .../rede/evaluations` com `{ contact_id, project_id, front_id, level, note }`. `level: null` é permitido (retira a temperatura).
  - `GET .../rede/evaluations?contact_id=&project_id=` para o histórico, no escopo.
- Policy e jbuilder `_evaluation` (com `author: { id, name }`).

**Fica de fora:**
- sincronização com etiquetas;
- cálculo por critérios, dimensões extras e validade;
- interface (016 e 018).

## Comportamento esperado

- **Projeto PE (com frentes), Ana com atuação ativa em "PE Campo":**
  - `POST { front_id: campo, level: 'quente' }` responde 200;
  - a temperatura atual de Ana em PE Campo passa a ser quente.
- **Depois `level: 'morno'`:** a temperatura atual vira morno, e as duas linhas continuam no histórico.
- **`level: null`:** a temperatura atual fica "sem temperatura".
- **Em PE, sem `front_id`:** 422.
- **Em "PE Digital"**, onde Ana não tem atuação ativa: 422.
- **Em frente com `has_temperature = false`** ou encerrada: 422.
- **Projeto PA, sem frentes:** `POST { front_id: nil, level: 'frio' }` responde 200; com qualquer `front_id`, 422.
- **Agente não membro do projeto:** 404.
- **`Current`:** para 50 participações, uma consulta (medir com `ActiveRecord::QueryRecorder` ou contando queries no teste).

## Testes primeiro

- `spec/models/rede/evaluation_spec.rb`: todas as validações da decisão 2, `level` nulo, enum.
- `spec/services/rede/evaluations/current_spec.rb`: a mais recente vence; contextos diferentes não se misturam; nula conta como "sem temperatura"; número de consultas.
- `spec/controllers/api/v1/accounts/rede/evaluations_controller_spec.rb`: por papel, com todos os casos de "Comportamento esperado".

## Arquivos a mudar

- `db/migrate/<ts>_create_rede_evaluations.rb` (novo) e `db/schema.rb`.
- `app/models/rede/evaluation.rb` (novo); `app/models/contact.rb` e `app/models/rede/project.rb` (associações).
- `app/services/rede/evaluations/current.rb` (novo).
- `app/controllers/api/v1/accounts/rede/evaluations_controller.rb` (novo), `app/policies/rede/evaluation_policy.rb` (novo) e as views jbuilder (novas).
- `config/routes.rb` e `config/locales/en.yml`.
- Os specs e `spec/factories/rede/evaluations.rb`.

## Casos de borda

- **O projeto ganha a primeira frente** depois de já haver temperaturas de projeto (`front_id` nulo): as linhas antigas ficam no histórico. A temperatura "atual" do projeto deixa de aparecer na lista, porque a lista passa a mostrar por frente (008). Não migrar dado.
- **Encerrar a frente** mantém o histórico; a nova temperatura nessa frente é recusada.
- **Duas linhas com o mesmo `evaluated_at`:** desempatar por `id`.

## Dependências

003.

## Comandos de verificação

```
docker exec chatwoot-next-rails-1 bundle exec rails db:migrate
MSYS_NO_PATHCONV=1 docker exec -e RAILS_ENV=test chatwoot-next-rails-1 bundle exec rails db:drop db:create db:schema:load
MSYS_NO_PATHCONV=1 docker exec -e RAILS_ENV=test chatwoot-next-rails-1 bundle exec rspec spec/models/rede/evaluation_spec.rb spec/services/rede/evaluations spec/controllers/api/v1/accounts/rede/evaluations_controller_spec.rb
docker exec chatwoot-next-rails-1 bundle exec rubocop app/models/rede app/services/rede app/controllers/api/v1/accounts/rede app/policies/rede
```

## Revisão

- [ ] Nenhum `update` em `rede_evaluations` (só inserção).
- [ ] Nenhuma alteração em etiquetas, `label_groups` ou taggings.
- [ ] A regra frente obrigatória ou nula depende de **frentes ativas no momento do registro**.
- [ ] `Current` sem N+1 e com desempate determinístico.
- [ ] Escopo: histórico e criação passam pelo `Rede::AccessScope`.

## Commit sugerido

`feat: registra temperatura por frente no crm`
