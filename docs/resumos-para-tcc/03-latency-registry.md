# Registro de latência com HdrHistogram (B-06)

## O que foi feito

A classe `LatencyRegistry` substituiu uma instrumentação inicial baseada em `ConcurrentLinkedQueue` por um registro thread-safe baseado em HdrHistogram (`org.hdrhistogram:HdrHistogram:2.2.2`). Para cada nome de operação criou-se um `Recorder` dedicado, com precisão de três dígitos significativos no intervalo de 1\,$\mu$s a 60\,s, o que permite extrair p50, p95, p99 e p99,9 com baixo erro de quantização. A classe oferece `record(op, t0)` que computa o delta de `System.nanoTime`, faz *clamp* nos limites e adiciona ao histograma, e `dumpCsv(destino)` que produz um arquivo CSV com uma linha por operação (campos: `op`, `count`, `mean_ns`, `p50_ns`, `p95_ns`, `p99_ns`, `p999_ns`, `max_ns`).

A escolha do HdrHistogram contrasta com listas de amostras: o histograma tem custo $O(1)$ por inserção sem alocação, ocupa memória limitada (alguns kilobytes por op), e permite *snapshot* do intervalo sem bloqueio do produtor. Esse desenho é o que sustenta o volume de $10^6$ operações por execução (T9) com 30 repetições por cenário (T10) sem pressão de memória.

## O que isso significa para a monografia

- **Cap. 4 §4.1** pode citar "instrumentação de latência baseada em HdrHistogram com despejo em CSV" — formulação já presente após a rodada de reescrita de 2026-06-14 (E-06).
- **Cap. 4 §4.4** pode complementar com o detalhe de precisão (três dígitos significativos no intervalo 1\,$\mu$s a 60\,s) e com o argumento de custo constante por inserção, que é o que torna T9 + T10 viáveis sem agregação reativa.
- **Tabela 1** linha T13 (percentis reportados) é diretamente sustentada por essa classe.

## Arquivos no repositório

- `workload/src/main/java/br/unipampa/tcc/session/LatencyRegistry.java` — `Recorder` por op + `dumpCsv`.
- `workload/src/test/java/br/unipampa/tcc/session/LatencyRegistryTest.java` — precisão dos percentis e formato do CSV.
