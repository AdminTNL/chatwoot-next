# Spec 016: Front, ficha da pessoa

## Execução

Igual à 013:
- Fluxo TDD: testes, provar que falham, implementar, verificar, code review.
- Papéis: implementador `sonnet`, testador `haiku`, revisor `opus`.
- vitest no container com `TZ=UTC`, sem worktree.

## Contexto

- **Da 013:** a casca `rede/pages/PersonPage.vue` (rota `rede_person`, parâmetro `contactId`) e a store `stores/rede/person.js`.
- **Da 015:** `TemperatureBadge`, `ProjectBadge` e `LastContact`.
- **APIs:**
  - ficha e histórico: 009;
  - participação e atuações: 003 (`PATCH participations/:id`, `POST/PATCH assignments`, `POST assignments/:id/close`);
  - temperatura: 004 (`POST evaluations`);
  - ligações e notas: 005 (`POST/PATCH interactions`, editar só o autor em até 24 h);
  - papéis: `GET roles`.
- **Nota da reunião:** "é importante ter ligação no histórico (ou registrar manualmente)" e "histórico em pessoas, com filtros por data".
- **A ficha nativa do contato** (`/contacts/:id`) continua existindo. A ficha do CRM tem um link para ela ("Ver contato").

## Decisões fechadas (não reinterpretar)

1. **Cabeçalho:**
   - nome, telefone, e-mail e cidade, com o link "Ver contato" (ficha nativa);
   - os botões "Registrar ligação" e "Adicionar nota".
2. **Um bloco por participação visível** (cada projeto), com a cor do projeto na borda ou na etiqueta:
   - **status** (etiqueta "Encerrada" quando for o caso);
   - **responsável:** seletor dos membros do time do projeto e dos admins, salva no `PATCH`;
   - **indicado por:** busca de contato ou texto livre;
   - **próximo passo:** texto, salva ao sair do campo;
   - **último contato:** `LastContact`;
   - **atuações ativas**, cada uma com:
     - frente;
     - papel (seletor);
     - superior (busca de contato);
     - **temperatura** (seletor dos 4 níveis mais "Sem temperatura", com uma nota opcional, que chama `POST evaluations`). O seletor só aparece em frente com `has_temperature`;
     - o botão "Encerrar atuação";
   - em **projeto sem frentes**, a temperatura fica no bloco do projeto (`project_temperature`);
   - **"Frente a definir"** em destaque quando `front_pending`, com o botão "Definir frente" (cria a atuação);
   - **"Adicionar atuação"**: frente (as ativas do projeto, que ainda não tenham atuação ativa) e papel.
3. **Registrar ligação**, num diálogo:
   - projeto (obrigatório; se a pessoa só tem um projeto visível, já vem escolhido);
   - frente (opcional);
   - data e hora (padrão agora, sem futuro);
   - "Atendeu?" (sim ou não, obrigatório);
   - resumo.

   "Quem ligou" é o usuário logado, mostrado só para leitura.
4. **Adicionar nota:** projeto, frente opcional e texto.
5. **Histórico** (`timeline`):
   - lista vertical do mais novo para o mais antigo;
   - **filtros:** projeto, período (de/até, com os atalhos 7 dias, 30 dias e 90 dias) e tipos (conversa, ligação, nota, temperatura, atuação);
   - **"Carregar mais"** pelo cursor `before`;
   - **cada tipo tem ícone e texto:**
     - conversa: "Conversa #123 em Caixa X", com link para a conversa;
     - ligação: atendida ou não, mais o resumo;
     - nota;
     - temperatura: "de quente para morno", com a nota;
     - atuação: iniciada ou encerrada, com papel e frente;
   - **editar** ligação e nota aparece só quando o autor é o usuário atual e faz menos de 24 h. Se a API recusar, mostrar a mensagem.
6. **Depois de qualquer ação**, recarregar a ficha e a primeira página do histórico.
7. **404 da API** (fora do escopo): a tela "Pessoa não encontrada ou sem acesso", com um link para voltar à lista.

