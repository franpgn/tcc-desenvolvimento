# Scripts de injeção de falha F1 e F3 (B-11, B-12)

## O que foi feito

Os scripts `scripts/inject-crash.sh` e `scripts/inject-jitter.sh` operacionalizam as falhas F1 (*crash* silencioso) e F3 (atraso e *jitter* no canal) prescritas em Cap. 3 §3.3.2 e parametrizadas pelas linhas T17 e T18 da Tabela 1. O `inject-crash.sh` executa o ciclo `podman stop`, `sleep`, `podman start` sobre um nó alvo, com duração padrão de 60\,s (superior ao timeout de detecção de 40\,s do FD_ALL3 do Infinispan, T16) e emite aviso quando o usuário escolhe duração menor. O `inject-jitter.sh` aplica regras `tc qdisc add ... netem delay X jitter Y distribution Z` sobre a interface de *bridge* do Podman, com *defaults* delay=15\,ms e jitter=12\,ms para aproximar o alvo p99=+50\,ms de T18; um `trap EXIT INT TERM` remove a disciplina ao final ou em interrupção.

Ambos os scripts seguem o mesmo padrão: `--help`, `--dry-run`, validação de argumentos com mensagem clara, *exit codes* padronizados (0 sucesso; 2 argumento inválido; 3 dependência ausente; 4 falha de privilégio; 5 recurso não encontrado) e log de cada passo com *timestamp* UTC. A execução real depende de Podman para F1 e da *capability* `NET_ADMIN` sobre a interface alvo para F3; nenhuma das duas está disponível no *sandbox* atual, motivo pelo qual o *baseline* F1+F3 foi reposicionado como entregável condicional de TCC-I (Cap. 4 §4.3 reescrita).

## O que isso significa para a monografia

- **Cap. 3 §3.3.2** já descreve F1 e F3; este resumo registra que os scripts estão prontos para execução e que a única pendência é o ambiente do autor.
- **Cap. 4 §4.3** já registra a dependência de Podman e `NET_ADMIN`; este resumo sustenta a frase mostrando que os artefatos do lado do código foram escritos e revisados.
- **Cap. 5 §5.2 e §5.3** podem mencionar que os scripts estão prontos e que o desbloqueio operacional final é exclusivamente de ambiente, não de implementação.

## Arquivos no repositório

- `scripts/inject-crash.sh` — F1, padrão 60\,s.
- `scripts/inject-jitter.sh` — F3, padrão delay=15\,ms jitter=12\,ms.
- Em ambos: `--help` documenta opções; `--dry-run` imprime o plano sem executar.

## Limitação registrada

A distribuição `lognormal` não é suportada nativamente pelo `netem`. O default `normal` aproxima a cauda longa com ajuste do jitter; para fidelidade ao alvo de T18, a distribuição customizada pode ser carregada via `tc qdisc change ... distribution <arquivo>` em uma rodada posterior.
