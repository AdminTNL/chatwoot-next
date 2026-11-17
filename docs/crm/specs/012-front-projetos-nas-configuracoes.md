# Spec 012: Front, Projetos nas configurações

## Execução

- Fluxo TDD (000):
  1. testes;
  2. provar que falham;
  3. implementar;
  4. verificar;
  5. code review.
- Papéis: implementador `sonnet`, testador `haiku` (espera cada comando), revisor `opus` separado.
- vitest no container, com `TZ=UTC`, só nos arquivos tocados. Sem worktree, branch saindo da `develop`.
- Parar e reportar se faltar arquivo.
- Usar `components-next`, Tailwind sem CSS próprio, `<script setup>` e Composition API. Não usar Vuex novo.

## Contexto

- **Configurações de times** ficam em `app/javascript/dashboard/routes/dashboard/settings/teams/`:
  - `teams.routes.js`, com as rotas `settings_teams_list`, `settings_teams_new`, `settings_teams_add_agents`, `settings_teams_finish`, `settings_teams_show`, `settings_teams_edit` e `settings_teams_edit_members`;
  - `Index.vue`, a lista com o botão de apagar;
  - `TeamForm.vue`, com nome, descrição, ícone e `icon_color`;
  - `Create/`, `Edit/` e `AgentSelector.vue`.
- **i18n:** `i18n/locale/{en,pt_BR}/teamsSettings.json` (`TEAMS_SETTINGS.*`); a sidebar usa `SIDEBAR.TEAMS` em `en/settings.json:346`.
- **Sidebar:** `components-next/sidebar/Sidebar.vue`.
  - Por volta da linha 484 fica a seção "Teams" das conversas, que filtra conversas por time.
  - Por volta da linha 855 fica o item "Teams" das configurações.
- **Backend:**
  - API `rede/projects` (001), incluindo `create`, que cria time e projeto juntos, e `close`/`reopen`;
  - frentes (002);
  - tokens (007);
  - `DELETE /teams/:id` agora dá 422.
- **Cliente de API:** os existentes ficam em `app/javascript/dashboard/api/` (base `ApiClient.js`, com `accountScoped: true`). A store Pinia segue `stores/companies.js` com `createStore` de `store/storeFactory.js`.

## Decisões fechadas (não reinterpretar)

1. **Nomenclatura "Projetos" na interface.**
   - Onde a interface diz "Times"/"Teams" referindo-se ao time, passa a dizer "Projetos"/"Projects": configurações, seção da sidebar de conversas, filtros e atribuição de conversa.
   - A mudança é **só de texto**, nos arquivos `en` e `pt_BR`. Nomes de rota, chaves de i18n e código continuam `team`.
   - **Desvio consciente da regra do AGENTS.md** ("só `en.json`"): este fork é usado em português, e a troca de termo não faz sentido só em inglês. Mexer **só** em `en` e `pt_BR`. As outras línguas ficam como estão.
2. **Lista de projetos** (`settings_teams_list`):
   - passa a ler de `GET rede/projects`;
   - mostra uma bolinha com a cor, o nome de exibição, o status (etiqueta "Encerrado" quando for o caso), o número de membros e o número de caixas;
   - filtro "Mostrar encerrados", desligado por padrão;
   - o botão de **apagar some** e no lugar entra **"Encerrar"** (com confirmação) ou **"Reativar"**.
3. **Criar projeto** usa `POST rede/projects`. Campos:
   - nome;
   - cor (seletor com a paleta de 8 cores da 001 e campo hex);
   - descrição.

   O passo seguinte (adicionar agentes) continua o atual, com o `team_id` devolvido.
4. **Editar projeto** usa `PATCH rede/projects/:id`, com nome, cor e descrição.
   - O **slug aparece só para leitura**, com botão de copiar e o texto "Identificador usado por ferramentas externas. Não muda."
   - Os membros continuam pela tela atual (`settings_teams_edit_members`).
5. **Frentes**, uma aba ou seção na edição do projeto:
   - lista com nome, "tem temperatura" e status;
   - criar e editar pelo diálogo com nome e o checkbox "tem temperatura";
   - "Encerrar" e "Reativar";
   - o `public_id` aparece só para leitura, com botão de copiar.
6. **Tokens de API**, uma página nova nas configurações, "Integrações do CRM" (rota `settings_rede_api_tokens`, só para admin, item no menu de configurações logo depois de "Projetos"):
   - lista com nome, prefixo, criado por, último uso e status;
   - "Criar token" abre um diálogo com o nome. O valor aparece **uma vez**, num campo com botão de copiar e o aviso "Guarde agora. Ele não será mostrado de novo.";
   - "Revogar" pede confirmação.
7. **Só o admin** vê e usa todas essas telas (já é assim nas rotas de times).

## Escopo

