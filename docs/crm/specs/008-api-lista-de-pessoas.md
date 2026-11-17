# Spec 008: API da lista de pessoas

## Execução

Igual à 001:
- Fluxo TDD: testes, provar que falham, implementar, verificar, code review.
- Papéis: implementador `sonnet`, testador `haiku` (espera cada comando), revisor `opus` separado.
- rspec sempre com `-e RAILS_ENV=test`, sem worktree, branch saindo da `develop`.
- **Parar e reportar** se faltar arquivo de produção. Endpoint sem escopo é vazamento entre projetos.

## Contexto

- Participação, atuação e `Rede::AccessScope` vêm da 003; a temperatura atual, de `Rede::Evaluations::Current` (004); `last_contact_at`, da 006.
- **Cidade é atributo nativo do contato** (`contacts.additional_attributes->>'city'`). Não há catálogo de campos nesta fatia.
- **Como modelo de API de lista paginada**, ver `ContactsController#index` (`app/controllers/api/v1/accounts/contacts_controller.rb`), com `page`, `@contacts_count` e `meta`.

## Decisões fechadas (não reinterpretar)

1. **Uma linha** por **participação ativa** × **atuação ativa**:
   - cada atuação ativa gera uma linha com a frente dela (nula se for "sem frente");
   - **participação ativa sem nenhuma atuação ativa** gera uma linha com frente nula e papel nulo.
2. **Campos da linha:**
   - `row_key` (`"<participation_id>-<assignment_id|none>"`);
   - `contact: { id, name, phone_number, city, avatar_url }`;
   - `project: { id, slug, name, color, status }`;
   - `front: { id, name } | null`;
   - `front_pending` (true quando o projeto tem frentes ativas e a linha está sem frente);
   - `role: { id, name } | null`;
   - `temperature` (`frio|morno|quente|vapor|null`);
   - `responsible: { id, name } | null`;
   - `last_contact_at`;
   - `next_step`;
   - `participation_id`, `assignment_id`.
3. **Temperatura da linha:**
   - em projeto **sem frentes ativas**, é a temperatura do projeto (frente nula);
   - em projeto **com frentes ativas**, é a temperatura daquela frente;
   - linha "frente a definir" fica com `temperature: null`.
4. **Filtros** (todos combináveis, em AND):
   - `project_ids[]`, `front_ids[]` (aceita `none` para "sem frente"), `temperatures[]` (aceita `none` para "sem temperatura"), `responsible_ids[]` (aceita `none`);
   - `city` (igual, sem diferenciar maiúsculas e acentos, se o banco permitir `unaccent`; se não permitir, só sem maiúsculas, e registrar no relatório);
   - `no_contact_days` (N): `last_contact_at` nulo **ou** anterior a agora − N dias;
   - `q`: nome (`ILIKE`) ou telefone (só dígitos, contém).
5. **Ordenação** (`sort`):
   - `last_contact_at` (padrão: crescente, com os nulos primeiro, porque mostra primeiro quem está esquecido), `-last_contact_at`, `name`, `-name`, `temperature`, `-temperature`;
   - desempate sempre por `row_key`.
6. **Paginação:** `page` (a partir de 1) e `per_page` (padrão 25, máximo 100), com `meta: { count, page, per_page }`. `count` é o número de **linhas**.
7. **Escopo:** admin vê todos os projetos; agente vê só as linhas de projetos do seu escopo. Um filtro por `project_ids` fora do escopo é ignorado (não dá erro e não traz dado).
8. **Projetos encerrados** só entram se `include_closed=true`. O padrão é só ativos.

## Escopo

**Entra:**
- `Rede::People::Query` (`app/services/rede/people/query.rb`): monta a relação das linhas com SQL composto (participações LEFT JOIN atuações ativas, joins com contato, projeto, frente, papel e responsável), aplica o escopo, os filtros, a ordenação e a paginação, e anexa a temperatura em lote via `Current`.
- `GET .../rede/people` (controller `rede/people_controller#index`) e o jbuilder `index` com `payload` + `meta`.
- `GET .../rede/people/filters`: opções de filtro **no escopo** do usuário, ou seja, os projetos (com as frentes) e os responsáveis possíveis (membros dos times desses projetos e admins).

