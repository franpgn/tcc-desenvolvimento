# Workload Java: esqueleto Hot Rod e padronização de retorno (B-04, B-05)

## O que foi feito

O programa de carga é um projeto Maven em `workload/` que produz um *jar shaded* executável. O esqueleto (B-04) trouxe as classes-base `SessionOps`, `SessionState`, `IdentityState`, `LatencyRegistry`, `InvariantAuditor` e `WorkloadMain`, com integração efetiva ao cliente Hot Rod 15.0 do Infinispan. A operação O1 (`login`) abre conexão, cria uma entrada no *cache* `sessions`, e dispara `IdentityState.criar()` para identidades novas no *cache* `counters`. As operações O2 a O7 implementam validar, *logout* (idempotente), incrementar contador (com bloqueio automático ao atingir o limiar), reset, bloqueio administrativo (que invalida sessões válidas) e desbloqueio.

A padronização de retorno (B-05) introduziu o tipo `OpResult` como contrato único: cada operação devolve um `OpResult` com `Code` em `{OK_LOGIN, OK_VALIDATE, OK_STATUS, OK_NOOP, BLOCKED, NOT_FOUND, ERROR_TRANSPORT}` e *payload* opcional (`sessionId`, `estado`, `status`). Antes desse refactor, as operações retornavam tipos heterogêneos (`String`, `Estado`, `Status`, `void`), o que dificultava auditoria, instrumentação e análise tabular. A homogeneização tornou o código do auditor e da CLI imediatamente mais simples e suportou a evolução subsequente do `InvariantAuditor` (B-07).

## O que isso significa para a monografia

- **Cap. 4 §4.1** pode citar que o programa de carga conecta-se ao *cluster* via Hot Rod e implementa as operações O1 a O7 declaradas em Cap. 3 §3.3.1 com **um único tipo de retorno** que captura código, *payload* e mensagem opcional. Essa formulação é coerente com a literatura de teste de armazenamentos chave-valor.
- **Cap. 4 §4.4** já cita "as operações O1 a O7 padronizadas sob um tipo único de retorno" depois da rodada de reescrita de 2026-06-14; este resumo sustenta a frase com detalhes do que esse contrato cobre.

## Arquivos no repositório

- `workload/pom.xml` — projeto Maven com dependências Hot Rod, Micrometer, HdrHistogram, Jackson, Picocli, JUnit.
- `workload/src/main/java/br/unipampa/tcc/session/SessionOps.java` — implementação O1-O7.
- `workload/src/main/java/br/unipampa/tcc/session/SessionState.java`, `IdentityState.java` — modelos de estado.
- `workload/src/main/java/br/unipampa/tcc/session/OpResult.java` — tipo único de retorno.
- `workload/src/main/java/br/unipampa/tcc/session/WorkloadMain.java` — ponto de entrada e *thread pool*.
