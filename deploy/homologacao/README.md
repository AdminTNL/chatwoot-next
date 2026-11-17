# Ambiente de homologação (develop)

Stack do Portainer (Swarm) que roda a imagem da branch `develop`. A `main` é a produção e só recebe o que foi validado aqui.

> **Homologação não tem backup. Os dados são descartáveis.**

Esta pasta (`deploy/`) não tem relação com `deployment/`, que é do upstream.

## Arquivos

- `docker-compose.portainer.yml`: modelo da stack, com nomes próprios (`chatwoot-hml-*`) para não colidir com a produção.
- `.env.example`: nomes das variáveis, com valores de exemplo não secretos.

## Recursos

Cada serviço tem limite de memória (a VPS não tem swap, estourar a memória derruba a produção):

| Serviço | Limite | Reserva |
|---|---|---|
| `chatwoot-hml-postgres` | 512M | 256M |
| `chatwoot-hml-redis` | 128M | 64M |
| `chatwoot-hml-web` | 1G | 512M |
| `chatwoot-hml-worker` | 768M | 384M |

Concorrência reduzida: `WEB_CONCURRENCY=0`, `RAILS_MAX_THREADS=3`, `SIDEKIQ_CONCURRENCY=3`. Se o web passar de 1G de forma estável, registre e discuta antes de aumentar o limite; se faltar memória, reduza primeiro o worker.

## Variáveis (definir no Portainer, nunca no repositório)

| Variável | Obrigatória | Observação |
|---|---|---|
| `CHATWOOT_IMAGE` | sim | `ghcr.io/admintnl/chatwoot-next:develop` ou `...:sha-<curto>` para fixar |
| `TRAEFIK_HOST` | sim | sugestão `homolog-chatwoot.<domínio>` (a confirmar) |
| `FRONTEND_URL` | sim | `https://` + o host acima |
| `RAILS_ENV` | não | padrão `production` |
| `SECRET_KEY_BASE` | sim | gerar um valor novo, diferente da produção |
| `POSTGRES_DB`, `POSTGRES_USER` | sim | banco próprio da homologação |
| `POSTGRES_PASSWORD` | sim | senha própria, diferente da produção |
| `MAILER_SENDER_EMAIL`, `SMTP_*` | não | vazio = sem envio de e-mail |
| `AI_SUGGESTION_SERVICE_URL`, `AI_SUGGESTION_SERVICE_API_KEY` | não | vazio desliga o recurso de sugestão de IA |

Fixos no modelo: `ENABLE_ACCOUNT_SEEDING=true` (só aqui), `ACTIVE_STORAGE_SERVICE=local` (volume `chatwoot-hml-storage`, sem bucket) e o Redis/Postgres próprios da stack. Nenhuma conexão com o banco, o Redis ou o bucket da produção.

Sem SMTP, convite e recuperação de senha não enviam e-mail: os jobs de e-mail falham e aparecem como erro/retry no Sidekiq, o que é esperado. Os usuários são criados pelo seeder ou pelo console.

## Subir

1. Confirmar o host com o Fabio e criar o DNS apontando para a VPS.
2. Se a imagem for privada, associar o registry do GHCR ao ambiente no Portainer.
3. Portainer, **Stacks > Add stack**, nome `chatwoot-hml`. Colar o conteúdo de `docker-compose.portainer.yml`.
4. Preencher as variáveis (use `.env.example` como lista) e fazer o deploy.
5. Conferir os logs do `chatwoot-hml-web` (`db:prepare` cria o banco vazio) e do `chatwoot-hml-worker`. A URL deve abrir a tela de login.
6. Criar o super admin e a conta (`rails c` ou o fluxo de onboarding).
7. Anotar a memória da VPS antes e depois.

## Atualizar

1. Push na `develop`: o GitHub Actions publica `:develop` e `:sha-<curto>`.
2. No Portainer, trocar a tag em `CHATWOOT_IMAGE` (ou usar `:develop` e forçar o pull) e atualizar a stack (**Update the stack**, com *Re-pull image*). O `db:prepare` roda as migrações.

## Rodar o seeder

No container do `chatwoot-hml-web` (console do Portainer):

```
ACCOUNT_ID=<id> bundle exec rake db:seed:rede_data   # disponível após a spec 019
```

Depois, entrar como admin e como `agente.pe@demo.local`.

## Zerar o ambiente

1. Remover a stack no Portainer.
2. Remover os volumes `chatwoot-hml_chatwoot-hml-postgres-data`, `chatwoot-hml_chatwoot-hml-redis-data` e `chatwoot-hml_chatwoot-hml-storage` (no Swarm o nome ganha o prefixo da stack; só estes; nunca volumes `chatwoot-next-*`, que são da produção).
3. Recriar a stack: o `db:prepare` cria o banco vazio de novo.

## WhatsApp

Só um **número de teste**, numa instância separada da Evolution, apontando para a URL da homologação. **Os números reais dos projetos nunca são conectados à homologação.** Isso é feito fora do compose.

## Checklist de validação

- [ ] `actionlint` no workflow
- [ ] `docker compose --env-file deploy/homologacao/.env.example -f deploy/homologacao/docker-compose.portainer.yml config > /dev/null` sem erro
- [ ] `grep -n "chatwoot-next-" deploy/homologacao/docker-compose.portainer.yml` vazio
- [ ] Push de teste na `develop` gerou a imagem `:develop`
- [ ] Stack criada no Portainer; web e worker saudáveis
- [ ] Super admin e conta criados
- [ ] Seeder rodou
- [ ] Login como admin e como `agente.pe@demo.local`
- [ ] Instância de teste da Evolution conectada; mensagem recebida aparece e atualiza o último contato
- [ ] Memória da VPS antes e depois anotada
