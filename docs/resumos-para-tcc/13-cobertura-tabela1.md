# Cobertura da Tabela 1 do Cap. 3 §3.3.5 — estado em 2026-06-14

> Mapeamento entre cada linha T1 a T22 da Tabela 1 (Cap. 3 §3.3.5) e o artefato que a realiza no repositório `tcc-desenvolvimento`. Status: ✅ implementado e testado; ⚠️ implementado mas não exercido contra cluster vivo; ❌ não realizável no sandbox atual.

| ID | Parâmetro | Status | Artefato | Resumo associado |
|---|---|---|---|---|
| **T1** | Modo de replicação (`DIST_SYNC`, `DIST_ASYNC`) | ⚠️ | `cluster/infinispan-cluster.xml` | [01-cluster](01-cluster-infinispan.md) |
| **T2** | Número de nós (3) | ⚠️ | `cluster/podman-compose.yml` | [01-cluster](01-cluster-infinispan.md) |
| **T3** | `numOwners=2` | ⚠️ | `cluster/infinispan-cluster.xml` | [01-cluster](01-cluster-infinispan.md) |
| **T4** | `numSegments=64` | ⚠️ | `cluster/infinispan-cluster.xml` | [01-cluster](01-cluster-infinispan.md) |
| **T5** | Payload 1 KiB | ✅ | `KeyGenerator.java`, `SessionOps.java` | [05-keygen](05-keygenerator-scenario.md) |
| **T6** | Distribuição Zipfian $\rho=0{,}99$ | ✅ | `KeyGenerator.java` | [05-keygen](05-keygenerator-scenario.md) |
| **T7** | Mistura S1 50/50 e S2 95/5 | ✅ | `Scenario.java`, `Cli.java` | [05-keygen](05-keygenerator-scenario.md), [07-cli](07-cli-picocli.md) |
| **T8** | Cardinalidade 100\,000 | ✅ | `KeyGenerator.java` | [05-keygen](05-keygenerator-scenario.md) |
| **T9** | $10^6$ operações por execução | ✅ | `Cli.java --ops` | [07-cli](07-cli-picocli.md) |
| **T10** | 30 repetições por cenário | ✅ | `Cli.java --rep`, `run-baseline.sh` | [07-cli](07-cli-picocli.md), [12-baseline](12-run-baseline.md) |
| **T11** | Warm-up + descarte | ✅ | `WarmupPolicy.java`, `LatencyRegistry.java` | [06-warmup](06-warmup-policy.md) |
| **T12** | Carga = 75\% do pico do piloto | ❌ | depende de calibração com cluster vivo | — |
| **T13** | Percentis p50, p95, p99 (e p99,9 quando $n \ge 10^6$) | ✅ | `LatencyRegistry.java`, `analysis/percentis.py` | [03-latency](03-latency-registry.md), [11-analysis](11-analysis-python.md) |
| **T14** | 10\,min sem falha; 30\,min com falha | ✅ | `Cli.java --duration` | [07-cli](07-cli-picocli.md) |
| **T15** | MTU 1500 | ⚠️ | herdado do Podman default | [01-cluster](01-cluster-infinispan.md) |
| **T16** | FD_ALL3 padrão (8\,s heartbeat, 40\,s timeout) | ⚠️ | `cluster/infinispan-cluster.xml` | [01-cluster](01-cluster-infinispan.md) |
| **T17** | F1 crash 60\,s mínimo | ⚠️ | `scripts/inject-crash.sh` | [08-scripts-falha](08-scripts-injecao-falha.md) |
| **T18** | F3 +50\,ms p99 lognormal | ⚠️ | `scripts/inject-jitter.sh` | [08-scripts-falha](08-scripts-injecao-falha.md) |
| **T19** | Métricas M1-M7 coletadas | ⚠️ | `scripts/collect-metrics.sh` | [09-metrics](09-collect-metrics.md) |
| **T20** | Endpoint OpenMetrics | ⚠️ | `scripts/collect-metrics.sh` | [09-metrics](09-collect-metrics.md) |
| **T21** | TLC 2-2-2, 3-3-2, 3-3-3 | ✅ | `spec/SessionStore.tla`, `spec/run-tlc.sh` | [10-spec](10-spec-tla-tlc.md) |
| **T22** | Mann-Whitney + bootstrap 10\,000 | ✅ | `analysis/bootstrap_ic.py`, `analysis/compare_scenarios.py` | [11-analysis](11-analysis-python.md) |

## Legenda do status

- **✅** O artefato está implementado, foi exercido (com testes JUnit, smoke-test ou dados sintéticos validados) e produz resultado compatível com a linha da Tabela 1.
- **⚠️** O artefato está implementado e os smoke-tests sem cluster passam, mas o comportamento real só é confirmado em ambiente com Podman, `NET_ADMIN` ou cluster vivo. Estes itens são entregáveis condicionais de TCC-I conforme Cap. 4 §4.3 reescrito em 2026-06-14.
- **❌** O artefato depende de medição contra cluster vivo que não pode ser feita no sandbox atual; sua execução é pré-requisito de outro item (T12 depende de uma rodada-piloto sem falhas para encontrar o pico).

## Síntese

Dos 22 parâmetros, 11 estão em ✅ no sandbox, 10 em ⚠️ (executáveis na máquina do autor), 1 em ❌ (depende de medição). A frente formal (T21) é integralmente coberta com cinco rodadas executadas; o modelo de carga (T5-T11, T13, T14, T22) também está coberto com testes; o cluster e as falhas (T1-T4, T15-T20) estão prontos mas aguardam ambiente.

Esta cobertura sustenta a frase de **Cap. 4 §4.4 (Estado dos artefatos)** após a reescrita de 2026-06-14: "Os artefatos versionados no repositório `tcc-desenvolvimento` cobrem, ao final do Trabalho de Conclusão de Curso~I, três frentes integradas". O Cap. 5 §5.2 reflete corretamente que o *baseline* depende de ambiente operacional, não de implementação.
