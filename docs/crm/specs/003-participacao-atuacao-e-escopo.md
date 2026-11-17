# Spec 003: papéis, participação, atuação e escopo de acesso

## Execução

Igual à 001:
- Fluxo TDD: testes, provar que falham, implementar, verificar, code review.
- Papéis: implementador `sonnet`, testador `haiku` (espera cada comando), revisor `opus` separado.
- rspec sempre com `-e RAILS_ENV=test`, sem worktree, branch saindo da `develop`.
- **Parar e reportar** se faltar arquivo de produção. Aqui isso pesa mais: um endpoint sem escopo vaza dados entre projetos.
- `db/schema.rb` no commit.

## Contexto

- **Projeto** (`Rede::Project`, 001) e **frente** (`Rede::Front`, 002) já existem.
- **Pessoa** é `Contact` (`app/models/contact.rb`):
  - `contacts.id` é **integer**, não bigint;
  - `phone_number` é único por conta e validado em E.164 (`/\+[1-9]\d{1,14}\z/`, linhas 54-56);
  - `name` pode vir vazio.
- **Acesso:**
  - agente do projeto é quem é membro do time (`team.members`);
  - o admin é `account_user.administrator?`;
  - o precedente de serviço de escopo é `Contacts::AccessScope` (`app/services/contacts/access_scope.rb`): `unrestricted?` para admin, ids permitidos e `restrict(relation)` com subquery;
  - `Reports::AccessScope` (`app/services/reports/access_scope.rb`) segue a mesma linha.
- **Visibilidade de contatos:** a spec antiga 012 deixou a tela nativa de Contatos visível só para quem tem conversa com o contato numa inbox acessível. **Esta spec não mexe nisso.**

## Decisões fechadas (não reinterpretar)

1. **Participação:**
   - Uma por pessoa e projeto: índice único `[contact_id, project_id]`.
   - Guarda: responsável (`responsible_user_id`), quem indicou (`referred_by_contact_id` **ou** `referred_by_text`), próximo passo (`next_step`, texto livre), origem, status (`active`/`closed`) e data de entrada (`joined_at`).
2. **O responsável** precisa ser membro do time do projeto ou admin da conta. Pode ficar vazio.
3. **Origem:** `manual` (0), `import` (1), `integration` (2), `form` (3). Nesta fatia só se usa `manual`; o seeder usa `import`.
4. **Atuação:**
   - É a pessoa numa frente, com papel (`role_id`, opcional), superior (`superior_contact_id`, opcional), `started_at`, `ended_at` e status (`active`/`closed`).
   - **`front_id` pode ser nulo:**
     - em projeto sem frentes ativas, a atuação sem frente é o normal;
     - em projeto com frentes, quer dizer "frente a definir".
5. **Regras da atuação:**
   - a frente, quando existe, é do mesmo projeto da participação e está ativa;
   - no máximo **uma atuação ativa por participação e frente**, contando "sem frente" como uma frente: índice único parcial `[participation_id, COALESCE(front_id, 0)] WHERE status = 0`;
   - o superior é outro contato e não pode ser a própria pessoa;
   - mudar o papel ou o superior **encerra a atuação e abre outra** (o histórico são as linhas);
   - atribuir uma frente a uma atuação "frente a definir" também encerra aquela e abre outra com a frente.
6. **Papéis:**
   - Catálogo por conta (`rede_roles`: `account_id`, `key`, `name`, índice único `[account_id, key]`).
   - Padrões: `coordenador` (Coordenador), `ponto_focal` (Ponto focal), `mobilizador` (Mobilizador), `entrevistador` (Entrevistador).
   - Criados por `Rede::Roles::EnsureDefaults.new(account).perform`, idempotente, chamado:
     - na criação de projeto (no builder da 001);
     - na migração de dados desta spec, para as contas que já têm projeto.
   - Nesta fatia não há tela para editar papéis.
7. **Escopo de acesso (`Rede::AccessScope`):**
   - `unrestricted?` é verdadeiro para admin.
   - `project_ids` é `nil` para admin; para os outros, os projetos dos times de que o usuário é membro **nesta conta**.
   - Expõe `restrict_projects(rel)`, `restrict_participations(rel)` e `can_access_project?(project)`.
   - **Todas** as APIs do CRM daqui em diante usam esse serviço; nenhuma reimplementa a regra.
