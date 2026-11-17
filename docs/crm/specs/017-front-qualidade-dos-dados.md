# Spec 017: Front, Qualidade dos dados

## Execução

Igual à 013:
- Fluxo TDD: testes, provar que falham, implementar, verificar, code review.
- Papéis: implementador `sonnet`, testador `haiku`, revisor `opus`.
- vitest no container com `TZ=UTC`, sem worktree.

## Contexto

- **Da 013:** a casca `rede/pages/QualityPage.vue` (só admin) e a store `stores/rede/quality.js`.
- **API (011):**
  - `GET rede/quality?project_id=`, com `duplicates`, `incompletes` e `counts`;
  - `POST rede/quality/dismissals`;
  - `POST rede/quality/merges`.
- **Apresentação de referência:** a tela "Qualidade dos dados" de `apresentacao-crm-no-chatwoot.html`, com os cartões de número e a lista de pendências por tipo. **Nesta fatia** só entram duplicados e incompletos; "Dado diferente" (divergência) fica fora.

## Decisões fechadas (não reinterpretar)

1. **Topo:** o seletor de projeto (obrigatório escolher um; o padrão é o primeiro ativo), porque **duplicado só existe dentro do projeto**.
2. **Três cartões:** Possíveis duplicados, Cadastros incompletos e Resolvidos este mês.
3. **Lista "Possíveis duplicados":** cada par mostra as duas pessoas lado a lado, com nome, telefone, cidade, data de criação e número de conversas, se a API mandar. As ações são:
   - **"Juntar cadastros":** abre a confirmação, em que o admin escolhe **qual fica** (o base). O texto avisa: "O outro cadastro será apagado. Conversas, histórico e participações passam para o que fica. Não dá para desfazer.";
   - **"Não são a mesma pessoa":** chama `dismissals` e tira o par da lista.
4. **Lista "Cadastros incompletos":** cada item mostra a pessoa, o problema ("Sem cidade", "Sem telefone", "Sem nome" ou "Frente a definir") e a ação:
   - campos nativos → "Completar": um diálogo pequeno com o campo que falta, que salva pela API de contatos existente (`PATCH /contacts/:id`; cidade em `additional_attributes.city`);
   - "Frente a definir" → "Abrir ficha" (`rede_person`).
5. Depois de cada ação, recarregar as listas e os números.

## Escopo

**Entra:**
- a página;
- os componentes `rede/components/quality/{QualityStats,DuplicatePair,MergeDialog,IncompleteItem,CompleteFieldDialog}.vue`;
- os textos.

**Fica de fora:** divergência, duplicados entre projetos, desfazer o merge e mescla em massa.

## Comportamento esperado

- **Admin escolhe PE:** vê o par Ana Souza e Ana S. (mesmo número com e sem o nono dígito).
- **"Não são a mesma pessoa":** o par some e "Resolvidos este mês" sobe 1.
- **"Juntar" com base Ana Souza:** o par some, a lista de pessoas passa a mostrar uma só Ana, e a ficha dela tem o histórico das duas.
- **Diego sem cidade → "Completar" → "Recife":** o item some.
- **Agente:** nem vê o item no menu, e a rota bloqueia (013).

## Testes primeiro

- `rede/components/quality/specs/MergeDialog.spec.js`: exige escolher o base; o payload `{ project_id, base_contact_id, mergee_contact_id }` está certo; o aviso de irreversível está presente.
- `rede/components/quality/specs/DuplicatePair.spec.js`: emite `dismiss` e `merge`.
- `rede/components/quality/specs/IncompleteItem.spec.js`: ação certa por tipo de problema.
- `rede/components/quality/specs/CompleteFieldDialog.spec.js`: cidade vai para `additional_attributes.city` sem apagar os outros atributos.
- `stores/rede/quality.spec.js` (acrescentar): depois de cada ação, recarrega.

## Arquivos a mudar

- `app/javascript/dashboard/routes/dashboard/rede/pages/QualityPage.vue`.
- `app/javascript/dashboard/routes/dashboard/rede/components/quality/*.vue` (novos) e os specs.
- `app/javascript/dashboard/stores/rede/quality.js`.
- `i18n/locale/{en,pt_BR}/rede.json`.

## Casos de borda

- **Projeto sem pendências:** "Nada para resolver neste projeto."
- **Erro no merge:** mostrar a mensagem e manter o par (a API faz rollback).
- **Completar o telefone com um número que já existe** em outro contato (422 da API de contatos): mostrar "Esse telefone já é de outra pessoa." e sugerir o merge se as duas estiverem no projeto.

## Dependências

011 e 013.

## Comandos de verificação

```
MSYS_NO_PATHCONV=1 docker exec -e TZ=UTC chatwoot-next-rails-1 sh -c 'cd /app && node_modules/.bin/vitest --no-watch --no-cache --no-coverage run rede/components/quality stores/rede'
pnpm eslint app/javascript/dashboard/routes/dashboard/rede app/javascript/dashboard/stores/rede
```

Mais o percurso manual com o seeder, com prints no relatório.

## Revisão

- [ ] Merge com confirmação explícita, escolha do base e aviso de irreversível.
- [ ] Nenhuma sugestão entre projetos (a tela sempre tem um projeto escolhido).
- [ ] "Completar" não apaga outros `additional_attributes`.
- [ ] Só admin.

## Commit sugerido

`feat: mostra qualidade dos dados do crm com juntar e completar`
