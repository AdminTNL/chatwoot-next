# CRM (módulo Rede), fatia 1.1: decisões fechadas

Documento de decisões, **não é uma spec executável**. Registra o que foi combinado com o Fabio em 17/11/2026, depois do primeiro percurso pela fatia 1 no navegador. As specs executáveis da fatia 1.1 serão escritas a partir daqui, depois da 021 (revisão final da fatia 1).

Avaliação geral do Fabio: "para a primeira fatia está bom".

## Decisões fechadas (não reabrir)

### 1. Responsáveis

- **Responsável pela pessoa** (na participação): qualquer membro do projeto (membro do time) ou admin, escolhido à mão. É o que já existe. Não há regra automática.
- **Responsável pela frente (novo):**
  - uma frente pode ter **vários** responsáveis;
  - cada um precisa ser membro do projeto;
  - é opcional e pode ser alterado;
  - é **independente** do responsável de cada pessoa: não preenche nada automaticamente.
  - Modelagem sugerida: tabela de junção `rede_front_responsibles` (`front_id`, `user_id`, único por par).

### 2. Papéis cadastráveis pelo admin

- Hoje: 4 papéis fixos semeados por conta (Coordenador, Ponto focal, Mobilizador, Entrevistador), API só de leitura (`roles#index`).
- Fatia 1.1: o admin cria, edita e desativa papéis numa tela das configurações, como já faz com projetos e frentes.
- Cada papel ganha uma **cor**.
- Papel em uso nunca é apagado, só desativado (mesma regra de projeto e frente).
- O papel "Ponto focal" precisa continuar identificável pelo código (pela `key`), porque os níveis do item 3 dependem dele.

### 3. Níveis de ponto focal (PF1, PF2, PF3…) automáticos

- A cadeia é **por projeto** (não por frente).
- Contam **só superiores que também são pontos focais**.
- Regra: o nível de uma atuação de ponto focal é **1 + o menor nível que o superior tem como ponto focal ativo no mesmo projeto**, em qualquer frente.
- **A cadeia para no primeiro superior que não é ponto focal.** Exemplo: A (PF) → superior B (Coordenador) → superior C (PF): A é **PF1**.
- Ponto focal sem superior é PF1.
- Escala aberta: PF4, PF5 e assim por diante.
- Se a pessoa é ponto focal em duas frentes, cada linha mostra o próprio nível.
- **Calculado na hora de mostrar, nunca gravado.** Trocar um superior ajusta a árvore toda.
- **Ciclos proibidos:** ao salvar um superior, recusar se a cadeia voltar para a própria pessoa. (A falta de validação de ciclo já estava anotada como lacuna da fatia 1.)
- Cores fixas por nível (PF1, PF2, PF3…), independentes das cores dos papéis.
- Contexto técnico: o superior fica em `rede_assignments.superior_contact_id` (por atuação, isto é, por frente). A regra acima resolve o caso de o superior ser ponto focal em várias frentes.

### 4. Qualidade dos dados liberada para agentes

- O agente vê a qualidade **só dos projetos dele**. O admin continua vendo tudo.
- O agente pode:
  - completar cadastros;
  - marcar "não são a mesma pessoa";
  - **juntar** contatos **só quando os dois estão apenas em projetos dele**. Motivo: o contato é da conta inteira, e juntar mescla conversas e dados de todos os projetos, inclusive os que o agente não vê. Fora desse caso, a ação de juntar some (ou pede um admin).
- Hoje a trava é `app/policies/rede/quality_policy.rb` (só `administrator?`).

### 5. Botão "Abrir conversa" na qualidade dos dados

Serve para tirar a dúvida com a pessoa antes de decidir (duplicados e incompletos; "divergência" continua fora).

- Se o contato tem conversa numa caixa de entrada do projeto: abre a mais recente.
- Se não tem: abre o **contato**, onde o agente usa "Nova mensagem" do Chatwoot. A conversa só é criada **quando a mensagem é enviada**; se o agente desistir, nada fica criado (resolve o problema da conversa vazia).
- Caixas oferecidas: as **caixas do projeto que o agente também pode acessar**. No Chatwoot, acessar uma caixa depende de ser membro da caixa, não do time; na maioria dos casos coincide, mas nada garante.
  - Uma só: já vem selecionada.
  - Nenhuma: aviso de que o agente não tem acesso às caixas desse projeto.
  - Admin: todas as caixas do projeto.
- Cuidado: na API oficial do WhatsApp, iniciar conversa depois de 24 h exige template. Na Evolution não há essa trava. Conferir o canal de cada projeto ao implementar.

### 6. Correções de interface vindas do percurso