8. **Adicionar pessoa ao projeto** (`POST .../rede/participations`), permitido ao admin ou a um membro do projeto:
   - **Com `contact_id`:** usa o contato existente da conta. Se ele já participa do projeto, 422 com a participação existente no corpo.
   - **Com `contact: { name, phone_number }`:** normaliza o telefone para E.164 (só dígitos; sem DDI, assume `+55`) e procura um contato existente pelas variantes do nono dígito.
     - Encontrou: usa esse contato.
     - Não encontrou: cria o contato.
   - Opcionalmente cria a primeira atuação na mesma transação (`assignment: { front_id, role_id, superior_contact_id }`).
   - O agente só pode adicionar a projetos do seu escopo (fora dele, 404).
9. **Telefone:** o helper `Rede::Phone.normalize(raw)` e `Rede::Phone.variants(e164)` (com e sem o nono dígito para celular BR) ficam num lugar só e serão reusados pela 011. A lógica de referência é `phone_variants` em `lib/ops/temperatura_backfill.rb:136-147`. Não importar daquele arquivo, que é de operação.
10. **Contato** ganha `has_many :rede_participations, class_name: 'Rede::Participation', dependent: :destroy`. O mesmo para as tabelas filhas, via participação. Mesclar contatos é tratado na 011.

## Escopo

**Entra:**
- **Migrações:**
  - `create_rede_roles`;
  - `create_rede_participations`, com FKs, índices `[contact_id, project_id]` (único), `[project_id, status]` e `[responsible_user_id]`;
  - `create_rede_assignments`, com o índice único parcial com `COALESCE`;
  - migração de dados dos papéis padrão.
- **Models:** `Rede::Role`, `Rede::Participation` e `Rede::Assignment`, com as validações das decisões 1 a 5.
- **Serviços:** `Rede::AccessScope`, `Rede::Roles::EnsureDefaults`, `Rede::Phone` (em `app/services/rede/phone.rb` ou `lib/rede/phone.rb`, seguindo o padrão do repo para helpers) e `Rede::Participations::Create` (decisão 8).
- **API:**
  - `GET .../rede/roles` (qualquer usuário da conta);
  - `POST .../rede/participations`;
  - `PATCH .../rede/participations/:id`: `responsible_user_id`, `next_step`, `referred_by_contact_id`, `referred_by_text` e `status`;
  - `POST .../rede/participations/:participation_id/assignments`: `front_id`, `role_id`, `superior_contact_id`;
  - `PATCH .../rede/participations/:participation_id/assignments/:id`: muda o papel, o superior ou a frente, seguindo a decisão 5 (encerra e abre); devolve a atuação nova;
  - `POST .../assignments/:id/close`.
- **Policies** e jbuilder (`_participation`, `_assignment`, `_role`).

**Fica de fora:**
- listagem de pessoas (008) e ficha (009);
- temperatura (004), interações (005), último contato (006);
- cálculo do nível PF, PF1, PF2 pela cadeia de indicação;
- validação de ciclo na cadeia de indicação. O modelo prevê essa validação, mas ela fica para depois: **registrar como pendência no relatório**.

## Comportamento esperado

- **Admin adiciona "Ana" (+55 81 9xxxx-xxxx)** ao projeto PE, já com atuação em "PE Campo" como Mobilizadora:
  - cria o contato (se não existir), a participação `manual` ativa e a atuação ativa;
  - responde 200 com a participação e a atuação.
- **O mesmo telefone sem o nono dígito:** reaproveita o contato existente e não duplica.
- **O mesmo contato no mesmo projeto:** 422.
- **Atuação:**
  - em frente de outro projeto: 422;
  - em frente encerrada: 422;
  - uma segunda atuação ativa "sem frente" na mesma participação: 422;
  - atuação "sem frente" num projeto com frentes: permitida.
- **`PATCH` da atuação** mudando o papel: a antiga fica `closed` com `ended_at`, e a nova fica ativa com o papel novo.
- **Responsável** que não é membro do time nem admin: 422.
- **Agente:**
  - membro do PE: consegue tudo acima no PE;
  - no projeto PA, do qual não é membro: 404 em todas as rotas, inclusive `PATCH` de uma participação do PA pelo id.
- **`Rede::AccessScope`:** admin vê todos os projetos; agente vê só os seus; um usuário de outra conta não vê nada; um agente sem time vê zero projetos (sem erro).

## Testes primeiro

- `spec/models/rede/participation_spec.rb`: unicidade, responsável membro, enums.
- `spec/models/rede/assignment_spec.rb`:
  - frente do mesmo projeto e ativa;
  - índice parcial com `COALESCE`, provado no banco: `insert` cru deve falhar;
  - superior diferente da pessoa.
