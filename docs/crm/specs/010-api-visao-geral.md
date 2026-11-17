# Spec 010: API da visão geral

## Execução

Igual à 001:
- Fluxo TDD: testes, provar que falham, implementar, verificar, code review.
- Papéis: implementador `sonnet`, testador `haiku` (espera cada comando), revisor `opus` separado.
- rspec sempre com `-e RAILS_ENV=test`, sem worktree, branch saindo da `develop`.
- Parar e reportar se faltar arquivo de produção.

## Contexto

- As linhas da lista de pessoas e a regra de temperatura por linha estão em `Rede::People::Query` (008). **Reaproveitar essa regra**, sem reescrevê-la.
- A tela (014) mostra:
  - cartões de números;
  - "Por temperatura", com filtro de projeto;
  - "O que mudou esta semana".
- O semáforo de saúde fica fora. Demandas ficam fora da fatia.

## Decisões fechadas (não reinterpretar)

1. `GET .../rede/overview?project_id=` (opcional, sempre restrito ao escopo; sem projeto, considera todos os projetos visíveis e ativos) devolve:
   - `people_count`: contatos **distintos** com participação ativa.
   - `front_participations_count`: atuações ativas **com frente**.
   - `pending_front_count`: linhas "frente a definir".
   - `no_contact_7d_count`: participações ativas com `last_contact_at` nulo ou de mais de 7 dias.
   - `by_temperature`: `{ vapor, quente, morno, frio, none }`. A **unidade é a linha da lista** (pessoa × projeto × frente), com a mesma regra da 008.
   - `recent_changes`: os 10 eventos mais recentes dos últimos 7 dias, no escopo: mudança de temperatura, participação nova e atuação iniciada. O formato é o mesmo dos eventos da 009, com `contact: {id,name}` acrescentado.
2. Cada número é **clicável** na interface. A resposta inclui, para cada cartão, os parâmetros de filtro equivalentes da 008. Exemplo: `filters.no_contact_7d = { no_contact_days: 7, project_ids: [...] }`. Assim os números da visão geral e o resultado da lista não divergem.
3. **Escopo:** agente vê só os seus projetos. Um `project_id` fora do escopo dá 404.

## Escopo

**Entra:**
- `Rede::Overview::Summary`, que reaproveita `Rede::People::Query` (contagens via `count` e `group` sobre a mesma relação, sem paginação) e os eventos da `Rede::People::Timeline` ou uma consulta própria em lote.
- `GET .../rede/overview` (controller `rede/overview_controller#show`), mais o jbuilder.

**Fica de fora:** semáforo, demandas, gráficos de evolução.

## Comportamento esperado

- **Com os dados da 008** (Ana em PE·Campo, PE·Digital e PA; Bruna em PE sem atuação), como admin, sem filtro:
  - `people_count` = 2;
  - `front_participations_count` = 2;
  - `pending_front_count` = 1;
  - `by_temperature` soma 4 linhas.
- **`project_id=PA`:** só os números do PA.
- **Agente do PE:** os números só do PE; `project_id=PA` dá 404.
- **Os números batem com a lista:** para cada cartão, chamar a 008 com `filters.*` dá `meta.count` igual ao número do cartão. Isso é o teste de contrato entre as duas APIs.

## Testes primeiro

- `spec/services/rede/overview/summary_spec.rb`: cada número; o teste de contrato com `Rede::People::Query`; os eventos recentes no escopo e na janela de 7 dias.
- `spec/controllers/api/v1/accounts/rede/overview_controller_spec.rb`: por papel e por projeto.

## Arquivos a mudar

- `app/services/rede/overview/summary.rb` (novo).
- `app/controllers/api/v1/accounts/rede/overview_controller.rb` (novo), mais a policy (pode reusar `Rede::PersonPolicy`).
- `app/views/api/v1/accounts/rede/overview/show.json.jbuilder` (novo).
- `config/routes.rb` (`resource :overview, only: :show`).
- Os specs.

## Casos de borda

- **Conta sem projetos:** tudo zero e `recent_changes: []`.
- **Projeto encerrado:** fora do padrão. Com `project_id` de um projeto encerrado, mostra os números dele.

## Dependências

004, 006 e 008.

## Comandos de verificação

```
MSYS_NO_PATHCONV=1 docker exec -e RAILS_ENV=test chatwoot-next-rails-1 bundle exec rspec spec/services/rede/overview spec/controllers/api/v1/accounts/rede/overview_controller_spec.rb
docker exec chatwoot-next-rails-1 bundle exec rubocop app/services/rede/overview app/controllers/api/v1/accounts/rede
```

## Revisão

- [ ] A regra das linhas e da temperatura vem da 008, não duplicada.
- [ ] O teste de contrato de cada cartão contra a lista existe e passa.
- [ ] Contagens em SQL (`count`/`group`), sem carregar registros.
- [ ] O escopo é aplicado em todas as contagens e nos eventos.

## Commit sugerido

`feat: expoe numeros da visao geral do crm`
