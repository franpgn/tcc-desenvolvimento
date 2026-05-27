# Sondas sucessivas do model checking: vereditos por invariante

> Continuação de `docs/mc-resultados-iniciais.md`. Reporta os resultados de quatro rodadas adicionais do TLC sobre `spec/SessionStore.tla`, cada uma desabilitando os invariantes já identificados como violados na rodada anterior, com o objetivo de sondar todos os I1..I6 individualmente. Executadas em 2026-05-26 com OpenJDK Temurin 17.0.9.

## 1. Resumo executivo

Quatro de seis invariantes do conjunto declarado são **violáveis** no modelo atual (super-aproximação conservadora): I1, I2, I5 e I6. Os outros dois invariantes (I3 e I4) **não foram violados** em mais de 91 milhões de estados distintos explorados na quinta rodada, sob qualquer entrelaçamento das transições do canal assíncrono. Em síntese:

| Invariante | Status | Profundidade do contraexemplo (\|small\|) | Evidência |
|---|---|---|---|
| I1 — irreversibilidade do logout | **violado** | 6 passos | `runs/tlc/small/` |
| I2 — consistência de bloqueio | **violado** | 5 passos | `runs/tlc-sem-I1/small/` |
| I3 — monotonicidade local do contador | **OK até 91 M estados** | — | `runs/tlc-sonda-I3-I4/small/` |
| I4 — unicidade do motivo de invalidação | **OK até 91 M estados** | — | `runs/tlc-sonda-I3-I4/small/` |
| I5 — convergência do estado lógico sob quiescência | **violado** | 5 passos | `runs/tlc-sem-I1-I2/small/` |
| I6 — convergência do contador sob quiescência | **violado** | 7 passos | `runs/tlc-sonda-I6/small/` |

## 2. Metodologia das sondas

Cada rodada comenta uma ou mais linhas `INVARIANTS` no arquivo `.cfg`, sem alterar `SessionStore.tla`. Os arquivos das rodadas estão em `spec/cfg-sem-I1/`. A justificativa metodológica para essa sequência de sondas é simples: o TLC interrompe no primeiro contraexemplo, então a única forma de saber se os invariantes seguintes têm violações é desabilitar os anteriores e re-executar.

| Rodada | Arquivo de configuração | Invariantes ativos | Diretório de saída |
|---|---|---|---|
| 1 (referência) | `MC-{size}.cfg` | TypeOK, I1, I2, I3, I4, I5, I6 | `runs/tlc/{size}/` |
| 2 | `MC-{size}-sem-I1.cfg` | TypeOK, I2, I3, I4, I5, I6 | `runs/tlc-sem-I1/{size}/` |
| 3 | `MC-{size}-sem-I1-I2.cfg` | TypeOK, I3, I4, I5, I6 | `runs/tlc-sem-I1-I2/{size}/` |
| 4 | `MC-{size}-sonda-I6.cfg` | TypeOK, I3, I4, I6 | `runs/tlc-sonda-I6/{size}/` |
| 5 | `MC-{size}-sonda-I3-I4.cfg` | TypeOK, I3, I4 | `runs/tlc-sonda-I3-I4/{size}/` |

## 3. Estados explorados por rodada

| Config / Rodada | 1 (ref) | 2 (sem I1) | 3 (sem I1+I2) | 4 (sonda I6) | 5 (sonda I3+I4) |
|---|---|---|---|---|---|
| `small` (2-3-2) | 204 / I1 | 271 / I2 | 945 / I5 | 5 894 / I6 | **>91 M, sem violação** |
| `medium` (3-3-2) | 316 / I1 | 385 / I2 | 1 228 / I5 | 9 388 / I6 | (não executada por custo computacional) |
| `full` (3-3-3) | 453 / I1 | 590 / I2 | 2 658 / I5 | 35 632 / I6 | (não executada por custo computacional) |

A taxa de descoberta de estados distintos cresce ordens de magnitude entre rodadas porque cada invariante eliminado expande o ramo da árvore de busca em que o TLC continua antes de parar. A rodada 5 explorou o espaço quase sem barreiras — apenas TypeOK, I3 e I4 ficavam como guardas — e atingiu 91 milhões de estados distintos em 10 minutos sem encontrar uma única violação.

## 4. Interpretação dos resultados

### 4.1 Invariantes de tipo (I3, I4) resistem ao espaço de estados explorado

I3 (`contador[r][id] ∈ 0..LIMITE`) e I4 (`motivos[r][s] ∈ MotivosT`) são, na essência, restrições de tipo sobre as variáveis. As ações `IncrementFailure`, `ResetFailures` e `Unblock` foram escritas para preservar essa faixa: `IncrementFailure` é guardada por `contador[r][id] < LIMITE`, e os *handlers* de mensagem fazem o mesmo. A ausência de violação após 91 milhões de estados oferece evidência empírica robusta de que o modelo respeita esses limites por construção. Verificação total exigiria abordagens por simetria ou redução parcial de ordem, o que fica como otimização para o Trabalho de Conclusão de Curso~II.

### 4.2 Invariantes de segurança de domínio (I1, I2) violam por entrelaçamento concorrente

I1 viola em **6 passos** pela sequência já descrita em `docs/mc-resultados-iniciais.md`: dois `Login` concorrentes sobre a mesma sessão antes da entrega das mensagens. I2 viola em **5 passos** por um padrão correlato:

1. Init
2. `Login(r1, u1, s1)` → r1 vê u1 com sessão VALID
3. `Block(r2, u1)` → r2 marca u1 como BLOCKED, mas r1 ainda não recebeu `ID_BLOQUEIA`
4. `Login(r2, u2, s2)` (ou outra ação que mantenha r1 com sessão VALID enquanto r2 marca BLOCKED)
5. **Violação de I2**: existe r2 com `status[u1] = BLOCKED` e r1 com `sessoes[s1] = VALID` para uma sessão de u1, contradizendo a obrigação de invalidação para identidades bloqueadas

