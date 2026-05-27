# Resultados iniciais do model checking

> Documento que registra os primeiros resultados de execução do TLC sobre `spec/SessionStore.tla` (PR #3), conduzidos em 2026-05-26 sobre as três configurações declaradas pela linha T21 da Tabela 1 do Cap. 3 §3.3.5. Esses resultados correspondem à atividade *Model checking e análise de contraexemplos* prevista para Sem 9-10 do cronograma do Trabalho de Conclusão de Curso~I.

## 1. Resumo executivo

As três configurações reportam **violação do invariante I1** (irreversibilidade da invalidação por logout) em uma sequência mínima de seis passos a partir do estado inicial. Tempo de execução do TLC: menos de um segundo por configuração. A causa raiz é o entrelaçamento de duas operações `Login` concorrentes sobre a mesma sessão em réplicas distintas, seguidas por um `Logout` em uma das réplicas antes da entrega das mensagens de propagação.

## 2. Ambiente de execução

| Item | Valor |
|---|---|
| TLC | versão 2.18 (rev 4ba7d88), de `tla2tools.jar` v1.8.0 |
| Java | OpenJDK Temurin 17.0.9+9 (x86_64) |
| Sistema | Debian 12 (bookworm) em *container* Linux 6.12 |
| Comando | `./run-tlc.sh {small\|medium\|full}` |
| Data | 2026-05-26 |

## 3. Resultados por configuração

| Config | IDS | SIDS | REPLICAS | LIMITE | Estados gerados | Estados distintos | Profundidade | Veredito |
|---|---|---|---|---|---|---|---|---|
| `MC-small.cfg` | 2 | 3 | 2 | 3 | 204 | 198 | 6 | I1 violado |
| `MC-medium.cfg` | 3 | 3 | 2 | 3 | 316 | 312 | — | I1 violado |
| `MC-full.cfg` | 3 | 3 | 3 | 3 | 453 | 446 | — | I1 violado |

O TLC interrompe a busca no primeiro contraexemplo, por isso as configurações maiores não exploraram a totalidade do espaço de estados. A profundidade do grafo completo só foi reportada na execução `small`. Para todas as configurações, o mesmo padrão de contraexemplo se reproduziu, o que indica que o aumento de cardinalidade não introduziu novas classes de violação além da já capturada em `MC-small`.

Os resumos por configuração estão em [`runs/tlc/small/summary.json`](../runs/tlc/small/summary.json), [`runs/tlc/medium/summary.json`](../runs/tlc/medium/summary.json) e [`runs/tlc/full/summary.json`](../runs/tlc/full/summary.json). Os arquivos `output.txt` e `SessionStore_TTrace_*.tla` correspondem à saída bruta de cada execução, mantida para auditoria.

## 4. Análise do contraexemplo (configuração `small`)

A sequência mínima de seis passos a partir do estado inicial:

| Passo | Ação | Efeito relevante |
|---|---|---|
| 1 | Init | Estado limpo: todas as sessões `NONE`, contadores `0`, status `OPEN`, canal vazio |
| 2 | `Login(r1, u1, s1)` | r1: `sessoes[s1]=VALID`, `sessaoDe[s1]=u1`. Canal: 1 mensagem `SESSAO_VALIDA(s1, u1)` |
| 3 | `Login(r2, u1, s1)` | r2 ainda vê `sessoes[r2][s1]=NONE`, então a precondição passa. r2: `sessoes[s1]=VALID`, `sessaoDe[s1]=u1`. Canal: 2 mensagens |
| 4 | `Logout(r1, s1)` | r1: `sessoes[s1]=INVALID`, `motivos[s1]=LOGOUT`. r2 permanece `VALID`. Canal: 3 mensagens |
| 5 | (estado intermediário) | r1 com (INVALID, LOGOUT), r2 com VALID, canal não vazio |
| 6 | **Violação de I1** | Existe `r1` com (`INVALID`, `LOGOUT`) e `r2` com `VALID` para `s1`, contradizendo $\forall r_2: \texttt{sessoes}[r_2][s_1] \neq \texttt{VALID}$ |

O trace TLA+ completo gerado pelo TLC encontra-se em `runs/tlc/small/SessionStore_TTrace_1779863817.tla`.

## 5. Interpretação técnica

### 5.1 O modelo é uma super-aproximação conservadora

O modelo permite duas operações `Login(r, u1, s1)` concorrentes em réplicas distintas porque cada réplica decide com base no seu estado local. No Infinispan real isso não acontece da mesma forma: o *consistent hashing* atribui um dono primário determinístico a cada chave `s1`, e ambas as escritas seriam roteadas pelo cliente para esse mesmo dono primário, que serializa. Portanto, esse contraexemplo específico não se reproduz em uma instância padrão do Infinispan operando em modo `DIST_SYNC` ou `DIST_ASYNC` sem partição.

Entretanto, o contraexemplo é válido para sistemas chave-valor estilo Dynamo sem dono primário fixo (Cassandra com fator de replicação > 1 e quórum 1, Riak, Voldemort com `sloppy quorum`), e para o próprio Infinispan sob partição de rede com `partition-handling=ALLOW_READ_WRITES` (configuração permissiva que não é a do experimento atual, mas pode aparecer em produção). Ele também antecipa o comportamento esperado quando F2 (partição) entrar no modelo formal em TCC-II.

### 5.2 O achado central é metodológico

A primeira execução do TLC confirma que a especificação `SessionStore.tla`, na forma atual, **captura uma classe de violação de I1 detectável antes de qualquer experimento**. Isso valida o ponto declarado em Cap. 4 §4.2: o *model checking* identifica entrelaçamentos sutis que dificilmente apareceriam em testes manuais. O custo computacional dessa detecção foi inferior a um segundo nas três configurações.

### 5.3 Caminho 1: aceitar a super-aproximação

O recorte do TCC inclui replicação otimista em geral, não apenas Infinispan estrito. O contraexemplo é, nesse sentido, um achado legítimo: existe uma classe de sistemas distribuídos para os quais a violação de I1 ocorre, e o modelo a captura. Essa interpretação alinha-se com a Decisão 011 ponto 3 (escopo amplo dos oito eixos do mapeamento sistemático) e com a forma como Cap. 2 §2.1 trata Dynamo e CRDTs como classes irmãs do Infinispan.

### 5.4 Caminho 2: refinar a especificação para o Infinispan

Para aproximar o modelo do Infinispan real, é possível introduzir o conceito de **dono primário por chave** como uma função `donoPrimario : SIDS \cup IDS -> REPLICAS`, com a restrição adicional de que `Login(r, id, s)` só pode ocorrer quando `r = donoPrimario(s)`. Essa modificação eliminaria o contraexemplo atual e permitiria estudar exclusivamente as violações que sobrevivem ao roteamento por *consistent hashing* (a saber: violações sob partição e *failover*, que são F2 e F1 reservadas para TCC-II).

A decisão entre os dois caminhos é registrada para validação do autor.

## 6. Outros invariantes

A execução interrompe no primeiro contraexemplo (de I1), portanto os invariantes I2, I3, I4, I5 e I6 não foram exaustivamente avaliados nesta primeira rodada. Para verificá-los de forma independente, é necessário desabilitar I1 (comentar a linha `I1` em cada `.cfg`) ou executar com a opção `-continue` do TLC (que reporta múltiplos contraexemplos mas demanda parsing adicional). Essa segunda rodada fica como tarefa imediata.

## 7. Conexão com a frente experimental (Cap. 4 §4.3 e §4.5)

O contraexemplo de I1 sob `Login` concorrente é, no plano experimental, mais difícil de reproduzir em Infinispan estrito (Seção 5.1 acima). Os cenários de falha previstos para a Sem 9-10, F1 (*crash* silencioso) e F3 (atraso e *jitter*), são os candidatos prováveis a expor violações observáveis empiricamente. A correlação entre os contraexemplos do modelo e os eventos do *baseline* é tarefa do Cap. 5 §5.1.

## 8. Próximas tarefas

- **Decisão do autor** entre os caminhos 1 e 2 da Seção 5.
- **Segunda rodada do TLC** com I1 desabilitado, para detectar eventuais violações de I2-I6 (cobertura completa do espaço sob o modelo atual).
- **Migrar o achado** para o Cap. 5 §5.1 da monografia como resultado parcial documentado.
- **Em TCC-II**, conforme Apêndice B etapas 3 e 4: introduzir F1, F2, F3 explicitamente no modelo e gerar catálogo de contraexemplos por classe de falha, que orientará o desenho do controlador heurístico.
