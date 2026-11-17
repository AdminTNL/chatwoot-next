# Spec 015: Front, página Pessoas

## Execução

Igual à 013:
- Fluxo TDD: testes, provar que falham, implementar, verificar, code review.
- Papéis: implementador `sonnet`, testador `haiku`, revisor `opus`.
- vitest no container com `TZ=UTC`, sem worktree.

## Contexto

- **Da 013:** a casca `rede/pages/PeoplePage.vue`, a store `stores/rede/people.js`, o helper `peopleQuery` e as cores de `temperature.js`.
- **A API:** lista e filtros na 008; adicionar pessoa ao projeto na 003 (`POST rede/participations`, por `contact_id` ou por nome e telefone, com a primeira atuação opcional).
- **Tabela:** `components-next/table/BaseTable.vue`. Procurar no repo um uso com paginação para seguir; a paginação é a mesma de Contacts.
- **Notas da reunião:**
  - "na tabela de contato, cada linha de uma cor representando a temperatura";
  - "cada projeto ser diferenciado por cor";
  - "último contato: a resposta da pessoa deve ser para o último contato".

## Decisões fechadas (não reinterpretar)

1. **Colunas:**
   - Pessoa: nome, com o telefone embaixo, e link para `rede_person`;
   - Projeto: etiqueta na **cor do projeto**;
   - Frente: o nome, ou "Frente a definir" em destaque de aviso quando `front_pending`, ou "—" em projeto sem frentes;
   - Papel;
   - Temperatura: etiqueta com o rótulo;
   - Responsável;
   - Último contato: data relativa, **em vermelho quando passar de 7 dias ou for nulo** ("Nunca");
   - Próximo passo: truncado, com o texto completo no tooltip.
2. **A linha inteira tem um fundo suave da temperatura** (classes de fundo da 013). Sem temperatura, o fundo fica neutro. A coluna Temperatura sempre mostra o rótulo.
3. **Filtros numa barra acima da tabela**, todos refletidos na URL:
   - Projeto (multi);
   - Frente (multi, agrupada por projeto, com "Sem frente");
   - Temperatura (multi, com "Sem temperatura");
   - Responsável (multi, com "Sem responsável");
   - Cidade (texto);
   - "Sem contato há" (7, 15, 30 dias ou personalizado);
   - Busca (nome ou telefone, com debounce de 300 ms).

   As opções vêm de `GET people/filters`. Há o botão "Limpar filtros".
4. **Ordenação** pelo cabeçalho em Pessoa, Temperatura e Último contato. O padrão é o da API.
5. **Paginação** de 25 por página, com o total ("123 linhas"). Lembrar que **linha não é pessoa**: o texto de ajuda diz "Uma pessoa aparece uma vez por frente em que atua."
6. **"Adicionar pessoa"** abre um diálogo com dois modos:
   - **contato existente:** busca pela API de contatos (`/contacts/search`);
   - **pessoa nova:** nome, telefone e cidade.

   Depois: projeto (obrigatório, do escopo), frente (opcional, só as ativas do projeto), papel (opcional), responsável (opcional) e próximo passo.

   Ao salvar, chama `POST rede/participations` e recarrega a lista. Se a API achar contato pelo telefone (regra do nono dígito), ela usa esse contato, e a interface avisa: "Encontramos Ana Souza com esse telefone. Ela foi adicionada ao projeto."
7. **Estado vazio:**
   - sem filtros: "Ninguém neste projeto ainda", com o botão de adicionar;
   - com filtros: "Nenhuma pessoa com esses filtros", com "Limpar filtros".

## Escopo

**Entra:**
- a página;
- os componentes `rede/components/people/{PeopleTable,PeopleFilters,AddPersonDialog,TemperatureBadge,ProjectBadge,LastContact}.vue`;
- os textos.

`TemperatureBadge`, `ProjectBadge` e `LastContact` são reaproveitados na 016 e na 018.

**Fica de fora:** edição na linha, exportação, filtros salvos e ações em massa.

## Comportamento esperado

- **Abrir com `?temperatures=quente&project_ids=1`:** os filtros vêm preenchidos e a lista já filtrada.
- **Trocar um filtro:** a URL muda, a página volta para 1 e a lista recarrega.
- **A Ana com três atuações** aparece em três linhas, cada uma com a sua frente e a sua cor.
- **Último contato de 9 dias atrás:** em vermelho. Nulo: "Nunca", em vermelho.
- **Adicionar uma pessoa nova no PE, frente Campo:** ela aparece na lista.
- **Agente:** os filtros só oferecem os projetos dele.

## Testes primeiro

- `rede/components/people/specs/TemperatureBadge.spec.js`: rótulo e classe por nível, nulo como "Sem temperatura".
- `rede/components/people/specs/LastContact.spec.js`: relativo, vermelho com mais de 7 dias e com nulo (usar uma data fixa, `vi.setSystemTime`).
- `rede/components/people/specs/PeopleFilters.spec.js`: emite os parâmetros certos, "Limpar" zera, debounce da busca.
- `rede/components/people/specs/AddPersonDialog.spec.js`: validação (projeto obrigatório; no modo novo, nome ou telefone), payload enviado em cada modo, frentes recarregadas ao trocar de projeto.
- `stores/rede/people.spec.js` (acrescentar, se preciso): mudança de filtro zera a página.

## Arquivos a mudar

- `app/javascript/dashboard/routes/dashboard/rede/pages/PeoplePage.vue`.
- `app/javascript/dashboard/routes/dashboard/rede/components/people/*.vue` (novos) e os specs.
- `app/javascript/dashboard/stores/rede/people.js`, se preciso.
- `i18n/locale/{en,pt_BR}/rede.json`.

## Casos de borda

- **Contato sem nome:** mostrar o telefone como título.
- **Frente encerrada com atuação ativa:** mostrar o nome com "(encerrada)".
- **Projeto encerrado** (com `include_closed`): a etiqueta do projeto vem esmaecida. A opção "Incluir projetos encerrados" fica no filtro de projeto.
- **Erro 422 ao adicionar** (por exemplo, já participa): mostrar a mensagem da API no diálogo.
- **Tema escuro:** fundos de linha legíveis.

## Dependências

003, 008 e 013.

## Comandos de verificação

```
MSYS_NO_PATHCONV=1 docker exec -e TZ=UTC chatwoot-next-rails-1 sh -c 'cd /app && node_modules/.bin/vitest --no-watch --no-cache --no-coverage run rede/components/people stores/rede'
pnpm eslint app/javascript/dashboard/routes/dashboard/rede app/javascript/dashboard/stores/rede
```

Mais o percurso manual com o seeder (019), com prints no relatório (tema claro e escuro).

## Revisão

- [ ] Linha colorida **e** rótulo de temperatura. Nada depende só da cor.
- [ ] Filtros na URL; recarregar a página mantém a lista.
- [ ] Debounce na busca, sem uma requisição por tecla.
- [ ] O diálogo usa a resposta da API (contato encontrado pelo telefone), sem lógica de duplicado no front.
- [ ] Componentes reaproveitáveis exportados para a 016 e a 018.

## Commit sugerido

`feat: lista pessoas do crm com cores filtros e cadastro`