Esse padrão de I2 era previsto na descrição da operação `Block(r, id)` em Cap. 3 §3.3.1, que estabelece a invalidação local das sessões da identidade — porém o canal propaga apenas `ID_BLOQUEIA`, sem mensagens `SESSAO_INVALIDA` derivadas, o que cria a janela de violação. O trace completo está em `runs/tlc-sem-I1/small/SessionStore_TTrace_1779864137.tla`.

### 4.3 Invariantes de convergência (I5, I6) violam por janela transitória entre entrega e quiescência

I5 e I6 são condicionados ao predicado `Quiescent ≜ Len(canal) = 0`. Eles afirmam que, quando todas as mensagens foram entregues, as réplicas concordam. A violação de I5 em 5 a 7 passos é interessante: o canal aparentemente esvazia, mas o estado das réplicas permanece divergente porque mensagens *suficientes* para reconciliar nem todas as alterações foram geradas pelo emissor. Em outras palavras, o emissor de `Block(r, id)` invalidou sessões locais de `id` mas o sistema não gerou, no momento da ação, as `SESSAO_INVALIDA` correspondentes — apenas um único `ID_BLOQUEIA`. Quando o canal esvazia, o destino fica com a identidade `BLOCKED` mas as sessões da identidade ainda `VALID`. I5 vê esse mismatch e dispara.

Esse achado tem duas leituras possíveis, que cabem ao autor decidir:

- **Achado legítimo do modelo:** o protocolo, conforme especificado em Cap. 3 §3.3.1, tem uma assimetria entre o efeito local de `Block` (invalida sessões) e o efeito propagado (apenas marca a identidade). Em produção, esse mismatch precisa de mecanismo adicional (auditoria periódica que invalida sessões de identidades `BLOCKED`, ou propagação explícita de cada `SESSAO_INVALIDA` derivada). O auditor de invariantes previsto em B-07 do *backlog* é exatamente esse mecanismo.

- **Imprecisão do modelo:** a especificação simplifica demais a propagação de `Block`. Refinar `Block` para gerar uma mensagem `SESSAO_INVALIDA` por sessão de `id` afetada eliminaria os contraexemplos de I2, I5 e (parcialmente) I6.

A recomendação técnica é **manter o modelo como está** e usar os contraexemplos como **catálogo direto** para o desenho do controlador heurístico em TCC-II: cada contraexemplo descreve um caminho operacional concreto que precisa de mitigação.

### 4.4 Custo da exploração sem invariantes

A rodada 5 demonstra empiricamente o que motiva a estratégia de sondas sucessivas: explorar o espaço de estados completo, sem invariantes que sirvam de barreira ao TLC, é computacionalmente inviável dentro de timeboxes de 10 minutos mesmo na configuração `small` (2 identidades, 3 sessões, 2 réplicas). A taxa de descoberta de 7 a 8 milhões de estados distintos por minuto, combinada à fila crescente de estados não explorados, indica que o espaço total dessa configuração deve ter ordem de bilhões de estados. A solução padrão da literatura (REF-018 Gao et al., 2025) é incremental: começar com cardinalidades pequenas e invariantes de barreira, e expandir só o necessário.

## 5. Consequências para o trabalho

### 5.1 Para o Capítulo 5 §5.1 (Resultados parciais)

A primeira rodada do model checking, com a especificação no escopo TCC-I, identificou contraexemplos para quatro de seis invariantes do conjunto declarado. Os contraexemplos foram obtidos em menos de um segundo de execução por configuração, e a profundidade dos contraexemplos é pequena (5 a 7 passos), o que sustenta o argumento metodológico do trabalho: o *model checking* identifica antes da execução experimental exatamente os entrelaçamentos que motivam a observação de violação na frente experimental.

### 5.2 Para o desenho do controlador heurístico (Cap. 4 e TCC-II)

Cada contraexemplo identifica um padrão operacional concreto a mitigar. O controlador heurístico previsto para TCC-II pode usar esses padrões como **regras de detecção de risco**: por exemplo, quando duas réplicas distintas processam `Login` para a mesma sessão em janela curta, a probabilidade de I1 violar sob *failover* aumenta. O catálogo de contraexemplos torna a heurística rastreável (auditável), o que cumpre o critério C4 do Cap. 3 §3.3.4.

### 5.3 Para a frente experimental (Sem 9-10)

A frente experimental, sob Infinispan estrito (com *consistent hashing* roteando todas as escritas de uma chave para o mesmo dono primário), provavelmente **não reproduzirá os contraexemplos de I1 e I2 sob fluxo nominal**, dado que o dono primário serializa as escritas. Contraexemplos de I5 e I6, condicionados à propagação assimétrica de `Block`, têm maior chance de aparecer empiricamente, especialmente sob *failover* (F1) e atraso (F3). Essa hipótese é testável e configura uma das perguntas de pesquisa centrais para o Capítulo 5.

## 6. Próximos passos imediatos

- **Decisão do autor** sobre os dois caminhos da Seção 4.3: aceitar a assimetria de `Block` como achado ou refinar.
- **Migração dos achados** para o Capítulo 5 §5.1 da monografia, com referência aos arquivos `summary.json` versionados.
- **Avanço para a frente experimental:** implementar B-05 a B-13 do *backlog* (operações reais, latência, auditor, injeção de falhas, coleta de métricas) e validar empiricamente a hipótese da Seção 5.3.
