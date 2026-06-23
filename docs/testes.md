# Testes

> Registro da suíte de testes do *workload* e dos critérios de aceite verificados na frente prática.

## Suíte unitária (JUnit 5)

Execução: `mvn -f workload/pom.xml test`. Estado atual: **49/49 verde**.

| Classe de teste | n | Cobre |
|---|---|---|
| `CliTest` | 9 | parsing Picocli, *defaults*, validação de parâmetros |
| `ScenarioTest` | 3 | mistura S1 50/50, S2 95/5, soma de pesos = 100 |
| `KeyGeneratorTest` | 6 | distribuição Zipfian, reprodutibilidade por seed, cobertura |
| `WarmupPolicyTest` | 7 | fases warm-up/descarte/medição (T11) |
| `LatencyRegistryTest` | 4 | percentis HdrHistogram, dump CSV, supressão por *warm-up* |
| `InvariantAuditorTest` | 5 | violações I1–I6 imediatas e periódicas |
| `OpResultTest` | 8 | mapeamento `Code → return_code` e "só ERROR_TRANSPORT é erro" |
| `EventCsvWriterTest` | 4 | cabeçalho/ordem do CSV, *op_id* crescente, *warm-up* não vaza, `end_ns > start_ns`, sanitização |
| `EpochClockTest` | 3 | conversão monotônico → epoch-ns, preservação de duração |

### Testes do bloco de eventos (T5)

- **Mapeamento de códigos** (`OpResultTest`): cada `OpResult.Code` mapeia
  para o `return_code` canônico aprovado; varre todos os `Code` garantindo
  que apenas `ERROR_TRANSPORT` fique fora do conjunto de sucessos do
  `analysis/percentis.py`.
- **Cabeçalho e ordem** (`EventCsvWriterTest`): o CSV gravado começa
  exatamente com `op_id,operation,start_ns,end_ns,replica,return_code,key`
  e cada linha de dados tem 7 colunas na ordem do cabeçalho; `op_id` é
  estritamente crescente (contador global).
- **Warm-up não vaza**: com `WarmupPolicy.never()`, nenhum evento entra; o
  arquivo contém só o cabeçalho e `descartadosWarmup()` reflete o volume.
- **`end_ns > start_ns`**: validado em 200 linhas geradas; também após a
  conversão epoch-ns em `EpochClockTest`.

## Critérios de aceite integrados (cluster real)

Verificados contra o *cluster* Infinispan size=3 (Podman, imagem
`quay.io/infinispan/server:15.0.21.Final`).

### GATE 1 — formação do *cluster*

```bash
curl -s --digest -u admin:infinispan \
  http://localhost:11222/rest/v2/cache-managers/default/health
# {"cluster_health":{"health_status":"HEALTHY","number_of_nodes":3,...}}
```

Aceite: `health_status = HEALTHY` e `number_of_nodes = 3`, *caches*
`sessions` e `counters` HEALTHY.

### SMOKE (GATE 2) — carga curta + pipeline

Carga de 60s (rep 1, warm-up 10s) contra o *cluster* real; depois
`python percentis.py ../runs/smoke`:

- `runs/smoke/rep-001.csv`: ~540 700 linhas (1 cabeçalho + eventos).
- `return_code`: apenas códigos de sucesso (`BLOCKED`, `COUNTED`, `NONE`);
  **0 `ERROR_TRANSPORT`**.
- `summary.json`: 5 operações canônicas, `n` entre ~27 mil e ~270 mil,
  `taxa_erro = 0,00%` em todas, sem exceção.

Latências observadas (smoke, sem falha): Validate p50 ≈ 0,41 ms / p99 ≈
1,99 ms; Login p50 ≈ 0,46 ms / p99 ≈ 2,63 ms.

## Como reproduzir

```bash
# 1. cluster
cd cluster && podman-compose up -d        # aguardar HEALTHY size=3
# 2. build + suíte
mvn -f workload/pom.xml test              # 49/49
mvn -f workload/pom.xml package
# 3. smoke
java -jar workload/target/session-workload-0.1.0-SNAPSHOT.jar \
  --scenario S1 --duration 60 --warmup-min-sec 10 --rep 1 --csv-dir runs/smoke
cd analysis && python percentis.py ../runs/smoke
# 4. bateria baseline (S1/S2 x none/F1)
bash scripts/run-baseline.sh --reps 3 --duration 120 --warmup-min 20
```
