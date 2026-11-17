# CRM (módulo Rede), fatia 1: visão geral

Documento de orientação do conjunto **001 a 021**. **Não é uma spec executável**: nada é implementado a partir daqui. Ele serve para quem coordena escolher a ordem e para cada agente entender onde sua spec se encaixa.

## Problema

A Central acompanha pessoas da rede (pontos focais, mobilizadores, entrevistadores) em vários projetos. Hoje isso vive em planilhas e na memória da equipe. O Chatwoot já tem as conversas, os contatos e os times. Falta a camada de acompanhamento:
- quem está em qual projeto e frente, com qual papel;
- qual a temperatura dessa pessoa;
- quem é o responsável e qual o próximo passo;
- quando foi o último contato;
- o que aconteceu com ela.

A fatia 1 entrega essa camada **só com dados do próprio Chatwoot e cadastro manual**. Não há integração com outros sistemas.

## Arquitetura

```
Time (teams)  ──1:1──  Projeto (rede_projects)
 │                       ├── Frentes (rede_fronts)            [opcional: projeto sem frentes é válido]
 │                       └── Participações (rede_participations)   uma por pessoa e projeto
 │                             ├── responsável (users), quem indicou, próximo passo, último contato
 │                             └── Atuações (rede_assignments)  pessoa numa frente (ou sem frente), papel, superior
 ├── Caixas de entrada (inboxes.team_id)  → conversas (conversations.team_id derivado da inbox)
 └── Membros (team_members)  → quem é membro do time é agente do projeto

Pessoa = Contato (contacts), sem tabela nova.
Temperatura (rede_evaluations): por pessoa + projeto + frente (frente nula em projeto sem frentes). Histórico, nunca sobrescreve.
Interações (rede_interactions): ligação (com "atendeu") e nota, manuais.
Papéis (rede_roles): catálogo por conta.
Tokens de leitura (rede_api_tokens): para ferramentas externas lerem os projetos.
Qualidade (rede_quality_resolutions): pares de duplicados resolvidos ("juntados" ou "não são a mesma pessoa").
```

**Namespace:** classes `Rede::*` e tabelas `rede_*`. O namespace `Crm::` já existe (`app/services/crm/`, integração LeadSquared do upstream) e fica intocado. Na interface, a área se chama **CRM**.

## Decisões de produto fechadas (não reabrir)

1. **Todo time é um projeto**, numa relação 1:1 (`rede_projects.team_id` único).
   - Na interface, "Times" vira "Projetos". No código e no banco continua `teams`.
   - O nome de exibição, a cor, o status e o slug ficam em `rede_projects`. `Team#name` é guardado em minúsculas (`app/models/team.rb:38-41`) e vira detalhe interno.
2. **Só o administrador cria e edita projetos e frentes.** Ferramentas externas só leem.
3. **Projeto e frente nunca são apagados, só encerrados.** O "apagar time" deixa de existir na interface e na API (vira "Encerrar").
4. **Slug do projeto é o id público, imutável.** A frente tem um `public_id` (uuid) imutável. Renomear não muda a referência guardada por outra ferramenta.
5. **Acesso:**
   - Admin vê todos os projetos.
   - Agente vê só os projetos de cujo time é membro.
   - Não existe tela de vínculo agente × projeto: o vínculo é ser membro do time.
6. **Atuação sem frente é permitida.** Em projeto sem frentes é o normal. Em projeto com frentes quer dizer "frente a definir".
7. **Temperatura:**
   - É por frente. Em projeto sem frentes, é por projeto (frente nula).
   - Escala: frio, morno, quente, vapor. "Sem temperatura" é um estado válido.
   - Pode alterar: o admin ou qualquer membro do projeto, mesmo que não seja o responsável.
8. **A temperatura do CRM é independente das etiquetas de temperatura atuais** (etiquetas por time, `label_groups`, specs 015 e 029). Nada sincroniza nesta fatia; a ligação entre as duas fica para a Etapa 3.
9. **Ligação registrada à mão:**
   - Campos: data, quem ligou, resumo e se a pessoa atendeu.
   - Sempre ligada a um projeto, que o operador escolhe entre os projetos da pessoa dos quais ele faz parte.
10. **Último contato é por projeto.** É o maior valor entre:
    - a última mensagem **recebida** da pessoa (não privada) numa conversa do time do projeto;
    - a última ligação **atendida** registrada no projeto.

    Ligação não atendida aparece no histórico, mas não conta.
