# Spec 006: último contato por projeto

## Execução

Igual à 001:
- Fluxo TDD: testes, provar que falham, implementar, verificar, code review.
- Papéis: implementador `sonnet`, testador `haiku` (espera cada comando), revisor `opus` separado.
- rspec sempre com `-e RAILS_ENV=test`, sem worktree, branch saindo da `develop`.
- Parar e reportar se faltar arquivo de produção.
- `db/schema.rb` no commit.

Esta spec **toca o `Message`, que é caminho quente**. Medir o efeito e rodar `spec/models/message_spec.rb` inteiro. Se ficar lento, usar o atalho `fast.rb` de `.claude/lessons/rspec-must-run-with-rails-env-test.md`.

## Contexto

- **`conversations.team_id`** é derivado da inbox (`derive_team_from_inbox`, `app/models/conversation.rb:77,302-304`) e indexado. Projeto é time, então "conversa do projeto" é `conversation.team_id = project.team_id`.
- **Mensagens:** `message_type` é `incoming: 0, outgoing: 1, activity: 2, template: 3` (`app/models/message.rb:88`), e `private` é boolean.
- **Callback:** `Message#execute_after_create_commit_callbacks` (`app/models/message.rb:326-335`) já chama `update_contact_activity` (linhas 337-339), que atualiza `contacts.last_activity_at` da conta inteira. Esse campo **não serve**, porque não é por projeto.
- **Índice útil:** `(conversation_id, account_id, message_type, created_at)` em `messages`.
- A 005 deixou `Rede::LastContact::Touch` como no-op, chamado ao criar uma interação.

## Decisões fechadas (não reinterpretar)

1. **Último contato da pessoa num projeto** é o **maior** valor entre:
   - (a) o `created_at` da última mensagem `incoming`, **não privada**, enviada pelo contato (`sender_type = 'Contact'`), numa conversa com `team_id = project.team_id` e `contact_id = pessoa`;
   - (b) o `occurred_at` da última `Rede::Interaction` do tipo `call` com `answered = true` naquele projeto.
2. Mensagens enviadas pela equipe, mensagens privadas, atividades, ligação não atendida e notas **não contam**.
3. O valor fica gravado em `rede_participations.last_contact_at` (datetime, nullable, índice `[project_id, last_contact_at]`), para ordenar e filtrar na lista (008) e na visão geral (010).
4. **Atualização incremental:**
   - Mensagem incoming nova: atualiza as participações da pessoa **no projeto do time da conversa**, só se o valor novo for maior (`UPDATE ... SET last_contact_at = GREATEST(COALESCE(last_contact_at, '-infinity'), :t)`). Uma única query, sem carregar models.
   - Ligação atendida criada, ou editada para atendida: o mesmo, no projeto da interação.
   - Participação criada: calcula o valor inicial a partir do histórico (decisão 1).
   - Editar uma ligação de atendida para não atendida **recalcula** o valor daquela participação (pode diminuir).
5. **Backfill:** rake `rede:backfill_last_contact` (e serviço `Rede::LastContact::Recompute`) recalcula para todas as participações de uma conta ou de todas. Idempotente, em lotes.
6. A atualização **não pode quebrar a criação de mensagem**. Erro no cálculo é logado e não propagado. Fazer na própria transação do `after_create_commit`, com `rescue` e log, **ou** num job `low`.
   - **Escolha desta spec:** síncrono, uma query só, com `rescue`.
   - O revisor confere que é uma query só e sem lock longo.

## Escopo

**Entra:**
- Migração `add_last_contact_at_to_rede_participations`, com índice.
- `Rede::LastContact::Touch.new(contact_id:, project_id: nil, team_id: nil, at:).perform`: atualização incremental.
- `Rede::LastContact::Recompute.new(participations).perform`: recálculo pelo histórico.
- `Message`: na lista de `execute_after_create_commit_callbacks`, chamar `touch_rede_last_contact`. Ele só age quando `incoming? && !private? && sender.is_a?(Contact) && conversation.team_id.present?`.
- `Rede::Interaction`: completar o hook da 005 (criar e editar).
- `Rede::Participations::Create` (003): chamar `Recompute` na criação.
- `lib/tasks/rede.rake`: `rede:backfill_last_contact[account_id]`.
- O partial `_participation` passa a devolver `last_contact_at`.

**Fica de fora:** "último contato" na interface (015, 016, 018); qualquer mudança em `contacts.last_activity_at`.