**Entra:**
- API clients `api/rede/projects.js`, `api/rede/fronts.js` e `api/rede/apiTokens.js`.
- Stores Pinia `stores/rede/projects.js` (com as frentes aninhadas, ou numa `stores/rede/fronts.js`) e `stores/rede/apiTokens.js`.
- Mudanças em `settings/teams/*`, a página nova de tokens e os textos.
- O arquivo novo `i18n/locale/{en,pt_BR}/rede.json` (chave raiz `REDE`), registrado no `index.js` de cada língua.

**Fica de fora:**
- área CRM (013 em diante);
- mudar nomes de rota;
- outras línguas.

## Comportamento esperado

- **Admin abre Configurações → Projetos:** vê os projetos ativos com cor; liga "Mostrar encerrados" e vê os encerrados com a etiqueta.
- **Criar "Mobiliza PE" com uma cor:** vai para o passo de agentes; a lista mostra o nome com maiúsculas.
- **Encerrar um projeto:** pede confirmação; o projeto some da lista padrão. Não existe mais botão de apagar.
- **Na edição:** o slug aparece só para leitura e copia com um clique.
- **Frentes:** criar "Campo" com temperatura e "Digital" sem; encerrar "Digital".
- **Tokens:** criar, ver o valor uma vez, fechar o diálogo; o valor não aparece mais. Revogar.
- **Em pt_BR,** a sidebar de conversas mostra "Projetos" no lugar de "Times".

## Testes primeiro

- `api/specs/rede/projects.spec.js`, `fronts.spec.js` e `apiTokens.spec.js`: URLs e verbos (padrão de `api/specs/*.spec.js`).
- `stores/rede/projects.spec.js` e `apiTokens.spec.js`: as ações chamam a API e atualizam o estado (`fetch`, `create`, `update`, `close`, `reopen`; para tokens, `create` guarda o valor só num campo efêmero, `lastCreatedToken`, que `clearLastCreated` limpa).
- Componente, se houver precedente de teste de componente em `settings/`: o formulário valida nome obrigatório e cor hex. Se não houver precedente, extrair a validação para um helper e testar o helper.

## Arquivos a mudar

- `app/javascript/dashboard/api/rede/{projects,fronts,apiTokens}.js` (novos) e os specs.
- `app/javascript/dashboard/stores/rede/{projects,apiTokens}.js` (novos) e os specs.
- `app/javascript/dashboard/routes/dashboard/settings/teams/{Index.vue,TeamForm.vue,Create/CreateTeam.vue,Edit/EditTeam.vue}`.
- `app/javascript/dashboard/routes/dashboard/settings/teams/Edit/Fronts.vue` (novo, ou componente equivalente) e o diálogo de frente.
- `app/javascript/dashboard/routes/dashboard/settings/rede/` (novo): `ApiTokens.vue` e `rede.routes.js`, registrado em `settings/settings.routes.js`.
- `components-next/sidebar/Sidebar.vue`: item de tokens nas configurações.
- `i18n/locale/{en,pt_BR}/{teamsSettings,settings,rede}.json` e `i18n/locale/{en,pt_BR}/index.js`, mais outros textos de "Team"/"Times" que o implementador encontrar (**listar no relatório** cada chave trocada).

## Casos de borda

- **Criar com nome já usado:** mostrar o erro 422 da API, sem travar o fluxo.
- **Cor inválida digitada:** validação local e na API.
- **Projeto encerrado:** a edição continua possível (nome e cor). As frentes também podem ser vistas.
- **Copiar sem `navigator.clipboard`:** usar o helper de cópia que o repo já tiver (`copyTextToClipboard`, se existir).

## Dependências

001, 002 e 007.

## Comandos de verificação

```
MSYS_NO_PATHCONV=1 docker exec -e TZ=UTC chatwoot-next-rails-1 sh -c 'cd /app && node_modules/.bin/vitest --no-watch --no-cache --no-coverage run api/specs/rede stores/rede'
pnpm eslint app/javascript/dashboard/api/rede app/javascript/dashboard/stores/rede app/javascript/dashboard/routes/dashboard/settings/teams app/javascript/dashboard/routes/dashboard/settings/rede
```

Mais o percurso manual no navegador (dev), com um print de cada tela no relatório.

## Revisão

- [ ] Nenhum botão de apagar projeto em lugar nenhum.
- [ ] Textos só em `en` e `pt_BR`, sem string solta no template.
- [ ] O valor do token não fica na store depois de fechar o diálogo, nem em `localStorage`.
- [ ] Nomes de rota e chaves mantidos (nada quebra o upstream mais do que o necessário).
- [ ] `components-next` e Tailwind; nenhum CSS novo com escopo.

## Commit sugerido

`feat: troca times por projetos nas configuracoes com frentes e tokens`
