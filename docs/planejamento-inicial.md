# Planejamento Inicial do Desenvolvimento Prático do TCC

> Primeira entrega do fluxo de desenvolvimento prático, produzida em 2026-05-25. A execução de qualquer tarefa técnica depende da aprovação prévia do autor.

## Objetivo do projeto prático

Construir o artefato experimental descrito no Capítulo 4 da monografia, capaz de **(a)** instanciar um *cluster* Infinispan em três nós com replicação assíncrona, **(b)** executar um *workload* parametrizado que gera as operações de sessão O1 a O7 sobre os *caches* `sessions` e `counters`, **(c)** injetar de forma reproduzível as falhas F1 (*crash* silencioso) e F3 (atraso e *jitter* de mensagens), **(d)** coletar latência por operação e taxa de violação dos invariantes I1 a I6 declarados no Cap. 3 §3.3.3, e **(e)** disponibilizar, lado a lado, a especificação TLA+ correspondente para *model checking* incremental. A meta para TCC-I é o ***baseline* parcial sob F1 e F3** previsto para as Semanas 9 e 10 do cronograma.

## Relação com o TCC

O TCC está estruturado em cinco capítulos. As decisões de implementação derivam diretamente de:

- **Cap. 1 §1.2 (Problema de pesquisa)** — define a questão central de especificar e verificar invariantes de sessão em *data grids* sob replicação assíncrona e falhas.
- **Cap. 3 §3.3.1 (Operações modeladas)** — fixa O1 a O7 com pré-condições, efeitos e códigos de retorno.
- **Cap. 3 §3.3.2 (Modelo de falhas)** — fixa F1 e F3 como obrigatórias para TCC-I; F2 e F4 ficam para TCC-II.
- **Cap. 3 §3.3.3 (Invariantes-alvo)** — I1 a I6, com I1 a I4 verificáveis no modelo formal inicial e I5 a I6 sob quiescência.
- **Cap. 3 §3.3.4 (Métricas e critérios)** — M1 a M7, com latência por operação, taxa de violação, tempo de recuperação, tempo de convergência, taxa de erro e métricas sistêmicas via Infinispan Metrics.
- **Cap. 3 §3.3.5 (Parâmetros experimentais)** — Tabela 1 com os 22 parâmetros do *baseline* e suas fontes bibliográficas; é o **contrato** que o protótipo deve realizar.
- **Cap. 4 §4.1 (Arquitetura experimental)** — define `DIST_SYNC` e `DIST_ASYNC` como modos de execução, `numOwners=2`, *containers* Podman, `tc-netem` para F3.
- **Cap. 4 §4.4 (Estado dos artefatos)** — o Cap. 4 declara que `/workspace/prototipo/` contém o *esqueleto* dos três artefatos (compose, *workload*, spec TLA+) ao fim da Semana 8.

A consequência operacional: a Tabela 1 do Cap. 3 §3.3.5 é o **especificação executável** do *baseline*; o desenvolvimento prático no repositório `tcc-desenvolvimento` precisa realizar cada linha T1 a T22 de forma observável.

## Estado atual do repositório

- *Checkout* local em `/workspace/tcc-desenvolvimento/` — diretório criado, remoto HTTPS reconfigurado (`origin = https://github.com/franpgn/tcc-desenvolvimento.git`).
- Remoto GitHub: **vazio** (zero refs; nenhum *commit*, nenhuma *branch*, nenhuma *tag*).
- Conteúdo local antes desta entrega: somente `.git/`. Após esta entrega: este arquivo `docs/planejamento-inicial.md`.
- *Branch* corrente (HEAD): `main` (configurada em `.git/config`, ainda sem *commit* inicial).

## Esqueleto pré-existente em `/workspace/prototipo/` (referência, não modificar)

O Cap. 4 §4.4 da monografia declara como entregue ao fim da Semana 8 um esqueleto que **pertence à estrutura do TCC** e, portanto, não é modificado pelo trabalho neste repositório. O esqueleto tem o seguinte estado:

