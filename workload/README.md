# workload

Programa de carga em Java 17 + Hot Rod, que gera operações concorrentes sobre os *caches* `sessions` / `sessions-async` / `counters` do *cluster* Infinispan e registra latência e violações de invariantes.

## Status

Esqueleto migrado de `/workspace/prototipo/workload/` em B-04. As classes compilam, mas a lógica completa das operações O1-O7, do gerador Zipfian, do *warm-up* parametrizado e da CLI será materializada por B-05 a B-10 do *backlog*.

Componentes presentes:

| Classe | Responsabilidade |
|---|---|
| `WorkloadMain` | Ponto de entrada; analisa argumentos, instancia o `RemoteCacheManager` e dispara *threads* |
| `SessionOps` | Implementação das operações O1-O7 sobre Hot Rod |
| `SessionState`, `IdentityState` | Modelos do estado representado nos *caches* |
| `LatencyRegistry` | Registro de latência por operação (será evoluído para HdrHistogram em B-06) |
| `InvariantAuditor` | Checagem imediata de invariantes I1-I4 e auditoria periódica de I5/I6 (B-07) |

## Compilação

```bash
cd workload
mvn -q package
```

Produz `target/session-workload-0.1.0-SNAPSHOT-shaded.jar` (uberjar pelo *Maven Shade Plugin*).

## Execução (placeholder até B-10)

A CLI atual aceita argumentos posicionais:

```bash
java -jar target/session-workload-0.1.0-SNAPSHOT-shaded.jar \
     <duração_segundos> <threads> <host:port,host:port,...>
```

Exemplo:

```bash
java -jar target/session-workload-0.1.0-SNAPSHOT-shaded.jar \
     60 8 127.0.0.1:11222,127.0.0.1:11223,127.0.0.1:11224
```

A CLI parametrizada conforme T7 (mistura 50/50 ou 95/5), T9 (10⁶ operações), T10 (30 repetições) e T11 (*warm-up* + descarte) será introduzida por B-10.

## Dependências relevantes

- `org.infinispan:infinispan-client-hotrod:15.0.0.Final`  — cliente Hot Rod alinhado ao servidor.
- `io.micrometer:micrometer-core:1.13.0`  — base para exportação de métricas (futura integração OpenMetrics em B-13).
- `com.fasterxml.jackson:jackson-databind:2.17.0`  — serialização dos `runs/<scenario>/summary.json`.
- `org.junit.jupiter:junit-jupiter:5.10.2`  — *smoke tests* a partir de B-05.

## Próximas tarefas previstas

- **B-05** — Implementação efetiva de O1-O7 com Hot Rod, códigos de retorno conforme Cap. 3 §3.3.1.
- **B-06** — `LatencyRegistry` baseado em HdrHistogram, com *dump* CSV por operação.
- **B-07** — Auditor com checagem imediata para I1-I4 e auditoria periódica para I5/I6 sob quiescência.
- **B-08** — Gerador de chaves com distribuição Zipfian ρ = 0,99, 100 000 chaves, *payload* fixo de 1 KB.
- **B-09** — *Warm-up* de 60 s ou 10 % da execução; descarte das primeiras 5 % das amostras.
- **B-10** — CLI parametrizada (cenário S1/S2, duração, *target throughput*, repetições, *cache* alvo).
