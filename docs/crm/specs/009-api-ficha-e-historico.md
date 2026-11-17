# Spec 009: API da ficha da pessoa e do histórico

## Execução

Igual à 001:
- Fluxo TDD: testes, provar que falham, implementar, verificar, code review.
- Papéis: implementador `sonnet`, testador `haiku` (espera cada comando), revisor `opus` separado.
- rspec sempre com `-e RAILS_ENV=test`, sem worktree, branch saindo da `develop`.
- **Parar e reportar** se faltar arquivo de produção.

## Contexto

- **De onde vem cada dado:**
  - participação, atuação e escopo: 003;
  - temperatura e histórico: 004;
  - ligações e notas: 005;
  - último contato: 006.
- **Conversas do projeto:** `Conversation` com `contact_id` e `team_id` (derivado da inbox). Campos úteis: `display_id`, `status`, `inbox_id`, `last_activity_at`, `created_at`. O último resumo de mensagem pode vir de `Conversation#last_incoming_message` (`app/models/conversation.rb:159-161`) ou de uma subquery em lote; evitar N+1.
- **A ficha nativa do contato** (`ContactsController#show`) continua existindo e não muda.

## Decisões fechadas (não reinterpretar)

1. **A ficha mostra só os projetos do escopo do usuário.** Se a pessoa não tem nenhuma participação visível para o usuário, `show` e `timeline` respondem **404**, mesmo que o contato exista e tenha conversas em outros times.
2. **`GET .../rede/people/:contact_id` devolve:**
   - `contact: { id, name, phone_number, email, city, avatar_url }`;
   - `participations: [...]`, uma por projeto visível, com:
     - `id`, `project: { id, slug, name, color, status, has_fronts }`;
     - `status`, `joined_at`, `origin`;
     - `responsible`, `referred_by: { contact: {id,name} | null, text }`, `next_step`, `last_contact_at`;
     - `assignments`: as ativas, cada uma com `id`, `front`, `role`, `superior: {id,name}|null`, `started_at` e `temperature` atual (da frente, ou do projeto quando ele não tem frentes);
     - `project_temperature`: só em projeto sem frentes;
     - `front_pending`.
3. **`GET .../rede/people/:contact_id/timeline` devolve eventos ordenados do mais novo para o mais antigo**, com paginação por cursor (`before` = ISO8601, `limit` padrão 30, máximo 100). Cada evento é `{ type, occurred_at, project: {id,name,color}, front: {id,name}|null, author: {id,name}|null, data }`. Tipos:
   - `conversation`: `data` = `{ conversation_id, display_id, inbox: {id,name}, status, last_incoming_at }`; `occurred_at` = `last_activity_at` da conversa. **Uma entrada por conversa**, não por mensagem.
   - `call`: `data` = `{ interaction_id, answered, summary }`.
   - `note`: `data` = `{ interaction_id, summary }`.
   - `temperature_change`: `data` = `{ evaluation_id, from, to, note }`, onde `from` é o nível anterior no mesmo contexto.
   - `assignment_change`: `data` = `{ assignment_id, action: started|closed, role, front }`.
4. **Filtros do histórico:** `project_id` (um projeto visível), `from` e `to` (datas, inclusivas, no fuso da conta, com UTC como padrão se a conta não tiver fuso), `types[]`.
5. **Só entram conversas cujo `team_id` é o time de um projeto visível.** Conversas em inbox sem time ou de outro time **nunca** aparecem.

## Escopo

**Entra:**
- `Rede::People::Profile` (monta o `show`) e `Rede::People::Timeline` (`UNION ALL` das fontes, ou consultas por tipo mescladas em Ruby com limite; escolher o que for mais simples **e** sem N+1, e justificar no relatório).
- As ações `show` e `timeline` no `rede/people_controller`.
- Views jbuilder: `show`, `timeline` e os partials de evento.

**Fica de fora:** edição (já existe nas APIs da 003 a 005); exportação.

## Comportamento esperado

- **Admin abre a Ana:** vê PE (com duas atuações e as temperaturas por frente) e PA (sem frentes, com `project_temperature`).
- **Agente do PE abre a Ana:** vê só PE. O histórico não traz nada do PA, nem a conversa do PA.
- **Agente do PA abre a Bruna,** que só participa do PE: 404.
- **Linha do tempo:** uma conversa do PE, duas ligações (uma não atendida), uma nota e duas mudanças de temperatura. Tudo em ordem; `from`/`to` recortam; `types[]=call` traz só as ligações.
- **`temperature_change`** mostra `from: quente, to: morno` e, na primeira mudança, `from: null`.
- **Paginação por cursor:** sem repetição entre páginas, inclusive com dois eventos no mesmo instante (desempatar por tipo e id).

## Testes primeiro

- `spec/services/rede/people/profile_spec.rb`: estrutura completa, escopo, projeto com e sem frentes, `front_pending`.
- `spec/services/rede/people/timeline_spec.rb`: cada tipo, ordem, cursor com empate, filtros, exclusão de conversas de outros times e de inbox sem time, número de consultas constante.
- `spec/controllers/api/v1/accounts/rede/people_controller_spec.rb` (acrescentar): `show` e `timeline` por papel, com 404 fora do escopo.

## Arquivos a mudar

- `app/services/rede/people/profile.rb` e `app/services/rede/people/timeline.rb` (novos).
- `app/controllers/api/v1/accounts/rede/people_controller.rb` (ações `show` e `timeline`).
- `app/views/api/v1/accounts/rede/people/{show,timeline}.json.jbuilder` e os partials em `app/views/api/v1/models/rede/` (novos).
- `config/routes.rb` (`member { get :timeline }`; o `:id` é o `contact_id`).
- Os specs.

## Casos de borda

- **Contato de outra conta:** 404.
- **Participação encerrada:** aparece na ficha com `status: closed`, e o histórico dela também.
- **Atuação encerrada:** some de `assignments` (só as ativas), mas aparece no histórico como `assignment_change` `closed`.
- **Datas `from` > `to`:** 422.

## Dependências

003, 004, 005 e 006.

## Comandos de verificação

```
MSYS_NO_PATHCONV=1 docker exec -e RAILS_ENV=test chatwoot-next-rails-1 bundle exec rspec spec/services/rede/people spec/controllers/api/v1/accounts/rede/people_controller_spec.rb
docker exec chatwoot-next-rails-1 bundle exec rubocop app/services/rede/people app/controllers/api/v1/accounts/rede
```

## Revisão

- [ ] Nenhuma conversa, ligação, nota ou temperatura de projeto fora do escopo, nem no `show` nem no `timeline`. Testar com a mesma pessoa em dois projetos.
- [ ] 404 quando não há participação visível.
- [ ] O cursor é estável com empates.
- [ ] Sem N+1 por evento.
- [ ] O fuso dos filtros de data está documentado e testado.

## Commit sugerido

`feat: expoe ficha e historico da pessoa no crm`