- `spec/models/rede/role_spec.rb` e `spec/services/rede/roles/ensure_defaults_spec.rb` (idempotente).
- `spec/services/rede/access_scope_spec.rb`: todos os casos de escopo.
- `spec/services/rede/phone_spec.rb`:
  - normalização de formatos (`(81) 9 8888-7777`, `5581988887777`, `+5581988887777`);
  - variantes com e sem o nono dígito;
  - fixo e não celular sem variante.
- `spec/services/rede/participations/create_spec.rb`: contato existente, novo, por variante, duplicado, atuação junto, rollback quando a atuação é inválida.
- `spec/controllers/api/v1/accounts/rede/participations_controller_spec.rb`, `assignments_controller_spec.rb` e `roles_controller_spec.rb`: por papel (admin, membro, não membro), cobrindo os casos de "Comportamento esperado".

## Arquivos a mudar

- `db/migrate/<ts>_create_rede_roles.rb`, `<ts>_create_rede_participations.rb`, `<ts>_create_rede_assignments.rb` e `<ts>_seed_rede_default_roles.rb` (novos), mais `db/schema.rb`.
- `app/models/rede/{role,participation,assignment}.rb` (novos) e `app/models/rede/project.rb` (`has_many :participations`).
- `app/models/contact.rb` (`has_many :rede_participations`) e `app/models/account.rb`.
- `app/services/rede/access_scope.rb`, `app/services/rede/roles/ensure_defaults.rb`, `app/services/rede/phone.rb` e `app/services/rede/participations/create.rb` (novos); `app/services/rede/projects/builder.rb` (chamar `EnsureDefaults`).
- `app/controllers/api/v1/accounts/rede/{participations,assignments,roles}_controller.rb` (novos).
- `app/policies/rede/{participation,assignment,role}_policy.rb` (novos).
- Views jbuilder correspondentes (novas).
- `config/routes.rb` e `config/locales/en.yml`.
- Os specs e as factories `spec/factories/rede/{roles,participations,assignments}.rb`.

## Casos de borda

- **Contato de outra conta** passado em `contact_id`: 404.
- **Telefone inválido** em `contact.phone_number`: 422. Nunca criar contato com telefone descartado: o `discard_invalid_attrs` do `Contact` apaga silenciosamente, então validar antes.
- **Duas variantes do telefone já existentes como contatos diferentes:** usar o que corresponde exatamente ao número informado; se nenhum corresponder exatamente, usar o mais antigo. O caso aparecerá como duplicado na 011.
- **Agente que é membro de dois times:** vê os dois projetos.
- **Projeto encerrado:** aceita `PATCH` de participação (para acompanhar), mas **não** aceita participação nova (422).
- **Apagar o contato** apaga participação e atuações (`dependent`); conferir que não sobra linha órfã.

## Dependências

001 e 002.

## Comandos de verificação

```
docker exec chatwoot-next-rails-1 bundle exec rails db:migrate
MSYS_NO_PATHCONV=1 docker exec -e RAILS_ENV=test chatwoot-next-rails-1 bundle exec rails db:drop db:create db:schema:load
MSYS_NO_PATHCONV=1 docker exec -e RAILS_ENV=test chatwoot-next-rails-1 bundle exec rspec spec/models/rede spec/services/rede
MSYS_NO_PATHCONV=1 docker exec -e RAILS_ENV=test chatwoot-next-rails-1 bundle exec rspec spec/controllers/api/v1/accounts/rede
docker exec chatwoot-next-rails-1 bundle exec rubocop app/models/rede app/services/rede app/controllers/api/v1/accounts/rede app/policies/rede app/models/contact.rb
```

## Revisão

- [ ] Toda rota nova passa pelo `Rede::AccessScope`. Procurar `Rede::Participation.find` ou `Current.account.rede_*` sem escopo.
- [ ] Fora do escopo dá 404, nunca 403 nem os dados.
- [ ] O índice parcial com `COALESCE` existe no banco, e não só como validação.
- [ ] O normalizador de telefone tem um ponto só e testes de formatos reais.
- [ ] Criar a participação com atuação é atômico.
- [ ] Nenhum vazamento de contato por `contact_id` de outra conta.
- [ ] Pendência de ciclo na cadeia de indicação registrada no relatório.

## Commit sugerido

`feat: adiciona participacao e atuacao de pessoas nos projetos do crm`
