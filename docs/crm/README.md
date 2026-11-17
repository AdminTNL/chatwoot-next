# CRM (módulo Rede): documentação da fatia 1

Material de referência para quem for portar ou evoluir o CRM.

- [`modelo-de-dados-fatia-1.md`](modelo-de-dados-fatia-1.md): decisões e tabelas `rede_*` da fatia 1.
- [`specs/`](specs/): specs executáveis da fatia 1 (001 a 019 e 021), a visão geral (000) e as decisões da fatia 1.1 (022). Servem de critério de aceite: cada uma traz comportamento esperado, casos de borda e testes.

## Como ler

- Comece pela [000](specs/000-visao-geral-fatia-1-crm.md) (visão geral e ordem) e pela [022](specs/022-decisoes-fatia-1-1.md) (decisões mais recentes).
- As specs foram escritas para agentes de código e citam arquivos, comandos e lições do ambiente local de desenvolvimento. Trate como especificação de comportamento, não como passo a passo.
- A spec 020 (ambiente de homologação) não está aqui de propósito.
- A 021 (revisão final) ainda não foi executada.

## Situação

O código da fatia 1 está no módulo `Rede::` (`app/**/rede/`). Em 17/11/2026 foi combinado levar o CRM para o painel unificado e deixar o Chatwoot só como chat, então este material serve de base para esse porte.
