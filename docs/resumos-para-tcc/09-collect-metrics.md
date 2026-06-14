# Coletor de métricas OpenMetrics (B-13)

## O que foi feito

O script `scripts/collect-metrics.sh` coleta o endpoint `/metrics` (formato OpenMetrics) de cada nó Infinispan em intervalos regulares durante uma janela controlada. A coleta cobre as linhas T19 (métricas reportadas) e T20 (endpoint OpenMetrics) da Tabela 1, ambas exigidas para correlacionar variações de latência e taxa de violação com eventos operacionais (RPC, *state transfer*, *heap*, GC, *cluster view*). Cada *snapshot* é salvo como arquivo `.prom` com nome `metrics-<host>-<port>-<YYYYMMDDTHHMMSSZ>.prom`, e um `manifest.csv` indexa o conjunto com `timestamp,server,arquivo,status_http,bytes` para auditoria posterior.

A configuração padrão coleta dos três nós em `127.0.0.1:11222`, `11223` e `11224` a cada 5\,s durante 600\,s (= 360 *snapshots* totais por execução). O script aborta após três falhas consecutivas no mesmo nó (*exit* 4), o que sinaliza que o nó perdeu o endpoint, condição típica de F1 com duração superior ao timeout. O timeout por requisição é 10\,s (`curl --max-time`), suficiente para *probes* em rede local sem suspender a coleta dos demais nós em caso de falha individual.

## O que isso significa para a monografia

- **Cap. 3 §3.3.4** lista M1-M7 e cita Infinispan Metrics como fonte (REF-008); este resumo registra a operacionalização.
- **Cap. 4 §4.3** ao descrever o que é executado durante o *baseline* pode mencionar a coleta paralela ao *workload*, com snapshots a cada 5\,s, e o `manifest.csv` como entrada da análise posterior.

## Arquivos no repositório

- `scripts/collect-metrics.sh` — *poll* e indexação.
- `docs/spec-formal.md` (não diretamente, mas o protocolo TLA+ produz `runs/tlc/output.txt` que é parente desse `manifest.csv` em estrutura).
