# Spec 005: ligações e notas (`Rede::Interaction`)

## Execução

Igual à 001:
- Fluxo TDD: testes, provar que falham, implementar, verificar, code review.
- Papéis: implementador `sonnet`, testador `haiku` (espera cada comando), revisor `opus` separado.
- rspec sempre com `-e RAILS_ENV=test`, sem worktree, branch saindo da `develop`.
- Parar e reportar se faltar arquivo de produção.
- `db/schema.rb` no commit.

## Contexto

- O Chatwoot não tem telefonia. A ligação é registrada à mão pelo operador.
- As notas nativas do contato (`notes`, `app/views/.../contacts/notes`) são por contato, sem projeto. **Não serão reaproveitadas:** a nota do CRM precisa de projeto, para respeitar a fronteira.
- O escopo de acesso é o `Rede::AccessScope`, da 003.

## Decisões fechadas (não reinterpretar)

1. Dois tipos: `call` (ligação, 0) e `note` (nota, 1).
2. **Ligação:**
   - `occurred_at` (data e hora, padrão agora), `author_user_id` (quem ligou: o usuário logado), `summary` (resumo, obrigatório) e `answered` (boolean, **obrigatório** em ligação).
   - Nota: `summary` obrigatório e `answered` nulo.
3. **Projeto:**
   - Sempre ligada a um projeto (`project_id` obrigatório).
   - O operador escolhe o projeto entre os projetos **em que a pessoa tem participação** e **que estão no escopo dele**. Fora disso, 422 ou 404.
   - `front_id` é opcional e, quando existe, é do mesmo projeto.
4. **Edição:** só o próprio autor pode editar `summary` e `answered`, e só nas primeiras 24 h. Não há exclusão. A ligação registrada errada vira uma nota de correção.
5. **Regra do último contato:** a ligação com `answered = true` conta como contato. Ela é aplicada na 006; esta spec só expõe um evento ou hook claro: `after_create_commit` chamando `Rede::LastContact::Touch`, que a 006 implementa. **Nesta spec, deixar o ponto de chamada atrás de um `respond_to?` ou criar o serviço como no-op**, para a 006 completar.

## Escopo

**Entra:**
- **Migração `create_rede_interactions`:**
  - `account_id`, `contact_id` (integer FK), `project_id`, `front_id` (nullable), `author_user_id`;
  - `kind` (integer, null: false);
  - `answered` (boolean, nullable);
  - `summary` (text, null: false);
  - `occurred_at` (null: false);
  - timestamps;
  - índice `[project_id, contact_id, occurred_at]`.
- **Model `Rede::Interaction`** com as validações.
- **API:**
  - `POST .../rede/interactions` com `{ contact_id, project_id, front_id, kind, answered, summary, occurred_at }`;
  - `PATCH .../rede/interactions/:id` (decisão 4);
  - `GET .../rede/interactions?contact_id=&project_id=` (no escopo, ordem decrescente).
- Policy e jbuilder `_interaction` (com `author: { id, name }`).

**Fica de fora:** linha do tempo combinada (009) e cálculo do último contato (006).

## Comportamento esperado

- **Ligação atendida de Carlos para Ana em PE:** 200; ela aparece no `GET`.
- **Ligação sem `answered`:** 422. Nota com `answered`: o valor é ignorado e gravado como nulo.
- **Projeto em que a pessoa não tem participação:** 422.
- **Projeto fora do escopo do operador:** 404.
- **Frente de outro projeto:** 422.
- **Edição:**
  - outro usuário edita: 401;
  - o autor edita depois de 24 h: 422;
  - o admin **não** tem exceção na edição. Registrar isso no relatório, para confirmar com o Fabio se o admin deveria poder.

## Testes primeiro

- `spec/models/rede/interaction_spec.rb`: validações por tipo, frente do projeto, participação existente.
- `spec/controllers/api/v1/accounts/rede/interactions_controller_spec.rb`: todos os casos acima, por papel, mais a janela de 24 h com `travel_to`.

## Arquivos a mudar

- `db/migrate/<ts>_create_rede_interactions.rb` (novo) e `db/schema.rb`.
- `app/models/rede/interaction.rb` (novo) e `app/models/contact.rb` (associação).
- `app/services/rede/last_contact/touch.rb` (novo, como no-op que a 006 completa).
- `app/controllers/api/v1/accounts/rede/interactions_controller.rb`, `app/policies/rede/interaction_policy.rb` e as views (novos).
- `config/routes.rb` e `config/locales/en.yml`.
- Os specs e `spec/factories/rede/interactions.rb`.

## Casos de borda

- `occurred_at` no futuro: 422.
- Ligação registrada para uma data passada é permitida, porque o operador anota depois.
- Participação encerrada: ainda aceita interação, para registrar a tentativa de retomada.

## Dependências

003.

## Comandos de verificação

```
docker exec chatwoot-next-rails-1 bundle exec rails db:migrate
MSYS_NO_PATHCONV=1 docker exec -e RAILS_ENV=test chatwoot-next-rails-1 bundle exec rails db:drop db:create db:schema:load
MSYS_NO_PATHCONV=1 docker exec -e RAILS_ENV=test chatwoot-next-rails-1 bundle exec rspec spec/models/rede/interaction_spec.rb spec/controllers/api/v1/accounts/rede/interactions_controller_spec.rb
docker exec chatwoot-next-rails-1 bundle exec rubocop app/models/rede app/services/rede app/controllers/api/v1/accounts/rede app/policies/rede
```

## Revisão

- [ ] Sem exclusão e com edição restrita ao autor e às 24 h.
- [ ] O projeto escolhido está entre os da pessoa **e** no escopo do operador.
- [ ] O hook para a 006 existe e não faz nada de errado sozinho.
- [ ] Sem uso das `notes` nativas do contato.

## Commit sugerido

`feat: registra ligacoes e notas por projeto no crm`
