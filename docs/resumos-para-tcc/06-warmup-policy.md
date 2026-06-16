# Warm-up + descarte de 5% (B-09)

## O que foi feito

A classe `WarmupPolicy` codifica a política T11 da Tabela 1 em três fases consecutivas. A primeira é o **warm-up**: as operações executam mas suas latências não entram no `LatencyRegistry`, com duração igual ao máximo entre 60\,s e 10\,\% da duração total nominal. A segunda é o **descarte**: imediatamente após o warm-up, 5\,\% do tempo restante também não são registrados, como margem de segurança para efeitos transitórios que persistam além da estabilização da JVM (JIT, alocadores, *cache lines*). A terceira é a **medição**, durante a qual as latências de fato compõem o histograma.

A política é imutável após a construção, com `Clock` injetável para testes determinísticos. O `LatencyRegistry` consulta `deveRegistrar()` em cada chamada e incrementa um contador `descartados` por operação quando a chamada cai fora da janela de medição; esse contador permite auditar pós-execução quantas amostras foram suprimidas em cada fase. A integração com o `WorkloadMain` é direta: a política é construída a partir do instante de início e da duração configurada na CLI, e impressa no início da execução para deixar as fronteiras de cada fase explícitas no log.

A escolha de implementar o "descarte das 5\,\% primeiras amostras" como descarte de **5\,\% do tempo de medição** segue de uma limitação técnica do HdrHistogram (que não preserva a ordem das amostras) e da hipótese de taxa estacionária, válida no intervalo logo após o warm-up. A justificativa está registrada como decisão técnica TD-005 em `docs/implementacao.md`.

## O que isso significa para a monografia

- **Cap. 3 §3.3.5** já cita o warm-up de "60\,s ou 10\,\%" + "descarte das 5\,\% primeiras amostras" (T11); este resumo registra que a operacionalização é por tempo proporcional, equivalente sob taxa estacionária.
- **Cap. 4 §4.1** pode mencionar nas próximas versões que a política é codificada como classe própria e testada em ~7 casos JUnit (aritmética para 60s, 600s e 1800s; predicados de fase mutuamente exclusivos).

## Arquivos no repositório

- `workload/src/main/java/br/unipampa/tcc/session/WarmupPolicy.java` — política das três fases.
- `workload/src/main/java/br/unipampa/tcc/session/LatencyRegistry.java` — consulta `deveRegistrar()`.
- `workload/src/test/java/br/unipampa/tcc/session/WarmupPolicyTest.java` — 7 testes.
- `workload/src/test/java/br/unipampa/tcc/session/LatencyRegistryTest.java` — 2 testes adicionais cobrem a integração.
