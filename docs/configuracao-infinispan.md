# Configuração do *cluster* Infinispan

> Documento técnico que descreve a configuração do *cluster* Infinispan empregada no protótipo do TCC. Mapeia cada decisão de configuração para a(s) linha(s) Tx da Tabela 1 do Cap. 3 §3.3.5 da monografia.

## Arquivos

| Arquivo | Função |
|---|---|
| `cluster/podman-compose.yml` | Orquestra três nós Infinispan em *containers* Podman, com rede *bridge* dedicada e *health check* via REST. |
| `cluster/infinispan-cluster.xml` | Define três *caches* coexistentes: `sessions` (síncrono), `sessions-async` (assíncrono) e `counters` (síncrono), todos com `owners=2`, `segments=64` e `partition-handling=DENY_READ_WRITES`. |

A inicialização ocorre via `cd cluster && podman-compose up -d`. O *health check* é executado pelo Podman a cada 5 s; um nó é considerado saudável quando `GET /rest/v2/cache-managers/default/health/status` retorna 200 com credenciais `admin:infinispan`.

## Caches disponíveis e regra de seleção

| Cache | Modo | Uso previsto |
|---|---|---|
| `sessions` | `DIST_SYNC` | controle de sanidade do *baseline*; escritas síncronas em cenários `DIST_SYNC` |
| `sessions-async` | `DIST_ASYNC` | cenário-alvo do trabalho; mede o comportamento sob replicação otimista |
| `counters` | `DIST_SYNC` | contadores de tentativas falhas (operações O4, O5); mantidos em modo síncrono para isolar a hipótese de violação de monotonicidade na camada assíncrona de `sessions-async` |

A escolha entre `sessions` e `sessions-async` ocorre no programa de carga, pelo parâmetro `--cache` da CLI (a definir em B-10). Os dois *caches* convivem no mesmo *cluster* sem interferência mútua, dado que os segmentos são calculados de forma independente por nome de *cache*. Essa configuração realiza a linha T1 da Tabela 1, que prevê `DIST_ASYNC` como cenário-alvo e `DIST_SYNC` como controle.

## Mapeamento Configuração ↔ Tabela 1

| Linha Tx | Onde realiza | Trecho relevante |
|---|---|---|
| **T1** Modo de replicação | `cluster/infinispan-cluster.xml` | `<distributed-cache name="sessions" mode="SYNC" ...>` e `<distributed-cache name="sessions-async" mode="ASYNC" ...>` cobrem alvo e controle |
| **T2** Número de nós: 3 | `cluster/podman-compose.yml` | Serviços `isn1`, `isn2`, `isn3` |
| **T3** `numOwners` = 2 | `cluster/infinispan-cluster.xml` | `owners="2"` em ambos os *caches* |
| **T4** `numSegments` | `cluster/infinispan-cluster.xml` | `segments="64"` (valor herdado do esqueleto; T4 da tabela cita 256 como padrão Infinispan; o esqueleto adota 64 para reduzir tempo de *state transfer* em ambiente com três nós — desvio justificado a registrar em `docs/decisoes-tecnicas.md` em B-04 ou ajustar para 256 se o autor preferir aderência estrita à Tabela 1) |
| **T15** MTU | herdado da configuração de rede do Podman (*bridge* default 1500) | sem ajuste explícito; equivale ao parâmetro T15 |
| **T16** Detecção de falha FD\_ALL3 | herdada do *stack* JGroups padrão (`default-jgroups-tcp.xml`) | `<stack-file name="cluster-stack" path="default-jgroups-tcp.xml"/>` aplica os defaults (8000 ms / 40000 ms) |
| **T17** Falha F1 (*crash*) | `cluster/podman-compose.yml` define os *containers*; o *crash* será injetado por `scripts/inject-crash.sh` em B-11 | — |
| **T19** Métricas coletadas | `cluster/infinispan-cluster.xml` | `statistics="true"` em `cache-container` e em cada *cache* |
| **T20** Endpoint OpenMetrics | nativo do Infinispan 15 | endpoint exposto por `endpoints socket-binding="default"` |

## Partition Handling

A configuração adota `<partition-handling when-split="DENY_READ_WRITES" merge-policy="PREFERRED_NON_NULL"/>`. Sob partição, a partição minoritária recusa leituras e escritas, e a reconciliação após o merge prefere o valor não-nulo mais recente. Essa escolha alinha-se com o escopo de TCC-I: F2 (partição) está reservado para TCC-II (Decisão 011 ponto 11) e, portanto, esta política funciona como salvaguarda passiva caso o experimento gere partição involuntária.

## Locking e *state transfer*

```
locking: concurrency-level=1000, acquire-timeout=15000, striping=false
state-transfer: enabled=true, timeout=60000
```

- `acquire-timeout=15000` ms está acima do RTT esperado dentro de uma rede *bridge* local e abaixo do *timeout* de detecção de falhas (T16), o que evita que a aquisição de *lock* seja abortada por evento de FD.
- `state-transfer.timeout=60000` ms está alinhado à duração mínima do cenário F1 (T17), que prevê 60 s de indisponibilidade de um nó.

## Variantes pendentes

| Variante | Quando | Branch sugerida |
|---|---|---|
| Perfil `DIST_ASYNC` | B-03 (próximo) | `feature/cluster-async` |
| Stack JGroups customizado (parâmetros explícitos de FD\_ALL3) | a decidir | — |
| Pacote `numSegments=256` alinhado ao default Infinispan | a decidir (vide T4) | — |

## Como subir o *cluster* localmente

```bash
cd cluster
podman-compose up -d
podman-compose ps
```

Para validar o estado:

```bash
curl -s -u admin:infinispan \
  http://localhost:11222/rest/v2/cache-managers/default/health/status
# esperado: HEALTHY
```

Para encerrar:

```bash
podman-compose down
```

## Como verificar conectividade dos nós

```bash
for port in 11222 11223 11224; do
  echo "isn em $port:"
  curl -s -u admin:infinispan \
    http://localhost:$port/rest/v2/cluster/distribution \
    | head -c 200
  echo
done
```

## Decisões a registrar em `docs/decisoes-tecnicas.md`

- T4: aceitar `numSegments=64` do esqueleto ou ajustar para 256.
- Persistir credenciais `admin/infinispan` por enquanto; revisar para variável de ambiente em B-05.
