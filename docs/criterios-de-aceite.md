# Critérios de aceite por bloco

> Critérios objetivos que cada bloco do *backlog* deve cumprir antes de ser considerado concluído. Complementa [`testes.md`](testes.md) (que descreve **como** testar) com **o que** especificamente deve passar por bloco.

## Critérios gerais (aplicáveis a todos os blocos)

1. **Reprodutibilidade.** Comando único documentado executa a entrega; versão de imagem e *checksum* fixados quando aplicável.
2. **Aderência ao Cap. 3 §3.3.5 da monografia.** Cada *feature* mapeia explicitamente para a(s) linha(s) Tx que ela realiza.
3. **Testes.** *Smoke test* mínimo (script ou JUnit) demonstrando que a *feature* funciona ponta-a-ponta.
4. **Documentação.** Atualização de [`implementacao.md`](implementacao.md), [`testes.md`](testes.md) ou de um arquivo em [`resumos-para-tcc/`](resumos-para-tcc/) com cada decisão não-trivial.
5. **Versionamento.** *Commits* no padrão `<tipo>(<escopo>): <descrição>`; *branch* nominal `feature/<nome>`; sem *force-push*; sem *push* para `origin/*` sem aprovação explícita do autor (D-006 rejeitada em 2026-06-14).
6. **Nenhum efeito colateral em** `/workspace/prototipo/` **(congelado) ou em** `/workspace/*.tex` **(monografia).**

## Critérios por bloco

### B-01 — Bootstrap do repositório

- `git status` na *branch* `feature/bootstrap-repo` retorna *working tree clean* após o *commit*.
- `tree -L 2` mostra a estrutura de pastas declarada em [`planejamento-inicial.md`](planejamento-inicial.md).
- `README.md` cita explicitamente `Cap. 3 §3.3.5` e a Tabela 1.

### B-02 — Cluster Infinispan SYNC

- `podman-compose config` valida o YAML.
- `cluster/infinispan-cluster.xml` é XML válido (pode ser checado por `xmllint --noout` se disponível).
- Cobertura T1, T2, T3, T4, T15, T16 documentada em [`configuracao-infinispan.md`](configuracao-infinispan.md).

### B-03 — Variante DIST_ASYNC

- O XML expõe ambos os perfis (`SYNC` e `ASYNC`) num único arquivo, selecionáveis por configuração do *compose*.
- Cobertura T1 (modo alvo `DIST_ASYNC`) documentada.

### B-04 — Esqueleto do workload Java

- `mvn -q compile` passa sem aviso.
- As seis classes-base existem em `workload/src/main/java/br/unipampa/tcc/session/`.
- Cliente Hot Rod 15.0 declarado em `pom.xml`.

### B-05 — Padronização de retorno (`OpResult`)

- Todas as O1 a O7 em `SessionOps` retornam `OpResult`.
- `OpResult.Code` enumera os sete códigos previstos (Cap. 3 §3.3.1).
- `mvn -q test` passa para classes não dependentes do *cluster*.

### B-06 — `LatencyRegistry` com HdrHistogram

- Dependência `org.hdrhistogram:HdrHistogram` em `pom.xml`.
- `LatencyRegistryTest` verifica precisão de p50 e p99 ($\le 1\,\%$ de erro) sobre 10\,000 amostras sintéticas.
- `dumpCsv` produz arquivo com cabeçalho `op,count,mean_ns,p50_ns,p95_ns,p99_ns,p999_ns,max_ns`.
- Cobertura T13.

### B-07 — `InvariantAuditor`

- Checagem imediata para I1 a I4 dentro das operações afetadas.
- Auditoria periódica em *thread* separada para I5 e I6 (com janela configurável).
- `InvariantAuditorTest` valida pelo menos cinco cenários (cada tipo de violação + caso negativo).
- Cobertura M2.

### B-08 — Gerador Zipfian e cenários

- `KeyGeneratorTest` cobre os três critérios principais: distribuição em $10^6$ amostras com erro relativo $< 5\,\%$ nos primeiros 100 *bins*; reprodutibilidade entre instâncias com mesma seed; cobertura $> 30\,\%$ do universo de 100\,000 chaves.
- `ScenarioTest` confirma S1 (50/25/10/10/5) e S2 (95/3/1/1/0) com $< 2\,\%$ de erro empírico.
- Cobertura T5, T6, T7, T8.

### B-09 — *Warm-up* + descarte

