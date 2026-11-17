# Spec 013: Front, área CRM (estrutura)

## Execução

- Fluxo TDD (000):
  1. testes;
  2. provar que falham;
  3. implementar;
  4. verificar;
  5. code review.
- Papéis: implementador `sonnet`, testador `haiku` (espera cada comando), revisor `opus` separado.
- vitest no container, com `TZ=UTC`, só nos arquivos tocados. Sem worktree, branch saindo da `develop`.

## Contexto

- **Rotas do dashboard:** `routes/dashboard/dashboard.routes.js` junta `contactRoutes`, `companyRoutes` e assim por diante. O modelo de módulo é `routes/dashboard/companies/routes.js` com `pages/`.
- **Sidebar:** `components-next/sidebar/Sidebar.vue`. O item Contacts (por volta das linhas 644 a 710) é o modelo de seção com filhos.
- **Permissões:** são checadas pelo `meta.permissions` da rota (`sidebar/provider.js:105-146`).
- **Stores Pinia:** `createStore` de `store/storeFactory.js` (exemplo: `stores/companies.js`).
- **i18n:** `rede.json`, criado na 012 (chave `REDE`).
- **APIs:** lista (008), filtros (008), ficha e histórico (009), visão geral (010), qualidade (011); papéis, participações, atuações, avaliações e interações (003 a 005).

## Decisões fechadas (não reinterpretar)

1. **Seção "CRM" na sidebar principal**, com o ícone `i-lucide-contact-round` ou parecido, e os filhos:
   - "Visão geral" (`rede_overview`);
   - "Pessoas" (`rede_people`);
   - "Qualidade dos dados" (`rede_quality`), **só para admin**: o item nem aparece para agente.
2. **Rotas** em `accounts/:accountId/crm/...`:
   - `crm/overview` → `rede_overview`;
   - `crm/people` → `rede_people`;
   - `crm/people/:contactId` → `rede_person`;
   - `crm/quality` → `rede_quality`.

   Permissões: `['administrator', 'agent']` em todas, menos `rede_quality`, que é `['administrator']`. `crm` redireciona para `rede_overview`.
3. **API clients** em `api/rede/`, um por recurso: `people.js` (index, filters, show, timeline), `overview.js`, `quality.js` (get, dismiss, merge), `participations.js`, `assignments.js`, `evaluations.js`, `interactions.js` e `roles.js`. A 012 já criou `projects.js` e `fronts.js`; reaproveitar.
4. **Stores Pinia** em `stores/rede/`:
   - `people.js`: lista, `meta`, filtros atuais e opções de filtro;
   - `person.js`: ficha, histórico paginado e ações (temperatura, ligação, nota, atuação, participação);
   - `overview.js`;
   - `quality.js`.

   Cada uma tem `uiFlags` como `stores/companies.js`.
5. **Filtros da lista na URL** (query string), para que um link compartilhado mostre a mesma lista e a visão geral possa abrir a lista já filtrada (010, decisão 2). Um helper `rede/helpers/peopleQuery.js` converte nos dois sentidos, entre `route.query` e os parâmetros da API.
6. **Constantes de temperatura** em `rede/helpers/temperature.js`:
   - ordem `vapor`, `quente`, `morno`, `frio`, `none`;
   - rótulo i18n;
   - classes Tailwind de **fundo** (linha) e de **etiqueta**, das cores semânticas do design system: vapor `n-ruby`, quente `n-amber`, morno `n-teal` ou `n-blue`, frio `n-slate`, sem temperatura neutra.

   **A cor nunca vem sozinha**: há sempre o rótulo junto.
7. **Páginas** ficam nesta spec como **cascas**, com título, layout e estado vazio. O conteúdo vem nas specs 014 a 017.

## Escopo

**Entra:** rotas, sidebar, clients, stores, os helpers, os textos e as páginas casca.

**Fica de fora:** o conteúdo das páginas (014 a 017) e o painel da conversa (018).

## Comportamento esperado

- **Agente:** vê "CRM" com Visão geral e Pessoas. Abrir `/crm/quality` na mão leva para a tela de sem permissão, pelo comportamento padrão das rotas.
- **Admin:** vê os três itens.
- **`peopleQuery`:** `{ project_ids: [1,2], temperatures: ['none'], no_contact_days: 7, page: 2 }` vira a query `?project_ids=1,2&temperatures=none&no_contact_days=7&page=2` e volta igual.

## Testes primeiro

- `api/specs/rede/*.spec.js`: URL, verbo e parâmetros de cada client novo.
- `stores/rede/*.spec.js`: as ações, as `uiFlags` e o tratamento de erro (padrão de `stores/companies.spec.js`).
- `routes/dashboard/rede/helpers/specs/peopleQuery.spec.js`: ida e volta, com arrays vazios e valores inválidos ignorados.
- `routes/dashboard/rede/helpers/specs/temperature.spec.js`: a ordem, e todo nível tem rótulo e classes.

## Arquivos a mudar

- `app/javascript/dashboard/routes/dashboard/rede/routes.js` (novo) e o registro em `dashboard.routes.js`.
- `app/javascript/dashboard/routes/dashboard/rede/pages/{OverviewPage,PeoplePage,PersonPage,QualityPage}.vue` (cascas).
- `app/javascript/dashboard/routes/dashboard/rede/helpers/{peopleQuery,temperature}.js` e os specs.
- `app/javascript/dashboard/api/rede/*.js` e os specs.
- `app/javascript/dashboard/stores/rede/*.js` e os specs.
- `components-next/sidebar/Sidebar.vue`.
- `i18n/locale/{en,pt_BR}/rede.json`.

## Casos de borda

- **Conta sem projetos:** as cascas mostram o estado vazio "Nenhum projeto ainda" e, para o admin, um link para criar projeto.
- **Trocar de conta:** as stores são limpas (seguir o que as stores atuais fazem na troca).

## Dependências

008 a 011 e 012 (`rede.json`, `projects.js`).

## Comandos de verificação

```
MSYS_NO_PATHCONV=1 docker exec -e TZ=UTC chatwoot-next-rails-1 sh -c 'cd /app && node_modules/.bin/vitest --no-watch --no-cache --no-coverage run rede'
pnpm eslint app/javascript/dashboard/routes/dashboard/rede app/javascript/dashboard/api/rede app/javascript/dashboard/stores/rede app/javascript/dashboard/components-next/sidebar/Sidebar.vue
```

## Revisão

- [ ] Qualidade invisível e inacessível para agente.
- [ ] Filtros da lista na URL, com ida e volta testada.
- [ ] Cores de temperatura com rótulo e tokens do design system (sem hex solto).
- [ ] Nenhuma string sem i18n.

## Commit sugerido

`feat: cria area do crm com rotas stores e clientes de api`
