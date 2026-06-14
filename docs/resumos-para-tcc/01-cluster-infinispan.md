# Cluster Infinispan: configuração e variantes SYNC/ASYNC (B-02, B-03)

## O que foi feito

O cluster experimental do trabalho foi materializado por dois arquivos no diretório `cluster/`. O arquivo `podman-compose.yml` orquestra três nós da imagem oficial `quay.io/infinispan/server:15.0` (rotulados `isn1`, `isn2`, `isn3`) sobre uma rede *bridge* `infinispan-net`. O arquivo `cluster/infinispan-cluster.xml` define dois *caches* distribuídos, `sessions` e `counters`, com `numOwners=2` (duas cópias por chave), `numSegments=64` (alinhado à recomendação do guia de *tuning* para *clusters* até 20 nós) e política de partição `DENY_READ_WRITES` com `merge-policy=PREFERRED_NON_NULL`. O perfil `DIST_SYNC` é o controle de sanidade; o perfil `DIST_ASYNC` é o alvo do experimento, e ambos coexistem na mesma configuração XML, selecionáveis por uma variável de ambiente injetada pelo *compose*.

A detecção de falha é feita pelo protocolo `FD_ALL3` do JGroups com `heartbeat_interval=8000ms` e `timeout=40000ms`, valores padrão do servidor Infinispan 15.0. Esses parâmetros sustentam a duração mínima de 60s do cenário F1 (T17 da Tabela 1) por uma janela superior ao tempo de detecção. O *health check* HTTP em `/rest/v2/.../health/status` é exposto pelos três nós, permitindo que scripts de orquestração esperem o *cluster* estar pronto antes de disparar carga.

## O que isso significa para a monografia

- **Cap. 4 §4.1 (Arquitetura experimental)** pode citar `cluster/podman-compose.yml` e `cluster/infinispan-cluster.xml` no repositório `tcc-desenvolvimento` como artefatos versionados que realizam T1, T2, T3, T4, T15 e T16 da Tabela 1.
- **Cap. 4 §4.4 (Estado dos artefatos)** pode mencionar que os perfis `DIST_SYNC` e `DIST_ASYNC` coexistem no mesmo XML, com seleção em tempo de subida, sustentando a Decisão 014 (T1 da Tabela 1 com modo alvo `DIST_ASYNC` e controle `DIST_SYNC`).
- O texto **não deve afirmar** que o *cluster* foi efetivamente subido e exercido no *sandbox* atual: Podman não está disponível. Toda a frente operacional foi de configuração, não de execução.

## Arquivos no repositório

- `cluster/podman-compose.yml` — orquestração de três nós.
- `cluster/infinispan-cluster.xml` — caches `sessions` e `counters`, perfis SYNC e ASYNC.
- `docs/configuracao-infinispan.md` — documentação técnica do conjunto.
