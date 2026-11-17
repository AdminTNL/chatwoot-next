# Spec 011: API de qualidade dos dados

## Execução

Igual à 001:
- Fluxo TDD: testes, provar que falham, implementar, verificar, code review.
- Papéis: implementador `sonnet`, testador `haiku` (espera cada comando), revisor `opus` separado.
- rspec sempre com `-e RAILS_ENV=test`, sem worktree, branch saindo da `develop`.
- Parar e reportar se faltar arquivo de produção.
- `db/schema.rb` no commit.

Esta spec **mexe no `ContactMergeAction`**, que é usado também pelo `contact_identify_action.rb:121`. Rode as specs dele inteiras.

## Contexto

- **`ContactMergeAction`** (`app/actions/contact_merge_action.rb`):
  - move conversas, mensagens, `contact_inboxes` e notas para o contato base;
  - mescla os atributos (o base vence);
  - apaga o outro contato;
  - **não move etiquetas**.
  - O endpoint atual é `POST /api/v1/accounts/:id/actions/contact_merge` (`app/controllers/api/v1/accounts/actions/contact_merges_controller.rb`).
- **Telefone:** `contacts.phone_number` é único por conta e em E.164. Duplicados reais aparecem como formatos diferentes do mesmo número, sobretudo com e sem o nono dígito. O normalizador fica em `Rede::Phone` (003).
- **A tela** (017) é **só para administradores**.

## Decisões fechadas (não reinterpretar)

1. **Duplicado:**
   - Par de contatos **com participação ativa no mesmo projeto** cujos telefones são variantes um do outro (`Rede::Phone.variants`). A comparação é feita **só dentro do mesmo projeto**.
   - Pessoas de projetos diferentes **nunca** são sugeridas para juntar: é a fronteira pendente com o Lucas.
   - O par é ordenado (`contact_a_id < contact_b_id`).
2. **"Não são a mesma pessoa":** grava a resolução `dismissed` do par naquele projeto, e o par deixa de aparecer.
3. **"Juntar cadastros":**
   - O admin escolhe o contato base. O endpoint `POST .../rede/quality/merges { project_id, base_contact_id, mergee_contact_id }` chama o `ContactMergeAction` e grava a resolução `merged`.
   - O `ContactMergeAction` passa a **mover os dados `rede_*`** do contato absorvido para o base, **em todos os projetos**:
     - **participações:** se o base não participa daquele projeto, a participação muda de contato. Se os dois participam, fica a do base (os campos vazios do base são completados com os do outro), e as atuações, temperaturas e interações do outro passam para a participação e o contato do base. Atuações ativas que colidirem na mesma frente: fica a do base, e a do outro é encerrada;
     - **avaliações** e **interações:** mudam de `contact_id`;
     - **referências** (`referred_by_contact_id`, `superior_contact_id`) que apontavam para o absorvido passam a apontar para o base;
     - `last_contact_at` é recalculado (`Rede::LastContact::Recompute`) nas participações afetadas;
     - tudo **na mesma transação** do merge.
4. **Incompleto:** participação ativa no projeto com algum destes problemas, cada um como item separado:
   - `missing_name`: nome vazio;
   - `missing_phone`: telefone vazio;
   - `missing_city`: `additional_attributes.city` vazio;
   - `pending_front`: projeto com frentes ativas e nenhuma atuação ativa com frente.
5. **Resolvidos este mês:** conta as resoluções (`merged` e `dismissed`) do mês corrente, no fuso da conta.
6. **Só admin** em todas as rotas desta spec (para os outros, 401).

## Escopo

**Entra:**
- Migração `create_rede_quality_resolutions`:
  - `account_id`, `project_id`, `kind` (`merged: 0`, `dismissed: 1`);
  - `contact_a_id`, `contact_b_id` (integers, sem FK, porque o contato absorvido deixa de existir);
  - `resolved_by_user_id`;
  - timestamps;
  - índice único parcial `[project_id, contact_a_id, contact_b_id] WHERE kind = 1`.
- Model `Rede::QualityResolution`.
- `Rede::Quality::Duplicates` (pares por projeto, numa consulta: expandir as variantes em SQL ou comparar a chave normalizada; escolher e justificar).
- `Rede::Quality::Incompletes`.
- `Rede::Contacts::MergeRedeData` (chamado pelo `ContactMergeAction`).
- **API:**
  - `GET .../rede/quality?project_id=`: `{ duplicates: [...], incompletes: [...], counts: { duplicates, incompletes, resolved_this_month } }`;
  - `POST .../rede/quality/dismissals { project_id, contact_a_id, contact_b_id }`;
  - `POST .../rede/quality/merges`.