## Escopo

**Entra:**
- a página;
- os componentes `rede/components/person/{PersonHeader,ParticipationCard,AssignmentRow,TemperaturePicker,CallDialog,NoteDialog,Timeline,TimelineFilters,TimelineEvent}.vue`;
- os textos.

`TemperaturePicker` e `CallDialog` são reaproveitados na 018.

**Fica de fora:** mesclar pela ficha (é na 017), exportar o histórico, anexos em nota.

## Comportamento esperado

- **Admin abre a Ana:** vê dois blocos, PE (Campo quente, Digital sem temperatura) e PA (frio no projeto).
- **Mudar Campo para morno com uma nota:** a etiqueta muda e o histórico ganha "de quente para morno".
- **Registrar uma ligação atendida no PE:** o último contato do PE vira agora, e a ligação aparece no topo do histórico. Uma ligação não atendida também aparece no histórico, mas não muda o último contato.
- **Filtrar os últimos 7 dias, só ligações:** a lista recorta.
- **Agente do PE abre a Ana:** só o bloco do PE e o histórico do PE.
- **Bruna** ("frente a definir"): o botão "Definir frente" cria a atuação, e o aviso some.

## Testes primeiro

- `rede/components/person/specs/TemperaturePicker.spec.js`: emite `{ level, note }`, com "Sem temperatura" como `null`; não aparece em frente sem `has_temperature` (testar no `AssignmentRow`).
- `rede/components/person/specs/CallDialog.spec.js`: obrigatórios (projeto, atendeu), data futura bloqueada, projeto pré-selecionado quando há um só, payload certo.
- `rede/components/person/specs/TimelineEvent.spec.js`: o texto e o ícone de cada tipo; "editar" visível só para o autor em até 24 h (`vi.setSystemTime`).
- `rede/components/person/specs/TimelineFilters.spec.js`: atalhos de período geram `from` e `to` certos (UTC no teste); tipos.
- `stores/rede/person.spec.js` (acrescentar): "carregar mais" concatena sem duplicar; uma ação recarrega a ficha e o histórico; 404 vira o estado `notFound`.

## Arquivos a mudar

- `app/javascript/dashboard/routes/dashboard/rede/pages/PersonPage.vue`.
- `app/javascript/dashboard/routes/dashboard/rede/components/person/*.vue` (novos) e os specs.
- `app/javascript/dashboard/stores/rede/person.js`.
- `i18n/locale/{en,pt_BR}/rede.json`.

## Casos de borda

- **Participação encerrada:** o bloco aparece esmaecido, sem os controles de edição e sem "Adicionar atuação". O histórico aparece.
- **Projeto encerrado:** igual a participação encerrada, mas o próximo passo e o responsável continuam editáveis (a API aceita).
- **Responsável que saiu do time:** aparece no seletor como "(fora do projeto)" até ser trocado.
- **Salvar o próximo passo com erro de rede:** manter o texto e mostrar o erro.

## Dependências

003, 004, 005, 009, 013 e 015.

## Comandos de verificação

```
MSYS_NO_PATHCONV=1 docker exec -e TZ=UTC chatwoot-next-rails-1 sh -c 'cd /app && node_modules/.bin/vitest --no-watch --no-cache --no-coverage run rede/components/person stores/rede'
pnpm eslint app/javascript/dashboard/routes/dashboard/rede app/javascript/dashboard/stores/rede
```

Mais o percurso manual com o seeder, como admin e como agente, com prints no relatório.

## Revisão

- [ ] Nada de outro projeto aparece para o agente (ficha e histórico).
- [ ] Temperatura só onde a regra da 004 permite: o front não deixa enviar o que a API recusaria.
- [ ] "Quem ligou" vem do usuário logado, não de um campo editável.
- [ ] O histórico pagina sem duplicar.
- [ ] Componentes reaproveitáveis para a 018.

## Commit sugerido

`feat: mostra ficha da pessoa no crm com historico e acoes`