## Comportamento esperado

- **Ana participa do PE (time 11).** Chega uma mensagem incoming dela numa conversa da inbox do time 11: `last_contact_at` do PE passa a ser o `created_at` da mensagem.
- **A mesma Ana também participa do PA (time 12):** o PA **não** muda.
- **A equipe responde (outgoing), ou grava uma nota privada:** nada muda.
- **Ligação atendida em PE com data anterior** ao último valor: nada muda. Com data posterior: atualiza.
- **Ligação não atendida:** nada muda.
- **Editar uma ligação atendida para não atendida**, sendo ela a mais recente: o valor volta para o próximo maior (mensagem ou outra ligação), ou para nulo.
- **Participação criada para quem já conversava** com o time: nasce com o valor certo.
- **Conversa numa inbox sem time:** não afeta nenhuma participação.
- **Exceção dentro do `Touch`:** a mensagem é criada normalmente e o erro vai para o log.
- **Backfill:** rodar duas vezes dá o mesmo resultado.

## Testes primeiro

- `spec/services/rede/last_contact/touch_spec.rb`: incremental, só aumenta, projeto certo, uma query.
- `spec/services/rede/last_contact/recompute_spec.rb`: combina mensagens e ligações, ignora outgoing, privadas, activity e não atendidas, pode voltar a nulo.
- `spec/models/message_spec.rb` (acrescentar): incoming do contato atualiza; outgoing e privada não; inbox sem time não; a exceção no `Touch` não impede a criação.
- `spec/models/rede/interaction_spec.rb` (acrescentar): criar e editar disparam o cálculo certo.
- `spec/services/rede/participations/create_spec.rb` (acrescentar): valor inicial.
- `spec/lib/tasks/rede_rake_spec.rb` (ou o teste do serviço chamado pela rake): idempotência.

## Arquivos a mudar

- `db/migrate/<ts>_add_last_contact_at_to_rede_participations.rb` (novo) e `db/schema.rb`.
- `app/services/rede/last_contact/touch.rb` (completar) e `app/services/rede/last_contact/recompute.rb` (novo).
- `app/models/message.rb`: um método privado e uma linha na lista de callbacks.
- `app/models/rede/interaction.rb`.
- `app/services/rede/participations/create.rb`.
- `lib/tasks/rede.rake` (novo).
- `app/views/api/v1/models/rede/_participation.json.jbuilder`.
- Os specs.

## Casos de borda

- **Contato que mudou de conversa entre times** (a inbox trocou de time, spec antiga 043): o cálculo usa o `team_id` **atual** da conversa. Aceito.
- **Mensagem importada com `created_at` antigo:** o `GREATEST` protege.
- **Pessoa sem participação em nenhum projeto:** o `UPDATE` não afeta nenhuma linha, e o custo é desprezível.
- **Testes antigos de `Message`** que usam `create(:message)` em massa: conferir que nada quebra e que o tempo do arquivo não sobe de forma relevante (anotar antes e depois no relatório).

## Dependências

003 e 005.

## Comandos de verificação

```
docker exec chatwoot-next-rails-1 bundle exec rails db:migrate
MSYS_NO_PATHCONV=1 docker exec -e RAILS_ENV=test chatwoot-next-rails-1 bundle exec rails db:drop db:create db:schema:load
MSYS_NO_PATHCONV=1 docker exec -e RAILS_ENV=test chatwoot-next-rails-1 bundle exec rspec spec/services/rede/last_contact spec/models/rede spec/services/rede/participations
MSYS_NO_PATHCONV=1 docker exec -e RAILS_ENV=test chatwoot-next-rails-1 bundle exec rspec spec/models/message_spec.rb
docker exec chatwoot-next-rails-1 bundle exec rubocop app/services/rede app/models/message.rb app/models/rede lib/tasks/rede.rake
```

## Revisão

- [ ] A mudança em `Message` é mínima, isolada num método e protegida por `rescue` com log.
- [ ] Uma query por mensagem, sem `find_each` nem carregar participações.
- [ ] As regras da decisão 1 estão exatas: tipo, privada, remetente contato, time da conversa.
- [ ] O caminho de diminuir (edição da ligação) recalcula corretamente.
- [ ] Rake idempotente e em lotes.
- [ ] `spec/models/message_spec.rb` verde, sem regressão de tempo relevante.

## Commit sugerido

`feat: calcula ultimo contato por projeto no crm`