**Fica de fora:** ficha (009), visão geral (010), exportação CSV, filtros salvos.

## Comportamento esperado

- **Ana** participa do PE com atuação em Campo e em Digital e também participa do PA (sem frentes): **3 linhas** (PE·Campo, PE·Digital, PA·—).
- **Bruna** participa do PE sem nenhuma atuação: 1 linha com `front: null`, `front_pending: true` e `temperature: null`.
- `temperatures[]=quente&project_ids[]=PE` traz só as linhas do PE com temperatura atual quente na frente.
- `temperatures[]=none` traz as linhas sem temperatura, incluindo as "frente a definir".
- `no_contact_days=7` traz quem tem `last_contact_at` nulo ou de mais de 7 dias.
- **Agente do PE:** não vê as linhas do PA da Ana. `meta.count` = 2 para ela.
- `per_page=2&page=2` traz a próxima página, sem repetir nem pular linhas (ordem estável).
- `q=8899` encontra pelo trecho do telefone.

## Testes primeiro

- `spec/services/rede/people/query_spec.rb`:
  - geração de linhas (decisão 1, com os exemplos acima);
  - temperatura por linha (decisão 3);
  - cada filtro isolado e combinado;
  - cada ordenação e o desempate;
  - paginação estável;
  - escopo;
  - `include_closed`;
  - **número de consultas constante** para 10 e para 50 pessoas.
- `spec/controllers/api/v1/accounts/rede/people_controller_spec.rb`: formato do payload, `meta`, escopo por papel, `filters` no escopo.

## Arquivos a mudar

- `app/services/rede/people/query.rb` (novo).
- `app/controllers/api/v1/accounts/rede/people_controller.rb` (novo; `index` e `filters` nesta spec, `show` e `timeline` na 009).
- `app/policies/rede/person_policy.rb` (novo; recurso virtual, usar `authorize :'rede/person'` ou o padrão do repo para recurso sem model).
- `app/views/api/v1/accounts/rede/people/{index,filters}.json.jbuilder` e `app/views/api/v1/models/rede/_person_row.json.jbuilder` (novos).
- `config/routes.rb` (`resources :people, only: [:index] { collection { get :filters } }`).
- Os specs.

## Casos de borda

- **Contato sem nome:** `name: null`. A interface trata.
- **Atuação ativa numa frente que depois foi encerrada:** a linha continua aparecendo com a frente (encerrada), para não sumir gente. **Não** marcar `front_pending`.
- **Responsável que deixou o time:** continua aparecendo como responsável. A troca é manual.
- **Ordenar por temperatura:** nulos por último no crescente e primeiro no decrescente. Documentar no teste.
- **Busca com caracteres especiais** (`%`, `_`): escapar.

## Dependências

003, 004 e 006.

## Comandos de verificação

```
MSYS_NO_PATHCONV=1 docker exec -e RAILS_ENV=test chatwoot-next-rails-1 bundle exec rspec spec/services/rede/people spec/controllers/api/v1/accounts/rede/people_controller_spec.rb
docker exec chatwoot-next-rails-1 bundle exec rubocop app/services/rede/people app/controllers/api/v1/accounts/rede app/policies/rede
```

## Revisão

- [ ] O escopo é aplicado **antes** dos filtros e da contagem; `meta.count` nunca conta linhas fora do escopo.
- [ ] Sem N+1: temperatura, responsável, frente e papel em lote.
- [ ] O SQL usa parâmetros (nada de interpolação de `params`).
- [ ] Índices usados nos filtros principais (`project_id, status`, `project_id, last_contact_at`); `EXPLAIN` no relatório para o caso padrão.
- [ ] Ordenação estável e paginação sem duplicar.
- [ ] Filtro de projeto fora do escopo ignorado silenciosamente.

## Commit sugerido

`feat: lista pessoas por projeto e frente no crm`