- `WarmupPolicy.padrao(0, 600)` produz warm-up = 60\,s e descarte = 27\,s (\(5\,\% \cdot 540\)).
- `WarmupPolicyTest` cobre aritmética para 60\,s, 600\,s e 1800\,s, e predicados mutuamente exclusivos.
- `LatencyRegistry` ignora *records* fora da janela e incrementa contador `descartados`.
- Cobertura T11.

### B-10 — CLI Picocli

- `Cli` declara 11 opções nomeadas conforme [planejamento](planejamento-inicial.md#próxima-tarefa-técnica).
- `--help`, `--version` e `--dry-run` funcionam após `mvn package`.
- *Exit code* 2 para argumento inválido; 3 para falha de execução.
- `CliTest` cobre *defaults*, parsing curto/longo, validação e formato do `toString`.
- Cobertura T7, T9, T10, T11, T14.

### B-11 — `inject-crash.sh`

- `bash -n` passa.
- `--help` mostra usage; `--dry-run` imprime plano.
- Aviso quando `--duration < 40` (timeout T16).
- *Exit code* 2 para argumento inválido; 3 para Podman ausente; 4 para *container* inexistente ou não em *running*.
- Cobertura T17.

### B-12 — `inject-jitter.sh`

- `bash -n` passa.
- `--help` mostra usage; `--dry-run` imprime plano.
- `trap` remove a disciplina `tc` em `EXIT`, `INT` ou `TERM`.
- *Exit code* 2 para argumento inválido; 3 para `tc` ausente; 4 para EPERM (sem NET_ADMIN); 5 para interface inexistente.
- Cobertura T18.

### B-13 — `collect-metrics.sh`

- `bash -n` passa.
- `--help` mostra usage; `--dry-run` imprime plano por host.
- *Manifest* CSV é criado com cabeçalho `timestamp,server,arquivo,status_http,bytes`.
- Aborta após 3 falhas consecutivas no mesmo host (*exit* 4).
- Cobertura T19, T20.

### B-14 e B-15 — Spec TLA+ e *runner* TLC

- `SessionStore.tla` declara seis variáveis, sete ações, seis invariantes I1 a I6.
- `MC-small.cfg`, `MC-medium.cfg` e `MC-full.cfg` instanciam as três cardinalidades T21.
- `./run-tlc.sh small` fecha em segundos sem violação inesperada.

### B-16 a B-18 — Análise estatística Python

- `analysis/percentis.py` produz `summary.json` com p50, p95, p99, p999 por cenário.
- `analysis/bootstrap_ic.py` aplica reamostragem com $\ge 10\,000$ réplicas.
- `analysis/compare_scenarios.py` aplica Mann-Whitney pareado entre dois cenários.
- Pipeline validado em `analysis/exemplo-pipeline/` com dados sintéticos.
- Cobertura T13, T22.

### B-19 — `run-baseline.sh`

- `bash -n` passa.
- `--help`, `--dry-run` mostram plano completo (todas as combinações).
- *Exit code* 2 para `--scenarios` ou `--falhas` inválidos; 3 para *jar* ausente; 4 quando $\ge 1$ combinação termina com erro.
- Estrutura de saída obedece a `runs/<baseline>/<scen>/<falha>/rep-NNN/`.
- Integração com `collect-metrics.sh`, `inject-crash.sh`, `inject-jitter.sh` e `analysis/*.py`.

### B-20 — Documentação consolidada

- `README.md` reflete o estado atual (estado das branches, cobertura Tabela 1, instruções de execução).
- Arquitetura ilustrada com Mermaid (não ASCII-art).
- [`docs/testes.md`](testes.md) e [`docs/criterios-de-aceite.md`](criterios-de-aceite.md) presentes.
- [`docs/configuracao-infinispan.md`](configuracao-infinispan.md), [`docs/implementacao.md`](implementacao.md), [`docs/spec-formal.md`](spec-formal.md) atualizados para refletir o que foi implementado.
- [`docs/resumos-para-tcc/`](resumos-para-tcc/) populado.

## Política de *push*

O critério adicional, vigente desde 2026-06-14, é que **nenhum bloco vai para** `origin/*` **sem aprovação explícita do autor.** A aprovação pode ser por entrega individual ou em lote por *branch* trabalhada, como o Senior achar melhor. Os PRs #1 a #8 já no remoto datam da política anterior (Decisão 014 de 2026-05-25) e ficam como histórico.
