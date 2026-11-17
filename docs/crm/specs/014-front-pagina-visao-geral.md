# Spec 014: Front, página Visão geral

## Execução

Igual à 013:
- Fluxo TDD: testes, provar que falham, implementar, verificar, code review.
- Papéis: implementador `sonnet`, testador `haiku`, revisor `opus`.
- vitest no container com `TZ=UTC`, sem worktree.

## Contexto

- A casca `rede/pages/OverviewPage.vue` e a store `stores/rede/overview.js` vêm da 013. A API é a 010, que devolve contagens, `by_temperature`, `recent_changes` e `filters` por cartão.
- **Notas da reunião:**
  - "Por temperatura: filtrar por projeto";
  - "Visão geral: semáforo (não entra agora)";
  - mostrar a quantidade de pessoas e as participações em frentes;
  - quem não tem temperatura também aparece.
- **Apresentação de referência:** `apresentacao-crm-no-chatwoot.html`, tela de visão geral, na pasta de análises.

## Decisões fechadas (não reinterpretar)

1. **Topo:** seletor de projeto ("Todos os projetos" ou um projeto do escopo, com a bolinha de cor), que muda `?project_id=` na URL.
2. **Quatro cartões:**
   - Pessoas (`people_count`);
   - Participações em frentes (`front_participations_count`);
   - Frente a definir (`pending_front_count`);
   - Sem contato há 7 dias ou mais (`no_contact_7d_count`, em destaque de alerta quando for maior que 0).

   **Cada cartão leva** para `rede_people` com a query montada a partir de `filters.<cartão>` (via `peopleQuery`, da 013).
3. **"Por temperatura":** barras horizontais (ou uma lista com barra proporcional), na ordem vapor, quente, morno, frio, sem temperatura.
   - Cada barra mostra o rótulo, a contagem e a cor da 013.
   - Clicar abre a lista filtrada por aquela temperatura e pelo projeto selecionado.
   - Sem biblioteca de gráfico nova: Tailwind basta.
4. **"O que mudou esta semana":** lista dos `recent_changes`, com a pessoa (link para `rede_person`), o tipo, o projeto e a frente com a cor, e o tempo relativo. Estado vazio: "Nada mudou nos últimos 7 dias."
5. **Sem semáforo, sem demandas.**

## Escopo

**Entra:** a página, os componentes `rede/components/overview/{StatCard,TemperatureBars,RecentChanges}.vue` e os textos.

**Fica de fora:** gráficos de evolução e exportação.

## Comportamento esperado

- **Admin sem filtro:** números da conta toda.
- **Escolher PE:** a URL ganha `project_id`; os números e as barras são do PE.
- **Clicar em "Sem contato há 7 dias":** abre Pessoas com `no_contact_days=7` (e o projeto, se houver), e a lista mostra **exatamente** esse número em `meta.count`.
- **Agente:** o seletor só lista os projetos dele.

## Testes primeiro

- `rede/components/overview/specs/TemperatureBars.spec.js`: ordem, largura proporcional (0 não quebra), "sem temperatura" presente, clique emite o nível.
- `rede/components/overview/specs/StatCard.spec.js`: rótulo, número e destino do link.
- `stores/rede/overview.spec.js`, se a 013 não cobriu: troca de projeto refaz a busca.

## Arquivos a mudar

- `app/javascript/dashboard/routes/dashboard/rede/pages/OverviewPage.vue`.
- `app/javascript/dashboard/routes/dashboard/rede/components/overview/*.vue` (novos) e os specs.
- `i18n/locale/{en,pt_BR}/rede.json`.

## Casos de borda

- **Tudo zero:** cartões com 0 e barras vazias, sem divisão por zero.
- **`project_id` na URL fora do escopo** (a API dá 404): limpar o filtro e mostrar um aviso discreto.
- **Carregando:** um esqueleto nos cartões.

## Dependências

010 e 013.

## Comandos de verificação

```
MSYS_NO_PATHCONV=1 docker exec -e TZ=UTC chatwoot-next-rails-1 sh -c 'cd /app && node_modules/.bin/vitest --no-watch --no-cache --no-coverage run rede/components/overview'
pnpm eslint app/javascript/dashboard/routes/dashboard/rede
```

Mais o percurso manual com o seeder (019), com prints no relatório.

## Revisão

- [ ] Os números do cartão e da lista batem (conferir na mão com o seeder).
- [ ] Sem semáforo.
- [ ] Cor sempre acompanhada de rótulo; contraste no tema escuro.
- [ ] Nenhuma lib nova.

## Commit sugerido

`feat: mostra visao geral do crm com cartoes e temperaturas`