11. **Lista de pessoas:**
    - Uma linha por pessoa, projeto e frente. A pessoa aparece mais de uma vez se estiver em mais de um projeto ou frente.
    - Cor da linha pela temperatura, sempre com o rótulo junto.
    - Etiqueta do projeto na cor dele.
12. **Visão geral:**
    - Mostra pessoas (contatos distintos) e participações em frentes, separadas.
    - Mostra "sem contato há 7 dias ou mais".
    - "Por temperatura" tem filtro por projeto e inclui "sem temperatura".
    - O semáforo de saúde fica fora.
13. **Histórico da ficha:** conversas do projeto, ligações, notas e mudanças de temperatura, com filtro de data.
14. **Qualidade dos dados, só para administradores:**
    - **Duplicado:** mesmo telefone normalizado, com a regra do nono dígito brasileiro, **só dentro do mesmo projeto**. Juntar pessoas de projetos diferentes, com dado real, é decisão de fronteira pendente com o Lucas.
    - **Incompleto:** só campos nativos do contato (nome, telefone, cidade) e "frente a definir".
    - Sem divergência e sem catálogo de campos nesta fatia.
15. **Painel do CRM ao lado da conversa** entra nesta fatia.
16. **API de leitura de projetos para ferramentas externas** (primeiro consumidor: os formulários do Abib):
    - token próprio, guardado como hash, revogável, só de leitura;
    - rota fora de `/api/v1/accounts`, desenhada como se fosse outro serviço;
    - as ferramentas nunca escrevem projetos.
17. **Pessoa entra no CRM** pela participação. Na fatia 1, de dois jeitos: cadastro manual ("Adicionar pessoa ao projeto": contato existente, ou novo com nome e telefone) e o seeder de dados fictícios.

## Fora da fatia 1

- **Fatia 2:** totais vindos dos projetos (pull a cada 5 min, sinal de vida de 1 h, aviso de desatualizado) e simuladores.
- **Fatia 3:** envio genérico de dados de pessoa, catálogo de campos, as três políticas de divergência e o aviso "Dado diferente".
- **v1:** formulários.
- Também fora: demandas, funil, semáforo, sincronização com etiquetas, juntar pessoas entre projetos, LGPD com dado real.

## Ordem e dependências

| Spec | Título | Depende de | Tamanho |
|---|---|---|---|
| 001 | Projeto ligado ao time | — | Média, base de tudo |
| 002 | Frentes do projeto | 001 | Pequena |
| 003 | Papéis, participação, atuação e escopo de acesso | 001, 002 | Grande |
| 004 | Temperatura por frente | 003 | Média |
| 005 | Ligações e notas | 003 | Pequena |
| 006 | Último contato por projeto | 003, 005 | Média, toca `Message` |
| 007 | API de leitura de projetos para ferramentas | 001, 002 | Média |
| 008 | API da lista de pessoas | 003, 004, 006 | Grande |
| 009 | API da ficha e do histórico | 003–006 | Média |
| 010 | API da visão geral | 004, 006 | Pequena |
| 011 | API de qualidade dos dados | 003–005 | Média, toca `ContactMergeAction` |
| 012 | Front: Projetos nas configurações | 001, 002, 007 | Grande, muitas strings |
| 013 | Front: área CRM, rotas, sidebar e stores | 008–011 | Média |
| 014 | Front: Visão geral | 010, 013 | Pequena |
| 015 | Front: Pessoas | 008, 013 | Média |
| 016 | Front: ficha da pessoa | 009, 013 | Grande |
| 017 | Front: Qualidade dos dados | 011, 013 | Média |
| 018 | Front: painel do CRM na conversa | 009, 013 | Média |
| 019 | Seeder de dados fictícios | 001–006 | Média |
| 020 | Ambiente de homologação | — | Pequena |
| 021 | Revisão final da fatia 1 | 001–020 | Revisão |

**Paralelismo:**
- 004, 005 e 007 podem rodar em paralelo depois da 003 (no caso da 007, depois da 002).
- 008 a 011 podem rodar em paralelo depois da 006.
- 014 a 018 podem rodar em paralelo depois da 013.
- A 020 é independente e pode ir a qualquer momento.

Paralelo só com conjuntos de arquivos disjuntos, e com quem coordena fazendo os commits (`.claude/lessons/implementadores-paralelos-misturam-commits.md`). **Dois rspec nunca ao mesmo tempo** (o banco `chatwoot_test` é um só).

