# Especificação TLA+ e execução do TLC (B-14, B-15)

## O que foi feito

A especificação formal `spec/SessionStore.tla` modela o protocolo de estado de sessão como um sistema de transições com canal assíncrono. As variáveis cobertas são: `sessoes` (estado lógico por réplica), `motivos` (motivo de invalidação por sessão), `sessaoDe` (identidade dona da sessão), `contador` (tentativas falhas por identidade), `status` (`OPEN` ou `BLOCKED`) e `canal` (sequência de mensagens pendentes). As ações modelam as operações O1, O3, O4, O5, O6 e O7 da Seção 3.3.1 (a operação O2 é leitura pura e não tem ação dedicada) e mais a ação `EntregaMensagem(r)` que captura atraso e reordenação na entrega. Os seis invariantes I1 a I6 são declarados conforme Cap. 3 §3.3.3; I5 e I6 ficam condicionados ao predicado `Quiescent ≜ Len(canal) = 0`.

A execução do verificador TLC foi conduzida em três configurações de cardinalidade crescente: `MC-small` (2 identidades, 3 sessões, 2 réplicas), `MC-medium` (3, 3, 2) e `MC-full` (3, 3, 3). O *script* `spec/run-tlc.sh` invoca o TLC com cada configuração e grava saída em `runs/tlc/<size>/output.txt`. As cinco rodadas conduzidas até 2026-05-27 produziram contraexemplos curtos (5 a 7 passos) para I1, I2, I5 e I6, e a sonda na configuração `MC-full` explorou aproximadamente 91 milhões de estados sem violação para I3 e I4. A leitura adotada é a Caminho A: os contraexemplos de I1 e I2 são achados legítimos do protocolo otimista, e o refinamento para mitigá-los integra TCC-II.

## O que isso significa para a monografia

- **Cap. 4 §4.2** e **§4.3** após a rodada de reescrita de 2026-06-14 (E-05) já reportam o `SessionStore.tla` versionado, as três configurações, os contraexemplos para I1, I2, I5, I6, e o estado 91 M explorado em `MC-full` sem violação para I3 e I4. Este resumo confirma a aderência ao texto.
- **Cap. 5 §5.1** menciona "cinco rodadas do TLC, com contraexemplos produzidos para I1, I2, I5 e I6" após a reescrita de 2026-06-14 (E-08).

## Arquivos no repositório

- `spec/SessionStore.tla` — especificação completa (~260 linhas comentadas).
- `spec/MC-small.cfg`, `spec/MC-medium.cfg`, `spec/MC-full.cfg` — configurações T21.
- `spec/run-tlc.sh` — *runner* parametrizado por `small | medium | full`.
- `docs/spec-formal.md` — documentação técnica da especificação.
- `runs/tlc/<size>/output.txt` — saídas das cinco rodadas (em `.gitignore` exceto o `summary`).