- Visão geral, "O que mudou esta semana": o nome da pessoa está colado na frase ("Caio Fariascomeçou um novo papel"). Falta um espaço no template.

### 7. Cadastro de pessoa completo

Lacuna anotada na 015: a criação de participação não aceita responsável, próximo passo nem cidade (o front faz POST e depois PATCH, e a cidade é ignorada). A fatia 1.1 resolve isso no backend, junto com a indicação de contato reaproveitado.

### 8. Homologação com a Evolution

- **Mesmo servidor Evolution** da produção, com **sessões exclusivas de homologação**: `homolog-pe` e `homolog-pa` (simulação mínima de PE e PA).
- **Sem feature flag.** O código da `develop` e da `main` é o mesmo; o ambiente se separa por **configuração**. O banco da homologação só conhece as caixas de teste.
- Regras de segurança, que entram no checklist de subida:
  - o webhook das sessões `homolog-*` aponta só para a URL de homologação;
  - nenhuma caixa da produção aponta para uma sessão `homolog-*`.
- Objetivo: merge da `develop` para a `main` com o mínimo de atrito; nada específico de teste entra na `main`.
- A spec 020 (concluída) fala só em "Evolution com número de teste". Este item a ajusta.
- **Não simular a ferramenta do Abib por enquanto:** ele ainda está testando.

## Confirmado que já existe na fatia 1

Itens da lista do Fabio que a fatia 1 já cobre:
- "Por temperatura" com filtro por projeto (inclui "sem temperatura").
- Último contato pela **resposta da pessoa**: só mensagens recebidas e ligações atendidas.
- Linha da tabela de pessoas na cor da temperatura, com rótulo.
- Projeto diferenciado por cor.
- Ligação registrada à mão no histórico.
- Filtro por data no histórico da pessoa.

## Descartado

- Coluna "última tentativa nossa" ao lado de "última resposta dela": **não fazer**.

## Fora da fatia 1.1 (depois)

- **Formulários:** ficam mockados. Antes de construir, fazer uma apresentação/protótipo para o Abib, que ainda não definiu o que quer.
- Catálogo de campos e divergência (o botão "Abrir conversa" do item 5 vale para ela quando vier).
- Totais e simuladores.
- Semáforo de saúde na visão geral.
- Demandas e funil.
- Ligação com as etiquetas de temperatura.
- Simulação da ferramenta do Abib.
- **Documento no Atlas** explicando como cada projeto se integra ao Chatwoot para mostrar os dados consolidados. Escrever depois da apresentação de arquitetura; hoje a única integração pronta é a API de leitura de projetos.

## Registrado para a fatia de formulários (não decidido, não implementar agora)

Pergunta do Fabio (17/11): o formulário cria o contato automaticamente se a pessoa ainda não existir?

- **Hoje:** não. A única integração é a API de leitura de projetos (`GET /api/rede/v1/projects`). Nenhuma resposta de formulário chega ao Chatwoot.
- Comparação: no WhatsApp, o próprio Chatwoot cria o contato na primeira mensagem; no CRM, "Adicionar pessoa ao projeto" já procura o contato ou cria um novo.
- **Direção natural quando os formulários vierem:** procurar o contato e, se não existir, criar. Cuidados:
  1. Buscar pelo **telefone normalizado** (regra do nono dígito, `Rede::Phone`), para não criar um contato pelo formulário e outro pelo WhatsApp.
  2. **Endpoint próprio do CRM com token restrito** (escopo só de envio de respostas), e não a API de contatos do Chatwoot, cujo token dá acesso amplo à conta.
  3. Contato criado pelo formulário fica **sem caixa de entrada**; a ligação com a caixa surge na primeira mensagem, e o Chatwoot reaproveita o contato pelo número.
  4. Marcar a origem na participação (`rede_participations.origin`).
  5. Casos duvidosos (sem telefone, telefone inválido, nome muito diferente do cadastrado) vão para a qualidade dos dados; liga com a "divergência", que ficou para depois.
  6. Em aberto: o formulário precisa mandar o slug do projeto e o id público da frente (a API de leitura já fornece); consentimento e LGPD para dado real; formato das respostas.
- Lugar: fatia de formulários e "envio genérico de dados de pessoa" (fatia 3). Levar para a conversa com o Abib.

## Ordem combinada

1. Apresentação de arquitetura para a equipe técnica (pasta `arquitetura/`, fora do repositório).
2. Spec 021: revisão final da fatia 1 (vazamento entre projetos e regressão focada).
3. Specs da fatia 1.1 a partir deste documento.
4. Depois: stack de homologação com as sessões `homolog-*`, protótipo do formulário para o Abib e documento no Atlas.