| Caminho | Tipo | Estado |
|---|---|---|
| `podman-compose.yml` | Orquestração | 3 nós `quay.io/infinispan/server:15.0`, rede `infinispan-net`, *health check* via `/rest/v2/.../health/status`, portas 11222/11223/11224 |
| `cluster/infinispan-cluster.xml` | Configuração de *cache* | *Caches* `sessions` e `counters` em `DIST_SYNC`, `owners=2`, `segments=64`, `partition-handling=DENY_READ_WRITES`, `merge-policy=PREFERRED_NON_NULL` |
| `workload/pom.xml` | Maven | Esqueleto Java 17 (sem dependência Hot Rod efetiva ainda) |
| `workload/src/.../session/*.java` | Java | Seis classes-esqueleto: `SessionState`, `IdentityState`, `LatencyRegistry`, `InvariantAuditor`, `SessionOps`, `WorkloadMain` (sem lógica de conexão Hot Rod nem execução real) |
| `spec/SessionStore.tla` | TLA+ | Operações `Login`, `Logout`, `IncrementFailure`, `Block` + `EntregaMensagem`; invariantes I1, I2, I3, I4. **Faltam:** `Validate`, `ResetFailures`, `Unblock`, e os invariantes de convergência I5/I6 sob quiescência |
| `spec/SessionStore.cfg` | Config TLC | Presente (não inspecionado nesta etapa) |
| `scripts/` | Vazio | Scripts de injeção de F1/F3 ainda não criados |

**Decisão proposta ao autor (D-001):** o repositório `tcc-desenvolvimento` **espelha e evolui** o esqueleto de `/workspace/prototipo/`. A migração inicial copia o conteúdo e organiza segundo o padrão de repositório Git; a partir daí, todo desenvolvimento ocorre exclusivamente em `tcc-desenvolvimento/`, e `prototipo/` fica congelado como *snapshot* coerente com o texto entregue do Cap. 4 §4.4. O caminho alternativo (recomeçar do zero em `tcc-desenvolvimento`) implica retrabalho sem ganho técnico e desalinha texto e código.

## Tecnologias identificadas

| Camada | Tecnologia | Versão prevista | Fonte no TCC |
|---|---|---|---|
| Servidor de *data grid* | Infinispan Server | 15.0 (`quay.io/infinispan/server:15.0`) | Cap. 4 §4.1; `podman-compose.yml` |
| Cliente | Hot Rod (cliente Java oficial) | alinhada ao servidor 15.0 | Cap. 4 §4.1 |
| Linguagem do *workload* | Java | 17 (LTS) | `prototipo/workload/pom.xml` |
| Build | Maven | 3.9+ | idem |
| Containerização | Podman + podman-compose | última estável | Cap. 4 §4.1 |
| Especificação formal | TLA+ + TLC | `tla2tools.jar` | Cap. 4 §4.2; Cap. 3 §3.3.5 T21 |
| Métricas | OpenMetrics endpoint do servidor | nativo do Infinispan 15 | Cap. 3 §3.3.4; REF-008 |
| Injeção de falha F1 | `podman stop` / `podman pause` | nativo | Cap. 3 §3.3.2 / Cap. 4 §4.3 |
| Injeção de falha F3 | `tc qdisc … netem delay lognormal` | Linux iproute2 | idem |
| Análise estatística | Python + NumPy/SciPy ou R | a definir (P-011/CAND-020) | Cap. 3 §3.3.5 T22 |

**Pontos abertos (P-A1).** Plataforma do *workload* foi fixada em Java/Hot Rod pelo Cap. 4; manter. **Pontos abertos (P-A2).** Linguagem de análise estatística não está fixada no texto — *default* sugerido: Python (SciPy + Matplotlib). Decisão do autor.

## Arquitetura inicial proposta

