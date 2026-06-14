# Auditor de invariantes: checagem imediata + auditoria periódica (B-07)

## O que foi feito

A classe `InvariantAuditor` reúne duas frentes de detecção complementares. A **checagem imediata** ocorre dentro de cada operação O1 a O7: quando uma operação de validação (O2) detecta sessão `VALID` enquanto a identidade está `BLOCKED` no mesmo nó, o auditor registra violação de I2; quando `incrementFailure` (O4) observa o contador regredir entre o estado antes e o estado depois, o auditor registra violação de I3. Essas verificações são síncronas e sem custo adicional (uma comparação por op).

A **auditoria periódica** opera em uma *thread* separada que, a cada janela configurável, consulta as réplicas do *cluster* e verifica os predicados de convergência I5 (estado lógico) e I6 (contador e *status*) sob a hipótese de quiescência. Cada violação é registrada em estrutura própria com timestamp, invariante atingido, chaves envolvidas e o snapshot mínimo do estado das réplicas. O contador `total()` retorna o total de violações registradas para reporte no fim da execução. A separação entre checagem imediata e auditoria periódica espelha a Seção §4.1 da monografia (frase "verifica a coerência local ... e periodicamente ... um auditor consulta todas as réplicas").

## O que isso significa para a monografia

- **Cap. 4 §4.1** já cita a estrutura em duas frentes ("imediatamente após cada operação ... e periodicamente, em intervalos configuráveis"); este resumo registra que ela está implementada.
- **Cap. 4 §4.4** após a rodada de 2026-06-14 menciona "auditor que combina verificação imediata após cada operação (I1 a I4) com auditoria periódica em janelas de quiescência (I5 e I6)". Confere com este resumo.
- **Tabela 1** M2 (taxa de violação por invariante) é diretamente sustentada por essa classe.

## Arquivos no repositório

- `workload/src/main/java/br/unipampa/tcc/session/InvariantAuditor.java` — registros + auditoria periódica.
- `workload/src/test/java/br/unipampa/tcc/session/InvariantAuditorTest.java` — cinco testes cobrem registro, contagem e a periódica.
