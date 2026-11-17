# Spec 021: Revisão final da fatia 1

## Execução

- **Não implementa funcionalidade.** É o code review do conjunto e o percurso de aceitação.
- **Papéis:**
  - revisor `opus`, que não participou de nenhuma implementação da fatia;
  - testador `haiku` para as suítes;
  - correções pontuais pelo implementador `sonnet`, uma por commit (`fix: ...`), cada uma com o teste que reproduz o problema **antes** da correção.
- Só começa com 001 a 020 em `develop/concluidas/`.

## Contexto

- **A visão geral e as decisões** estão na 000.
- **O seeder** é a 019, e **a homologação** é a 020.
- **O risco principal da fatia** é o **vazamento entre projetos**: um agente ver pessoa, conversa, ligação, nota, temperatura ou contagem de um projeto do qual não faz parte.

## O que revisar

1. **Escopo em todos os endpoints `rede/*`** (lista, filtros, ficha, histórico, visão geral, participações, atuações, avaliações, interações, qualidade).
   - Montar uma tabela endpoint × papel (admin, agente do PE, agente do PA, agente dos dois) × resultado esperado.
   - Conferir que há um teste para cada célula, ou acrescentar o que faltar.
2. **API externa (007):**
   - token só como hash;
   - 401 genérico;
   - nada de pessoa na resposta;
   - `Authorization` filtrado no log;
   - ETag.
3. **Migrações:**
   - todas reversíveis (`rails db:rollback STEP=n` e `db:migrate` de novo no dev);
   - só de acréscimo;
   - `db/schema.rb` coerente com a soma delas.
4. **Desempenho:**
   - lista, ficha e visão geral com número de consultas constante (os testes existem);
   - `EXPLAIN` da lista com o seeder;
   - o callback de mensagem (006) não adiciona mais que uma consulta por mensagem recebida.
5. **Mudanças em código upstream**, mínimas e listadas: `Team`, `TeamsController#destroy`, `Message`, `ContactMergeAction`, `ContactPanel.vue`, `useUISettings.js`, `Sidebar.vue`, as telas de times e os textos.
6. **Front:**
   - nenhuma string sem i18n;
   - textos só em `en` e `pt_BR`;
   - `components-next` e Tailwind;
   - a cor nunca sem rótulo;
   - tema escuro legível.
7. **Commits** no padrão de `.claude/rules/commits.md`: uma linha, em português e **sem nenhuma atribuição**.

## Percurso de aceitação (na homologação, com o seeder)

Fazer como admin, depois como `agente.pe`, `agente.pa` e `agente.ambos`, anotando o resultado de cada passo:

1. **Configurações → Projetos:**
   - os dois projetos com cor;
   - o slug só para leitura;
   - as frentes do PE;
   - "Encerrar" no lugar de apagar.

   Para os agentes, a tela não aparece.
2. **CRM → Visão geral:**
   - os números com "Todos" e por projeto;
   - clicar em cada cartão leva à lista com o mesmo total.
3. **CRM → Pessoas:**
   - a pessoa com três atuações aparece em três linhas;
   - as cores das linhas com rótulo;
   - a etiqueta do projeto na cor dele;
   - os filtros (cada um) e a URL compartilhável;
   - o último contato em vermelho depois de 7 dias.
4. **Ficha:**
   - mudar a temperatura de uma frente;
   - registrar uma ligação atendida (o último contato muda);
   - registrar uma não atendida (não muda);
   - adicionar uma nota;
   - o histórico com filtro de data e tipo;
   - "Definir frente" para quem estava "a definir".
5. **Conversa:**
   - responder pelo número de teste da Evolution: o último contato do projeto daquela caixa atualiza;
   - uma nota privada não atualiza;
   - o painel CRM mostra o projeto certo;
   - "Adicionar ao projeto" para um contato novo.
6. **Qualidade (admin):**
   - o duplicado do PE aparece e o par entre projetos não;
   - "Não são a mesma pessoa";
   - "Juntar", conferindo a ficha resultante;
   - completar a cidade.
7. **API externa:**
   - criar um token;
   - `curl` em `GET /api/rede/v1/projects`;
   - renomear o projeto: o `id` (slug) continua o mesmo;
   - revogar: 401.
8. **Isolamento:**
   - como `agente.pa`, tentar abrir pela URL a ficha de uma pessoa só do PE (sem acesso), um `project_id` do PE na visão geral (404) e a qualidade (bloqueada);
   - como `agente.ambos`, ver os dois.

## Suítes

```
MSYS_NO_PATHCONV=1 docker exec -e RAILS_ENV=test chatwoot-next-rails-1 bundle exec rspec spec/models/rede spec/services/rede spec/controllers/api/v1/accounts/rede spec/controllers/api/rede spec/lib/seeders/rede spec/actions/contact_merge_action_spec.rb spec/controllers/api/v1/accounts/teams_controller_spec.rb spec/models/team_spec.rb spec/models/message_spec.rb spec/swagger/openapi_spec.rb
MSYS_NO_PATHCONV=1 docker exec -e TZ=UTC chatwoot-next-rails-1 sh -c 'cd /app && node_modules/.bin/vitest --no-watch --no-cache --no-coverage run rede useUISettings'
docker exec chatwoot-next-rails-1 bundle exec rubocop app/models/rede app/services/rede app/controllers/api/v1/accounts/rede app/controllers/api/rede app/policies/rede lib/seeders/rede
pnpm eslint app/javascript/dashboard/routes/dashboard/rede app/javascript/dashboard/api/rede app/javascript/dashboard/stores/rede
```

Uma falha que já existia antes da fatia é registrada com a autoria (`.claude/lessons/falhas-preexistentes-exigem-rastreio-de-autoria.md`), sem ser corrigida aqui.

## Pendências a levar ao Fabio (não decidir na revisão)

- Admin pode editar ligação ou nota de outra pessoa? (005, decisão 4: hoje não pode.)
- Checagem de ciclo de indicação (003): ficou só registrada?
- `rack-attack` na API externa (007): existe ou ficou pendente?
- `AI_SUGGESTION_SERVICE_URL` na homologação (020): o que foi encontrado.

## Entregáveis

- O relatório de revisão em `develop/concluidas/021-relatorio.md`, com a tabela de escopo, o resultado do percurso (passo a passo, com prints) e a lista de correções feitas.
- As correções em commits `fix: ...`.
- **A recomendação "pode ir para a `main`" ou "não pode"**, com o motivo.

## Revisão

- [ ] A tabela de escopo está completa e cada célula tem teste.
- [ ] O percurso foi feito com os quatro usuários.
- [ ] As suítes estão verdes, com as falhas preexistentes rastreadas.
- [ ] As pendências foram listadas para o Fabio.

## Commit sugerido

Nenhum próprio. As correções seguem `fix: <descrição>`.
