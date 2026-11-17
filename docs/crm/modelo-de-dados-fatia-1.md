# Modelo de dados do CRM: fatia 1

**Data:** 16/11/2026

**Situação:** decidido. É a base das specs em `docs/crm/specs/` (000 a 022).

**Parte de:** `2026-11-09-modelo-de-dados-crm.md`, que **continua valendo** como visão completa (23 tabelas). Este documento diz o que entra **agora**, com que nome e com que mudanças. O que não aparece aqui segue como está no documento de 09/11, para as fatias seguintes.

**Nada foi alterado no repositório** ao escrever este documento.

---

## 1. Decisões de 13 a 16/11

| # | Decisão | Por quê |
|---|---|---|
| 1 | **Projeto = time do Chatwoot, 1 para 1.** Todo time é um projeto (`rede_projects.team_id` é único). Na interface, "Times" vira "Projetos"; no banco continua `teams`. | O fork já usa o time como fronteira de acesso: cada caixa pertence a um time, o agente acessa as caixas pelos times de que é membro, e a conversa herda o time da caixa. Um vínculo agente × projeto separado duplicaria isso. |
| 2 | **Namespace `Rede::` e tabelas `rede_*`.** | Já existe `Crm::` no Chatwoot (integração LeadSquared). |
| 3 | **Projeto nunca é apagado, só encerrado.** Apagar um time passa a ser bloqueado. | O histórico de pessoas e ligações não pode sumir. |
| 4 | **O slug do projeto é o id público e imutável;** a frente tem um `public_id` (uuid). | Ferramentas externas (os formulários do Abib) guardam o id e não podem quebrar quando alguém renomeia. |
| 5 | **Frentes são opcionais.** Projeto sem frentes é válido. | Alguns projetos não terão frentes. |
| 6 | **Atuação sem frente é permitida.** Em projeto sem frentes é o normal; em projeto com frentes, significa "frente a definir". | A pessoa entra antes de alguém decidir onde ela atua. |
| 7 | **Temperatura por frente.** Em projeto sem frentes, por projeto. A escala é frio, morno, quente e vapor, e "sem temperatura" é um estado válido. Só em frentes marcadas com `has_temperature`. | É assim que a equipe acompanha (reunião de 13/11). |
| 8 | **A temperatura do CRM é independente das etiquetas de temperatura** (por time, spec 029) nesta fatia. | Ligar as duas mexe nas automações da caixa; fica para depois. |
| 9 | **Último contato por projeto** = o mais recente entre a última mensagem **recebida** (não privada) numa conversa do time do projeto e a última **ligação atendida**. É gravado na participação. | "A resposta da pessoa deve contar como último contato" (reunião). Ligação não atendida não é contato. |
| 10 | **Ligação é registrada à mão,** com data, quem ligou, resumo e se atendeu. O operador escolhe o projeto. | Não há integração de telefonia. |
| 11 | **Duplicado só dentro do mesmo projeto,** pelo telefone normalizado (regra do nono dígito). | Juntar pessoas entre projetos depende da conversa com o Lucas. |
| 12 | **Incompleto = só os campos nativos** (nome, telefone, cidade) e "frente a definir". **Sem catálogo de campos e sem divergência** nesta fatia. | Os relatórios ainda dependem da conversa com o Abib; a estrutura agora é mínima. |
| 13 | **Leitura de projetos para ferramentas externas:** um token próprio (guardado como hash, revogável, mostrado uma vez) e a rota `GET /api/rede/v1/projects`. | É a primeira necessidade da ferramenta de formulários. |
| 14 | **Os totais de outras ferramentas virão por pull,** com o Chatwoot buscando a cada hora e um alerta de "dados desatualizados" para todo o projeto. **Não entra na fatia 1.** | É simples, e não depende de cada ferramenta lembrar de enviar. |
| 15 | **Branches:** a `develop` é a homologação (stack própria) e a `main` é a produção. A `main` só recebe o que foi validado. Há regra de hotfix e não há feature flag. | — |

---

## 2. De onde vem o acesso

