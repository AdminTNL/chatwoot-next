# Spec 018: Front, painel do CRM na conversa

## Execução

Igual à 013:
- Fluxo TDD: testes, provar que falham, implementar, verificar, code review.
- Papéis: implementador `sonnet`, testador `haiku`, revisor `opus`.
- vitest no container com `TZ=UTC`, sem worktree.
- **Tem uma pequena mudança de backend** (decisão 2): rspec com `-e RAILS_ENV=test`.

## Contexto

- **Painel lateral da conversa:** `app/javascript/dashboard/routes/dashboard/conversation/ContactPanel.vue`.
  - É um `Draggable` sobre `conversationSidebarItems`.
  - Cada item tem um `element.name` (`conversation_actions`, `conversation_info`, `contact_attributes`, `previous_conversation`, `macros`, `contact_notes` e assim por diante) e um `AccordionItem`, que abre e fecha por `isContactSidebarItemOpen('is_..._open')` e `toggleSidebarUIState`.
  - A ordem padrão fica em `composables/useUISettings.js` (`DEFAULT_CONVERSATION_SIDEBAR_ITEMS_ORDER`). As ordens já salvas recebem os itens novos pelo laço da linha 47.
- **A conversa tem `team_id`** (derivado da inbox) e **o projeto tem `team_id`** (partial `_project` da 001).
- **Ficha (009):** `GET rede/people/:contact_id` devolve as participações visíveis, mas o `project` de cada participação **não traz `team_id`**.
- **Da 015 e da 016:** `TemperatureBadge`, `ProjectBadge`, `LastContact`, `TemperaturePicker`, `CallDialog` e `NoteDialog`.

## Decisões fechadas (não reinterpretar)

1. **Item novo `rede_crm`** no painel, com o título "CRM", **primeiro na ordem padrão**. Abre e fecha por `is_rede_crm_open`, aberto por padrão.
2. **Backend:** acrescentar `team_id` ao objeto `project` das participações em `GET rede/people/:contact_id` (009) e ajustar o teste da 009. **Não criar endpoint novo.**
3. **O projeto do painel** é o projeto cujo `team_id` é o `team_id` da conversa.
   - **Conversa sem time:** o painel mostra "Esta caixa não pertence a um projeto."
   - **Time sem projeto visível para o usuário:** não deveria acontecer (o agente só vê conversa do próprio time). Mostrar o mesmo aviso.
4. **A pessoa participa do projeto:** o painel mostra
   - a etiqueta do projeto (cor);
   - as atuações ativas, com a frente e a temperatura (`TemperatureBadge`, editável pelo `TemperaturePicker` quando a frente tem temperatura; em projeto sem frentes, a temperatura do projeto);
   - "Frente a definir", quando for o caso;
   - o responsável;
   - o próximo passo (editável na hora, salvo ao sair do campo);
   - o último contato.

   Ações: "Registrar ligação" (`CallDialog`, com o projeto já fixado), "Adicionar nota" e "Abrir ficha" (`rede_person`).
5. **A pessoa não participa do projeto** (o 404 da ficha, ou a ficha sem esse projeto): o texto "Fora do projeto X" e o botão "Adicionar ao projeto", que chama `POST rede/participations` com o `contact_id` e o projeto, sem frente. Depois, recarregar o painel.
6. **Trocar de conversa** recarrega o painel. As requisições obsoletas são ignoradas: a resposta de uma conversa anterior não pode sobrescrever o painel da atual.

## Escopo

**Entra:**
- o componente `rede/components/conversation/RedeConversationPanel.vue`;
- o item no `ContactPanel.vue` e no `useUISettings.js`;
- o `team_id` na resposta da 009;
- os textos.

**Fica de fora:** painel na lista de contatos nativa e ações em massa.

## Comportamento esperado

- **Conversa da Ana numa caixa do PE:** o painel "CRM" aparece primeiro, mostra o PE com Campo quente e o último contato. Registrar uma ligação dali atualiza o último contato no painel.
- **Conversa de um contato novo** numa caixa do PE: "Fora do projeto Mobiliza PE" e "Adicionar ao projeto". Depois de clicar, o painel mostra "Frente a definir" (se o PE tiver frentes).
- **Conversa numa caixa sem time:** o aviso.
- **Um usuário que já tinha reordenado o painel:** o item CRM aparece (no fim da ordem salva, pelo laço existente). Nada quebra.

## Testes primeiro

- **Backend:** `spec/controllers/api/v1/accounts/rede/people_controller_spec.rb` (acrescentar) testa que `participations[].project.team_id` está presente.
- **`rede/components/conversation/specs/RedeConversationPanel.spec.js`**, com a API mockada:
  - escolhe a participação pelo `team_id`;
  - os três estados (participa, não participa, sem time);
  - o botão adicionar envia o payload certo;
  - a troca rápida de conversa não mistura respostas (duas promessas, a primeira resolvida por último).
- **`composables/spec/useUISettings.spec.js`** (acrescentar): `rede_crm` está na ordem padrão e é acrescentado às ordens salvas antigas.

## Arquivos a mudar

- `app/views/api/v1/accounts/rede/people/show.json.jbuilder` (ou o partial usado) e o spec do controller.
- `app/javascript/dashboard/routes/dashboard/conversation/ContactPanel.vue`.
- `app/javascript/dashboard/composables/useUISettings.js` e o spec.
- `app/javascript/dashboard/routes/dashboard/rede/components/conversation/RedeConversationPanel.vue` (novo) e o spec.
- `i18n/locale/{en,pt_BR}/rede.json`.

## Casos de borda

- **Contato sem telefone** (por exemplo, e-mail): funciona igual.
- **Projeto encerrado:** mostra os dados, sem "Adicionar ao projeto" (a API recusaria).
- **Erro de rede:** mostrar "Não foi possível carregar o CRM" e "Tentar de novo", sem quebrar o resto do painel.

## Dependências

003 a 005, 009, 013, 015 e 016.

## Comandos de verificação

```
MSYS_NO_PATHCONV=1 docker exec -e RAILS_ENV=test chatwoot-next-rails-1 bundle exec rspec spec/controllers/api/v1/accounts/rede/people_controller_spec.rb
MSYS_NO_PATHCONV=1 docker exec -e TZ=UTC chatwoot-next-rails-1 sh -c 'cd /app && node_modules/.bin/vitest --no-watch --no-cache --no-coverage run RedeConversationPanel useUISettings'
pnpm eslint app/javascript/dashboard/routes/dashboard/rede app/javascript/dashboard/routes/dashboard/conversation/ContactPanel.vue app/javascript/dashboard/composables/useUISettings.js
```

Mais o percurso manual numa conversa do seeder, com prints no relatório.

## Revisão

- [ ] O projeto do painel vem do `team_id` da conversa, nunca de uma escolha livre.
- [ ] Nenhum dado de outro projeto no painel.
- [ ] As ordens salvas antigas continuam funcionando.
- [ ] Sem condição de corrida na troca de conversa.
- [ ] Mudança mínima no `ContactPanel.vue` (um `v-else-if` e o import).

## Commit sugerido

`feat: mostra painel do crm na conversa`