- Policy (só admin) e jbuilder.

**Fica de fora:**
- divergência de dados ("Dado diferente"), que é a fatia 3;
- duplicados entre projetos;
- mover etiquetas no merge (comportamento upstream, não muda);
- catálogo de campos.

## Comportamento esperado

- **Mesmo número, formatos diferentes:** contatos `+5581988887777` e `+558188887777` participando do PE aparecem como **um** par em `duplicates` do PE.
- **O mesmo par, mas um no PE e outro no PA:** não aparece.
- **Dismiss do par:** some da lista e `resolved_this_month` sobe 1. Repetir o dismiss: 200 idempotente.
- **Merge com o base A:**
  - o contato B deixa de existir;
  - as participações, atuações, temperaturas e interações de B estão em A;
  - nos projetos em que os dois participavam, há **uma** participação;
  - `last_contact_at` está correto;
  - a resolução `merged` foi gravada.
- **Merge com erro no meio** (forçado no teste): nada muda, porque o rollback é completo.
- **Incompletos:** Diego sem cidade aparece com `missing_city`; Bruna, no PE com frentes e sem atuação com frente, aparece com `pending_front`.
- **Agente:** 401 em tudo.
- **Merge pelo endpoint antigo** (`actions/contact_merge`) também move os dados `rede_*`.

## Testes primeiro

- `spec/services/rede/quality/duplicates_spec.rb`: variantes, só no mesmo projeto, dismiss exclui, par ordenado, sem auto-par.
- `spec/services/rede/quality/incompletes_spec.rb`: cada tipo.
- `spec/services/rede/contacts/merge_rede_data_spec.rb`: todos os casos da decisão 3, incluindo a colisão de atuação na mesma frente e as referências de superior e indicação.
- `spec/actions/contact_merge_action_spec.rb` (acrescentar): move os dados `rede_*`; o rollback completo; o comportamento antigo intacto.
- `spec/controllers/api/v1/accounts/rede/quality_controller_spec.rb`: por papel, mais os três endpoints.

## Arquivos a mudar

- `db/migrate/<ts>_create_rede_quality_resolutions.rb` (novo) e `db/schema.rb`.
- `app/models/rede/quality_resolution.rb` (novo).
- `app/services/rede/quality/{duplicates,incompletes}.rb` e `app/services/rede/contacts/merge_rede_data.rb` (novos).
- `app/actions/contact_merge_action.rb`: uma chamada, dentro da transação existente.
- `app/controllers/api/v1/accounts/rede/quality_controller.rb` (novo), `app/policies/rede/quality_policy.rb` (novo) e as views.
- `config/routes.rb` e `config/locales/en.yml`.
- Os specs.

## Casos de borda

- **Telefone fixo** (sem nono dígito possível): só compara exato.
- **Três contatos com o mesmo número normalizado:** três pares (A-B, A-C, B-C).
- **O contato absorvido era responsável de alguém?** Não se aplica: responsável é `user`, não contato.
- **Base e absorvido na mesma participação e na mesma frente**, com temperaturas diferentes: as duas linhas de histórico ficam, e a atual é a mais recente.

## Dependências

003, 004 e 005 (e 006, para o recálculo).

## Comandos de verificação

```
docker exec chatwoot-next-rails-1 bundle exec rails db:migrate
MSYS_NO_PATHCONV=1 docker exec -e RAILS_ENV=test chatwoot-next-rails-1 bundle exec rails db:drop db:create db:schema:load
MSYS_NO_PATHCONV=1 docker exec -e RAILS_ENV=test chatwoot-next-rails-1 bundle exec rspec spec/services/rede/quality spec/services/rede/contacts spec/actions/contact_merge_action_spec.rb spec/controllers/api/v1/accounts/rede/quality_controller_spec.rb
MSYS_NO_PATHCONV=1 docker exec -e RAILS_ENV=test chatwoot-next-rails-1 bundle exec rspec spec/actions/contact_identify_action_spec.rb spec/controllers/api/v1/accounts/actions
docker exec chatwoot-next-rails-1 bundle exec rubocop app/services/rede app/actions/contact_merge_action.rb app/controllers/api/v1/accounts/rede app/policies/rede
```

## Revisão

- [ ] Nenhuma sugestão de duplicado entre projetos.
- [ ] Merge atômico, sem linha `rede_*` órfã apontando para o contato apagado (conferir com uma consulta no teste).
- [ ] A mudança no `ContactMergeAction` é mínima e dentro da transação existente.
- [ ] Só admin.
- [ ] Resolvidos no mês no fuso da conta.

## Commit sugerido

`feat: aponta duplicados e cadastros incompletos no crm`