```
┌──────────────────────────────────────────────────────────────────┐
│  Host (Linux + Podman)                                           │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  Rede bridge `infinispan-net`                              │ │
│  │                                                            │ │
│  │  ┌──────┐    ┌──────┐    ┌──────┐                          │ │
│  │  │ isn1 │    │ isn2 │    │ isn3 │  Infinispan 15.0         │ │
│  │  │ HotRod│   │ HotRod│   │ HotRod│  caches: sessions,      │ │
│  │  │11222 │    │11222 │    │11222 │           counters       │ │
│  │  └──────┘    └──────┘    └──────┘  modo: SYNC|ASYNC        │ │
│  └─────────────────────────────────────────────────────────────┘ │
│         ▲           ▲           ▲                                │
│         │           │           │  Hot Rod                       │
│         └───────────┼───────────┘                                │
│                     │                                            │
│  ┌──────────────────────────────────┐  ┌──────────────────────┐  │
│  │  workload (Java 17)              │  │ scripts/             │  │
│  │  - SessionOps O1..O7             │  │  inject-crash.sh F1  │  │
│  │  - LatencyRegistry (ns)          │  │  inject-jitter.sh F3 │  │
│  │  - InvariantAuditor I1..I6       │  │  collect-metrics.sh  │  │
│  │  - WorkloadMain (CLI)            │  └──────────────────────┘  │
│  └──────────────────────────────────┘                            │
│                                                                  │
│  ┌──────────────────────────────────┐  ┌──────────────────────┐  │
│  │  spec/ (TLA+ + TLC)              │  │ analysis/ (Python)   │  │
│  │  - SessionStore.tla              │  │  - parse_logs.py     │  │
│  │  - SessionStore.cfg              │  │  - percentis.py      │  │
│  │  - run-tlc.sh                    │  │  - bootstrap_ic.py   │  │
│  └──────────────────────────────────┘  └──────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

A arquitetura é **horizontal** sobre o servidor Infinispan e **vertical** entre as três camadas (especificação formal, execução experimental, análise estatística). A integração entre as três camadas é assíncrona e baseada em arquivos: o *workload* escreve `runs/<scenario>/<rep>/{latencies.csv, violations.csv, errors.csv}`; o `analysis/` consome esses arquivos e produz `runs/<scenario>/summary.json` com p50, p95, p99, IC *bootstrap* e M2; o `spec/` produz separadamente `runs/tlc/<config>/output.txt` com o veredito do *model checker*.

## Módulos previstos

| Módulo | Propósito | Origem | Estado planejado em TCC-I |
|---|---|---|---|
| `cluster/` | Configuração do Infinispan e do `podman-compose` | espelho do `prototipo/` | executável |
| `workload/` | *Workload* Java com Hot Rod, O1-O7, auditor de invariantes, registro de latência | espelho do `prototipo/` + implementação dos *stubs* | executável; cobre Cenário S1 (50/50) e S2 (95/5) |
| `scripts/` | *Shell scripts* de injeção de falha, *warmup*, coleta | novo | F1 + F3 prontos; F2 + F4 *placeholders* |
| `spec/` | Especificação TLA+ + cfg TLC + *script* de execução | espelho do `prototipo/` + complementos (O2, O5, O7; I5, I6 sob quiescência) | TLC executável em 3 configurações (2-2-2, 3-3-2, 3-3-3) |
| `analysis/` | *Scripts* Python de parsing, percentis e *bootstrap* | novo | gera `summary.json` por cenário |
| `runs/` | Saídas brutas e consolidadas dos experimentos | gerado em tempo de execução | versionado por *git-lfs* opcional ou ignorado conforme decisão do autor (P-A3) |
| `docs/` | Documentação técnica (este planejamento, arquitetura, *backlog*, testes, decisões, *roadmap*) | novo | completo ao fim do TCC-I |
| `.github/` | *Workflows* CI opcionais (lint Java, *mvn verify*, validação de TLC) | novo, opcional | a decidir (P-A4) |

## Backlog inicial

Cada item do *backlog* é uma *issue* candidata; cada um vira `feature/<nome>` quando aprovado pelo autor. A ordem reflete dependências técnicas, não prioridade absoluta.

| ID | Item | Branch sugerida | Cobertura na Tabela 1 do Cap. 3 §3.3.5 |
|---|---|---|---|
| B-01 | *Bootstrap* do repositório: `README.md`, `.gitignore`, `LICENSE`, `docs/` inicial, `CONTRIBUTING.md` mínimo | `feature/bootstrap-repo` | — |
| B-02 | Migração do `cluster/` (compose + xml) do `prototipo/` para `tcc-desenvolvimento/` | `feature/cluster-infinispan` | T1, T2, T3, T4, T15, T16 |
| B-03 | Configuração de variante `DIST_ASYNC` do *cache* `sessions` (perfil alternativo do XML) | `feature/cluster-async` | T1 (modo alvo) |
| B-04 | Migração do esqueleto Java do *workload* + dependências Hot Rod efetivas | `feature/workload-bootstrap` | — |
| B-05 | Implementação de O1-O7 com chamada Hot Rod real e códigos de retorno | `feature/workload-operations` | T7 |
| B-06 | `LatencyRegistry` com HdrHistogram + dump CSV | `feature/workload-latency` | T13, T14 |
| B-07 | `InvariantAuditor` com checagem imediata I1-I4 + auditoria periódica para I5/I6 | `feature/workload-auditor` | M2 |
| B-08 | Gerador de carga com Zipfian (`ρ=0,99`), 100 000 chaves, *payload* 1 KB | `feature/workload-load` | T5, T6, T8, T9 |
| B-09 | *Warm-up* (60 s ou 10 %) + descarte das primeiras 5 % das amostras | `feature/workload-warmup` | T11 |
| B-10 | CLI parametrizada: cenário, duração, *target throughput*, repetições | `feature/workload-cli` | T10, T12, T14 |
| B-11 | `scripts/inject-crash.sh` (F1 via `podman stop` por 60 s) | `feature/falha-f1-crash` | T17 |
| B-12 | `scripts/inject-jitter.sh` (F3 via `tc netem` lognormal +50 ms p99) | `feature/falha-f3-jitter` | T18 |
| B-13 | Coletor de métricas OpenMetrics (snapshot a cada 5 s) | `feature/metrics-collector` | T19, T20 |
| B-14 | Migração do `spec/SessionStore.tla` + complemento (O2, O5, O7 e I5/I6) | `feature/spec-completa` | T21 |
| B-15 | `spec/run-tlc.sh` com três configurações (2-2-2, 3-3-2, 3-3-3) | `feature/spec-tlc-runner` | T21 |
| B-16 | `analysis/parse_logs.py` + `analysis/percentis.py` (p50, p95, p99) | `feature/analysis-percentis` | T13 |
| B-17 | `analysis/bootstrap_ic.py` (IC 95 % por *bootstrap* 10 000) | `feature/analysis-bootstrap` | T22 |
| B-18 | `analysis/compare_scenarios.py` (Mann-Whitney pareado por percentil) | `feature/analysis-mwu` | T22 |
| B-19 | Pipeline de execução *end-to-end* (`scripts/run-baseline.sh`) | `feature/pipeline-baseline` | integra T9-T14, T17, T18 |
| B-20 | Documentação consolidada: `README.md`, `docs/configuracao-infinispan.md`, `docs/implementacao.md`, `docs/testes.md` | `docs/consolidacao-final` | — |

## Ordem sugerida de implementação

1. **Bloco fundação:** B-01 → B-02 → B-04. Resultado: repositório com *cluster* configurado e esqueleto Java migrado.
2. **Bloco execução nominal:** B-05 → B-06 → B-08 → B-09 → B-10. Resultado: *workload* roda contra `DIST_SYNC` e produz CSV de latência sem falhas.
3. **Bloco auditoria:** B-07 → B-13. Resultado: violações de I1-I4 e métricas de RPC são registradas.
4. **Bloco falhas:** B-03 (perfil ASYNC) → B-11 (F1) → B-12 (F3). Resultado: cenários completos S1/S2 × {sem-falha, F1, F3} × {SYNC, ASYNC} reproduzíveis.
5. **Bloco formal:** B-14 → B-15. Resultado: TLC executa três configurações; vereditos no `runs/tlc/`.
6. **Bloco análise:** B-16 → B-17 → B-18. Resultado: `summary.json` por cenário com percentis, IC e Mann-Whitney.
7. **Bloco entrega:** B-19 → B-20. Resultado: pipeline `run-baseline.sh` executa todo o experimento; documentação consolidada.

Em paralelo: **resumo técnico para o TCC** a cada bloco fechado, dentro de `docs/resumos-para-tcc/`, para alimentar a escrita acadêmica.

## Critérios de aceite (gerais)

Aplicáveis a todo item do *backlog* antes da entrega ser considerada concluída:

1. **Reprodutibilidade.** Comando único documentado executa a *feature*. Versão da imagem e *checksum* fixados.
2. **Aderência ao Cap. 3 §3.3.5.** Cada *feature* mapeia explicitamente para a(s) linha(s) Tx que ela realiza.
3. **Testes.** *Smoke test* mínimo (script ou JUnit) demonstrando que a *feature* funciona ponta-a-ponta.
4. **Documentação.** Atualização de `docs/implementacao.md` e `docs/decisoes-tecnicas.md` com cada decisão não-trivial.
5. **Versionamento.** Commits no padrão `<tipo>: <descrição>`. *Branch* da *feature*. Sem *force-push*.
6. **Nenhum efeito colateral em `/workspace/prototipo/` ou em `/workspace/*.tex`.**

Critérios específicos por *feature* são detalhados em `docs/criterios-de-aceite.md` (a criar quando este planejamento for aprovado e B-01 for expandido).

## Riscos técnicos

| Risco | Probabilidade | Impacto | Mitigação |
|---|---|---|---|
| R-01: cliente Hot Rod 15.0 incompatível com Maven Central no *sandbox* | Média | Alto (bloqueia B-04) | Fixar `<repositories>` do Red Hat GA; *vendor* opcional via `mvn dependency:go-offline` |
| R-02: `tc netem` exige `NET_ADMIN` no *container* alvo | Alta | Alto (bloqueia F3) | Aplicar `tc` no *host*, na interface de *bridge*, ou conceder `--cap-add=NET_ADMIN` ao serviço afetado |
| R-03: *clusterização* falha em `DIST_ASYNC` sob carga alta | Média | Médio (afeta B-03) | *Health check* já presente; ajustar `state-transfer.timeout` se necessário; documentar como limitação se persistir |
| R-04: TLC explode espaço de estados em configuração 3-3-3 | Média | Médio (afeta B-15) | Cardinalidades em escada (REF-018); aceitar `3-3-2` como teto se 3-3-3 ultrapassar 30 min |
| R-05: Volume de saída do *workload* (10⁶ ops × 30 reps × N cenários) | Média | Médio | Compactação LZ4 ou *streaming aggregation* dentro do `LatencyRegistry`; descartar latências brutas após agregação |
| R-06: tempo de execução total acima do disponível | Média | Alto | Reduzir repetições para piloto (5) antes da rodada final (30); cenários executados sob fim de semana |
| R-07: `git push` exige autenticação para o GitHub | Alta | Baixo (o autor executa) | Documentar; nunca tentar `push` no fluxo automatizado |

## Pontos que precisam de validação do autor

- **D-001.** Aprovar a migração do esqueleto `/workspace/prototipo/ → /workspace/tcc-desenvolvimento/` versus *bootstrap* limpo.
- **D-002.** Aprovar Java 17 + Maven como *toolchain* obrigatório do *workload* (mantém o que está no `prototipo/`).
- **D-003.** Aprovar Python (SciPy/Matplotlib) como *toolchain* da camada `analysis/`. Alternativa: R.
- **D-004.** Aprovar o fluxo de *branch* — `main` como linha de entrega e *feature branches* por item do *backlog*; sem *develop* intermediária (P-A5).
- **D-005.** Autorizar (ou não) o uso de Git LFS / extensão para versionar saídas em `runs/`. Alternativa: `runs/` em `.gitignore` e produzir apenas `summary.json` versionado.
- **D-006.** Autorizar criação do *commit* inicial e do *push* para `origin/main` após aprovação deste documento. Sem aprovação, tudo permanece local.
- **D-007.** Confirmar que **B-01 pode iniciar** assim que houver aprovação, ou ajustar a ordem.
- **D-008.** Confirmar se a análise estatística (B-16 a B-18) é entregável de TCC-I ou pode escorrer para TCC-II caso o cronograma aperte (escolha entre escopo e profundidade).
- **D-009.** Definir a política de tratamento das variantes `DIST_SYNC` vs `DIST_ASYNC`: ambas no *baseline* de TCC-I ou apenas `DIST_ASYNC` (alvo) com `DIST_SYNC` apenas como controle de sanidade?

## Próxima tarefa técnica

Após aprovação deste planejamento, executar **B-01 — *Bootstrap* do repositório** na *branch* `feature/bootstrap-repo`, com o seguinte escopo:

1. Criar `README.md` na raiz, com seções: visão geral, vínculo com o TCC, estrutura de pastas, *quickstart* (subir *cluster*, rodar *workload*, rodar TLC), tabela de cobertura T1-T22.
2. Criar `.gitignore` cobrindo `target/`, `runs/`, `*.log`, `.idea/`, `.vscode/`, `*.class`.
3. Criar `LICENSE` (MIT ou alinhada ao orientador — autor decide; *default* MIT).
4. Criar `CONTRIBUTING.md` curto descrevendo o fluxo de planejamento, execução, revisão e validação, além do padrão de commits e *branches*.
5. Criar diretórios vazios com `.gitkeep`: `cluster/`, `workload/`, `scripts/`, `spec/`, `analysis/`, `runs/`, `docs/resumos-para-tcc/`.
6. Manter este `docs/planejamento-inicial.md` na raiz de `docs/`.
7. *Commit* inicial: `chore: bootstrap inicial do repositório`.
8. **Não fazer *push*** — preparar PR-template em `docs/pull-request-template.md` para uso futuro.
9. Reportar a entrega no formato estabelecido (objetivo, *branch* utilizada, implementação, arquivos alterados, testes, problemas, documentação, pontos pendentes, próximo passo).

**Critérios de aceite específicos de B-01:**

- `git status` na *branch* `feature/bootstrap-repo` retorna *working tree clean* após o *commit*.
- `tree -L 2` (ou `find . -maxdepth 2 -not -path './.git*'`) mostra a estrutura acima.
- `README.md` cita explicitamente `Cap. 3 §3.3.5` e a Tabela 1.
- Nenhum arquivo dentro de `/workspace/prototipo/` ou `/workspace/*.tex` foi alterado.
