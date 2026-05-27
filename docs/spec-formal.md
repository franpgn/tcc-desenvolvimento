# Especificação formal: SessionStore.tla

> Documento técnico que descreve a especificação em TLA+ do núcleo do protocolo de estado de sessão, conforme Capítulo 4 §4.2 da monografia e linhas T21 da Tabela 1 do Cap. 3 §3.3.5.

## Visão geral

`spec/SessionStore.tla` modela o protocolo como um sistema de transições com canal assíncrono e seis estados por réplica. As operações cobertas por esta versão são O1, O3, O4, O5, O6 e O7 (a operação O2 é leitura pura e não altera estado, portanto não tem ação dedicada no modelo). Os invariantes I1 a I6, declarados no Cap. 3 §3.3.3, são todos verificáveis pelo TLC.

## Variáveis de estado

| Variável | Tipo | Significado |
|---|---|---|
| `sessoes` | `[REPLICAS -> [SIDS -> Estados]]` | Estado lógico de cada sessão por réplica (`NONE`, `VALID`, `INVALID`) |
| `motivos` | `[REPLICAS -> [SIDS -> MotivosT]]` | Motivo registrado em caso de `INVALID` (`LOGOUT`, `EXPIRADA`, `ADMIN_BLOCK`, `NONE`) |
| `sessaoDe` | `[REPLICAS -> [SIDS -> {NONE} ∪ IDS]]` | Identidade dona da sessão |
| `contador` | `[REPLICAS -> [IDS -> 0..LIMITE]]` | Tentativas falhas por identidade |
| `status` | `[REPLICAS -> [IDS -> StatusT]]` | Estado de bloqueio da identidade (`OPEN`, `BLOCKED`) |
| `canal` | `Seq(Mensagem)` | Fila de mensagens pendentes entre réplicas |

## Operações (ações do modelo)

| Ação | Origem (Cap. 3 §3.3.1) | Mensagem propagada |
|---|---|---|
| `Login(r, id, s)` | O1 | `SESSAO_VALIDA(s, id)` |
| `Logout(r, s)` | O3 | `SESSAO_INVALIDA(s, LOGOUT)` |
| `IncrementFailure(r, id)` | O4 | `CONTADOR_INC(id)` |
| `ResetFailures(r, id)` | O5 | `CONTADOR_RESET(id)` |
| `Block(r, id)` | O6 | `ID_BLOQUEIA(id)` |
| `Unblock(r, id)` | O7 | `ID_DESBLOQUEIA(id)` |
| `EntregaMensagem(r)` | abstração do canal | aplica uma mensagem qualquer da fila à réplica `r` |

`EntregaMensagem` escolhe não-deterministicamente qualquer mensagem da fila para entregar a qualquer réplica, o que captura atraso ilimitado e reordenação. Essa abstração é o ponto de divergência entre réplicas e a fonte de potenciais violações de I5 e I6 fora da quiescência.

## Invariantes verificados

| Invariante | Tipo | Predicado (informal) |
|---|---|---|
| `TypeOK` | tipo | as variáveis pertencem aos domínios declarados |
| `I1` | segurança | logout confirmado em uma réplica veta `VALID` em qualquer réplica |
| `I2` | segurança | identidade `BLOCKED` em alguma réplica veta sessões `VALID` em qualquer réplica |
| `I3` | segurança | contador permanece em `0..LIMITE` |
| `I4` | segurança | motivo de invalidação pertence ao tipo declarado |
| `I5` | convergência sob quiescência | com canal vazio, todas as réplicas concordam sobre `sessoes`, `motivos` e `sessaoDe` |
| `I6` | convergência sob quiescência | com canal vazio, todas as réplicas concordam sobre `contador` e `status` |

I5 e I6 usam o predicado `Quiescent ≜ Len(canal) = 0`. Em estados com canal não vazio, esses invariantes são vacuosamente verdadeiros (implicação com antecedente falso); a obrigação real só vale após todas as mensagens serem entregues.

## Configurações de TLC (Tabela 1 T21)

| Arquivo | Cardinalidade | Tempo esperado |
|---|---|---|
| `MC-small.cfg` | 2 identidades, 3 sessões, 2 réplicas | segundos a poucos minutos |
| `MC-medium.cfg` | 3 identidades, 3 sessões, 2 réplicas | minutos a dezenas de minutos |
| `MC-full.cfg` | 3 identidades, 3 sessões, 3 réplicas | pode estourar 30 min (R-04 do planejamento) |

`LIMITE` (limiar de tentativas para bloqueio automático) fica em 3 nas três configurações, em consonância com práticas comuns para autenticação multifator.

## Como executar

Pré-requisitos: `tla2tools.jar` em `spec/` (ou caminho exportado em `$TLA_TOOLS`) e Java 11 ou superior.

```bash
cd spec
./run-tlc.sh small         # primeira passada
./run-tlc.sh medium        # se small fechar OK
./run-tlc.sh full          # se medium fechar OK e houver folga de tempo
```

As saídas são gravadas em `runs/tlc/<size>/output.txt`, junto com o conjunto de estados visitados (`runs/tlc/<size>/states/`). Em caso de violação, o TLC retorna a sequência de transições que produz o contraexemplo.

## Resultados esperados em TCC-I

Para o fluxo nominal coberto por esta versão (sem falhas explícitas, conforme decisão registrada no Cap. 3 §3.3.2):

- **I1 a I4** devem fechar como `OK` nas três configurações. Um contraexemplo aqui indica que a abstração captura uma classe de comportamento incompatível com os invariantes mesmo sem falha, o que demanda refinamento da especificação.
- **I5 e I6** podem produzir contraexemplos em estados intermediários (canal não vazio), mas devem ser satisfeitas em todo estado quiescente. Como ambos os invariantes estão condicionados a `Quiescent`, eles só falham se houver divergência persistente entre réplicas após o canal esvaziar.

Caso a configuração `MC-full.cfg` estoure o orçamento de tempo, aceita-se `MC-medium.cfg` como teto e registra-se como limitação no Cap. 5 §5.1 (Risco R-04 do `docs/planejamento-inicial.md`).

## Evolução prevista para TCC-II

Conforme o Apêndice B da monografia, etapas 3 e 4, o modelo será estendido com transições explícitas para:

- *Crash* silencioso de nó (F1)
- Partição de rede entre subconjuntos (F2)
- Atraso e *jitter* no canal (F3)

A inclusão dessas falhas tende a produzir contraexemplos para I1, I2 e I4, e esses contraexemplos formam o catálogo de combinações operação × falha × invariante que orientará o desenho do controlador heurístico.
