# Pipeline end-to-end (B-19)

## O que foi feito

O script `scripts/run-baseline.sh` orquestra a execução completa do *baseline* experimental: combina cenários (T7), modos de falha (T17, T18), repetições (T10), coleta de métricas (T19, T20) e análise estatística (T13, T22), sem repetir nenhuma lógica já implementada nos outros scripts. Para cada combinação $(\text{cenário}, \text{falha}, \text{repetição})$, o script: (1) cria o diretório `runs/<baseline>/<scen>/<falha>/rep-NNN`; (2) inicia `collect-metrics.sh` em segundo plano; (3) inicia o *workload* Java com `--scenario`, `--duration` e `--csv-dir` apontando para o diretório da repetição; (4) dispara `inject-crash.sh` (offset = 1/4 da duração, dura 60\,s) ou `inject-jitter.sh` (offset = 5\,s, dura quase toda a janela) conforme a falha indicada; (5) aguarda o término do *workload* e do coletor; (6) opcionalmente invoca `analysis/percentis.py` ao final de cada `<scen>/<falha>/`, produzindo `summary.json`.

O script tem `--dry-run` que mostra a estrutura prevista e o número total de execuções sem rodar nada (útil para revisar antes de comprometer horas de cluster), `--no-analysis` para pular a fase Python (útil quando só os CSVs são desejados), e `--scenarios`/`--falhas` configuráveis para subconjuntos (por exemplo, `S1` apenas com `none,F1` para piloto). O *exit code* 4 sinaliza que pelo menos uma combinação terminou com aviso de *workload*, sem abortar as demais. Todos os argumentos são validados (cenários em `{S1, S2}`, falhas em `{none, F1, F3}`); valores inválidos produzem *exit* 2 com lista permitida.

## O que isso significa para a monografia

- **Cap. 4 §4.3 (Execução do model checking e estado do baseline)** após a rodada de reescrita de 2026-06-14 já menciona que o pipeline de análise estatística está pronto. Este resumo registra que o orquestrador também está pronto, com `--dry-run` revisável antes do dispêndio operacional.
- **Cap. 5 §5.3 (Próximas etapas)** após a reescrita de 2026-06-14 fala em "execução do baseline em infraestrutura local do autor" — este resumo informa que basta `bash scripts/run-baseline.sh` com Podman e NET_ADMIN disponíveis para reproduzir todo o experimento.

## Arquivos no repositório

- `scripts/run-baseline.sh` — orquestrador.
- `runs/baseline-<TS>/` — diretório de saída por bateria.
- Delegações: `scripts/collect-metrics.sh`, `scripts/inject-crash.sh`, `scripts/inject-jitter.sh`, `analysis/percentis.py`, `workload/target/session-workload-*.jar`.