```
caixa de entrada ──pertence a──▶ time ◀──1:1──▶ projeto (rede_projects)
       │                          │                     │
       ▼                          ▼                     ▼
   conversa (team_id)       membros do time       participações, frentes,
                            = agentes do projeto  temperaturas, ligações
```

- **O agente vê** só os projetos dos times de que é membro. **O admin** vê todos.
- **Uma conversa pertence ao projeto** do time da caixa. É ela que alimenta o último contato daquele projeto.
- **Um contato pode estar em vários projetos.** Cada projeto vê só a própria participação, as próprias conversas e o próprio histórico.

---

## 3. Tabelas da fatia 1

**Convenções:** todas têm `account_id`, `created_at` e `updated_at`, omitidos abaixo. "Encerrar" significa `status = closed` mais `closed_at` ou `ended_at`. Nada é apagado.

### 3.1 Já existem no Chatwoot (sem mudança de estrutura)

| Tabela | Uso no CRM |
|---|---|
| `contacts` | A pessoa. A cidade está em `additional_attributes->>'city'`. |
| `users` | O agente ou admin: responsável, quem ligou, autor. |
| `teams` | O time, que é o projeto. Apagar fica bloqueado. |
| `team_members` | Quem é do projeto. |
| `inboxes` | `team_id`: cada caixa pertence a um time. |
| `conversations`, `messages` | Fonte do último contato (mensagens `incoming`, não privadas). |

### 3.2 Novas