**Arquivos compartilhados entre specs** (resolver o merge à mão):
- `config/routes.rb`: bloco `namespace :rede` (001, 002, 003, 004, 005, 007, 008, 009, 010, 011);
- `app/models/team.rb`: 001;
- `app/models/contact.rb`: 003, 004, 005;
- `app/javascript/dashboard/i18n/locale/{en,pt_BR}/rede.json`: 012 a 018;
- `app/views/api/v1/accounts/rede/people/show.json.jbuilder`: 009, e 018 (acrescenta `team_id` ao projeto);
- `components-next/sidebar/Sidebar.vue`: 012 e 013.

## Fluxo de trabalho de cada spec (TDD)

1. **Testes primeiro.** O implementador escreve só os testes da seção "Testes primeiro".
2. **Provar que falham.** Roda os testes e confirma que falham **pelo motivo esperado** (classe inexistente, rota inexistente, asserção), e não por erro de ambiente. Cola no relatório o resumo da saída.
3. **Implementar** o mínimo que faz os testes passarem e cumpre o "Comportamento esperado".
4. **Verificar.** O testador roda os "Comandos de verificação" e espera cada um terminar.
5. **Code review.** Um revisor separado, que não escreveu o código, usa a seção "Revisão" da spec e reporta os achados por severidade. Correções voltam ao implementador.
6. **Fechar.** Commit de uma linha (`tipo: descrição` em português, sem atribuição, `.claude/rules/commits.md`) e a spec é movida de `develop/pendentes/` para `develop/concluidas/`.

A spec 021 é o code review do conjunto inteiro.

## Ambiente e branches

- **A `develop` é a homologação** (stack própria de homologação). **A `main` é a produção.**
- O trabalho da fatia sai da `develop`, em branches curtas por spec ou por grupo (`feat/rede-projetos`, `feat/rede-pessoas` e assim por diante), que voltam para a `develop`.
- **A `main` só recebe o que foi validado na `develop`.** Não há feature flag para o CRM.
- **Regra de hotfix** (registrada aqui; ainda não aplicada a fluxo nem a CI): correção urgente da produção sai de uma `hotfix/*` criada a partir da `main`, entra na `main` e volta para a `develop`. Ela não passa pela `develop`, então não arrasta o CRM ainda em validação.
- **As migrações são só de acréscimo** (tabelas `rede_*` e colunas novas). A única mudança de comportamento em tabela existente é bloquear o apagar time (001).

## Comandos que valem para todas as specs

```
# rspec: SEMPRE com RAILS_ENV=test (sem isso roda no banco de dev)
MSYS_NO_PATHCONV=1 docker exec -e RAILS_ENV=test chatwoot-next-rails-1 bundle exec rspec <arquivos>

# rubocop
docker exec chatwoot-next-rails-1 bundle exec rubocop <arquivos>

# migração no dev e depois recriar o banco de teste
docker exec chatwoot-next-rails-1 bundle exec rails db:migrate
MSYS_NO_PATHCONV=1 docker exec -e RAILS_ENV=test chatwoot-next-rails-1 bundle exec rails db:drop db:create db:schema:load

# vitest: no container, com TZ=UTC, só nos arquivos tocados
MSYS_NO_PATHCONV=1 docker exec -e TZ=UTC chatwoot-next-rails-1 sh -c 'cd /app && node_modules/.bin/vitest --no-watch --no-cache --no-coverage run <trecho-do-nome>'

# eslint
pnpm eslint <arquivos>
```

Lições que todo agente deve ler antes de começar (`.claude/lessons/`):
- `rspec-must-run-with-rails-env-test.md`;
- `vitest-must-run-with-tz-utc-in-container.md`;
- `selective-staging-must-not-drop-schema-rb.md`;
- `test-fixtures-break-silently-on-scoped-behavior-changes.md`;
- `falhas-preexistentes-exigem-rastreio-de-autoria.md`;
- `implementadores-paralelos-misturam-commits.md`;
- `git-worktree-isolation-fails.md`;
- `spec-file-list-scope-gaps.md`;
- `destroy-async-perde-contexto-nos-callbacks.md`.

## Referências

- Modelo de dados atualizado: `analises/2026-11-16-modelo-de-dados-crm-fatia-1.md` (na pasta do projeto, fora do repositório).
- Apresentação do escopo: `prototipo_chatwoot/apresentacao-crm-no-chatwoot.html` (também fora do repositório).