| Tabela (nome no modelo de 09/11) | Colunas principais | Regras |
|---|---|---|
| **`rede_projects`** (`PROJETO`, extensão) | `team_id` (único), `name`, `slug` (único na conta, imutável), `color` (#RRGGBB), `status` (active/closed), `closed_at` | É criado junto com o time. O nome é sincronizado nos dois sentidos com `teams.name`. |
| **`rede_fronts`** (`FRENTE`) | `project_id`, `name` (único por projeto, sem diferenciar maiúsculas), `public_id` (uuid, imutável), `has_temperature`, `status`, `closed_at` | Encerra, não apaga. |
| **`rede_roles`** (`PAPEL`) | `key`, `name`, `position` | Padrões: coordenador, ponto focal, mobilizador e entrevistador. |
| **`rede_participations`** (`PARTICIPACAO`) | `contact_id`, `project_id` (par único), `responsible_user_id`, `referred_by_contact_id`, `referred_by_text`, `next_step`, `origin` (manual/import/integration/form), `status`, `joined_at`, **`last_contact_at`** | O responsável é membro do time ou admin. `last_contact_at` é calculado (decisão 9). |
| **`rede_assignments`** (`ATUACAO`) | `participation_id`, `front_id` (**pode ser nulo**), `role_id`, `superior_contact_id`, `status`, `started_at`, `ended_at` | No máximo uma ativa por participação e frente (a frente nula conta como uma). Mudar o papel, o superior ou a frente encerra a atuação e abre outra. |
| **`rede_evaluations`** (`AVALIACAO`, simplificada) | `contact_id`, `project_id`, `front_id` (nulo em projeto sem frentes), `dimension` (`'temperatura'`), `level` (frio/morno/quente/vapor ou nulo), `note`, `evaluated_at`, `author_user_id` | **Só inserção**: o histórico nunca é sobrescrito, e a atual é a mais recente. A frente é obrigatória quando o projeto tem frentes ativas. |
| **`rede_interactions`** (`INTERACAO`, parcial) | `contact_id`, `project_id`, `front_id`, `kind` (call/note), `answered` (obrigatório em call), `summary`, `occurred_at` (sem futuro), `author_user_id` | O autor edita em até 24 h. Ligação atendida atualiza o último contato. |
| **`rede_api_tokens`** (nova; não estava no modelo) | `name`, `token_digest` (SHA-256), `token_prefix`, `scopes` (`projects:read`), `created_by_user_id`, `last_used_at`, `revoked_at` | O valor puro nunca é guardado. |
| **`rede_quality_resolutions`** (nova) | `project_id`, `kind` (merged/dismissed), `contact_a_id`, `contact_b_id`, `resolved_by_user_id` | "Não são a mesma pessoa" fica lembrado; serve também para contar os resolvidos no mês. |

### 3.3 O que mudou em relação ao modelo de 09/11

| Mudança | Motivo |
|---|---|
| `DIMENSAO` e `CRITERIO_DIMENSAO` não viraram tabelas agora. A dimensão é a string `'temperatura'` e a escala é fixa no código. | Só existe uma dimensão nesta fatia. A coluna já está lá para quando vier outra. |
| `AVALIACAO` sem `valido_ate` e sem origem calculada. | Nesta fatia toda avaliação é manual. |
| `ATUACAO.frente_id` passou a aceitar nulo. | Decisão 6. |
| `FRENTE` ganhou `has_temperature` e `public_id`. | Decisões 4 e 7. |
| `PARTICIPACAO` ganhou `last_contact_at`. | Ordenar e filtrar por "sem contato há N dias" sem calcular na hora. |
| `INTERACAO` só com ligação e nota, e o campo `answered`. | Decisão 10. As conversas não são copiadas: vêm de `conversations`. |
| `TIPO_FRENTE` ficou de fora. | Nenhuma tela usa agora. |
| Os nomes físicos passaram de `crm_*` para `rede_*`. | Decisão 2. |
| Tabelas novas `rede_api_tokens` e `rede_quality_resolutions`. | Decisões 13 e 11. |

---

## 4. A Ana na fatia 1

1. **Ana manda mensagem** para o número do Mobiliza PE. A caixa é do time PE, então a conversa tem `team_id` = PE.
2. **Um agente do PE** adiciona a Ana ao projeto: é criada uma participação com `origin = manual`. Como o PE tem frentes e nenhuma foi escolhida, ela aparece como **"frente a definir"**.
3. **O agente define a frente Campo,** com o papel mobilizador: é criada uma atuação ativa em Campo.
4. **O agente marca Campo como quente:** é criada uma avaliação (`front_id` = Campo, `level` = quente).
5. **A Ana responde outra mensagem:** `last_contact_at` da participação no PE vira o horário dela.
6. **Um agente liga e ela não atende:** é registrada uma ligação com `answered = false`. O último contato não muda.
7. **A Ana também entra no Mobiliza PA,** que não tem frentes: outra participação. A temperatura do PA fica no projeto (`front_id` nulo).
8. **O agente do PA** vê só a participação, as conversas e o histórico do PA. O agente do PE vê só os do PE. O admin vê os dois.
9. **Um cadastro "Ana S."** com o mesmo número sem o nono dígito aparece em **Qualidade** do PE. O admin junta os dois, e tudo passa para a Ana.

---

## 5. O que fica para as próximas fatias

| Fatia | O quê | Do modelo de 09/11 |
|---|---|---|
| **2** | **Formulários só registrados** (sem as perguntas): qual formulário da ferramenta do Abib pertence a que projeto e frente. **Totais por pull** com sinal de vida de 1 h e alerta de desatualizado para todo o projeto. **Simuladores** (serviços falsos, com contrato) da ferramenta de formulários e de outras ferramentas. | `FORMULARIO`, `INDICADOR`, `TOTALIZADOR` |
| **3** | **Catálogo de campos e valores por pessoa,** **divergência** ("Dado diferente" na qualidade), **submissões,** e a ligação da temperatura do CRM com as etiquetas da caixa. | `DEF_CAMPO`, `VALOR_CAMPO`, `FORMULARIO_CAMPO`, `SUBMISSAO`, `DIVERGENCIA`, `CRITERIO_DIMENSAO` |
| Depois | Demandas e funil, perfis sociais, tipos de frente, semáforo da visão geral, mesclar pessoas entre projetos (depende do Lucas). | `DEMANDA`, `PERFIL_SOCIAL`, `TIPO_FRENTE` |

---

## 6. Pontos ainda abertos

- **Edição de ligação ou nota de outra pessoa:** o admin deveria poder? Hoje só o autor edita, em até 24 h.
- **Formato das respostas de formulário:** a decidir com o Abib na fatia 2.
- **Fronteira entre a pessoa da Central e as bases dos projetos:** a decidir com o Lucas, antes de liberar a mescla entre projetos.
