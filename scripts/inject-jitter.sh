#!/usr/bin/env bash
#
# inject-jitter.sh
#
# Injeta a falha F3 (jitter/atraso na rede de um no) no cluster
# Infinispan, conforme Cap. 3 secao 3.3.2 (modelo de falhas, F3) e
# parametro T18 da Tabela 1 do Cap. 3 secao 3.3.5 da monografia. Aplica
# uma disciplina de fila 'netem' do tc (iproute2) sobre a interface
# egress do no alvo, DENTRO do container ('podman exec <node> tc ...'),
# pois o workload roda na VM e alcanca os nos pelas portas Hot Rod
# mapeadas. Ao fim da janela (ou em qualquer sinal/erro), a disciplina
# e SEMPRE removida.
#
# Calibracao padrao (execucao oficial TCC-I, aprovada pelo Gestor):
# 'delay 20ms 13ms distribution normal'. Para uma normal, o p99 do
# atraso adicionado e ~ MEAN + 2,326*JITTER = 20 + 2,326*13 ~= 50ms,
# atingindo o alvo de cauda +50ms do T18. A distribuicao lognormal
# estrita fica como rodada de sensibilidade (--distribution lognormal,
# que exige tabela /usr/lib/tc/lognormal.dist instalada no container).
#
# Dependencias: podman (CLI) e, DENTRO do container, 'tc' (iproute2) com
# o modulo de kernel 'sch_netem'. O kernel do WSL2 NAO traz sch_netem;
# por isso a execucao real exige a VM (Hyper-V/Ubuntu com
# linux-modules-extra). O '--dry-run' NAO requer nenhuma dependencia e
# roda em qualquer maquina (inclusive Windows/WSL antes do reboot).
#
# Exit codes:
#   0  sucesso (netem aplicado, aguardado, removido)
#   1  erro generico
#   2  argumento invalido ou --help
#   3  dependencia ausente (podman, ou tc/sch_netem indisponivel no container)
#   4  no nao encontrado ou em estado inesperado
#   5  netem rejeitado pelo kernel (qdisc kind unknown / sch_netem ausente)
#
# Cobertura: T18 (jitter/atraso, alvo p99 = +50ms via tc-netem).
set -euo pipefail

NOME="$(basename "$0")"
NODE_PADRAO="isn2"
IFACE_PADRAO="eth0"
DELAY_PADRAO="20ms"
JITTER_PADRAO="13ms"
DISTRIBUICAO_PADRAO="normal"
# Janela padrao alinhada a T14 (30 min com falha). A bateria
# (run-baseline.sh) sobrescreve para cobrir a janela de medicao da celula.
DURACAO_PADRAO=1800
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

usage() {
    cat <<EOF
Uso: ${NOME} [--node <nome>] [--iface <if>] [--delay <Nms>] [--jitter <Nms>]
            [--distribution <dist>] [--duration <segundos>]
            [--dry-run] [--help]

Injeta atraso/jitter (F3) no no alvo via 'podman exec <node> tc qdisc add
dev <iface> root netem ...'. Cobre T18 da Tabela 1: alvo p99 = +50ms com
os parametros padrao (delay=${DELAY_PADRAO} jitter=${JITTER_PADRAO} distribution=${DISTRIBUICAO_PADRAO}).
A disciplina netem e SEMPRE removida ao fim da janela ou em interrupcao
(trap de cleanup), para nao deixar o no degradado.

Opcoes:
  --node <nome>          Container alvo. Padrao: ${NODE_PADRAO}
  --iface <if>           Interface egress dentro do container. Padrao: ${IFACE_PADRAO}
  --delay <Nms>          Atraso medio (sufixo ms/us/s). Padrao: ${DELAY_PADRAO}
  --jitter <Nms>         Jitter/desvio (sufixo ms/us/s). Padrao: ${JITTER_PADRAO}
  --distribution <dist>  Distribuicao do netem: normal (padrao, TCC-I),
                         lognormal (sensibilidade; exige tabela custom no
                         container), pareto, paretonormal. Padrao: ${DISTRIBUICAO_PADRAO}
  --duration <segundos>  Janela de injecao em segundos. Padrao: ${DURACAO_PADRAO} (T14)
  --dry-run              Imprime o plano de comandos e sai 0, sem deps.
  --help                 Mostra esta mensagem.

Exemplos:
  ${NOME} --node isn2 --duration 90
  ${NOME} --node isn2 --distribution lognormal --delay 25ms --jitter 18ms
  ${NOME} --dry-run
EOF
}

NODE="${NODE_PADRAO}"
IFACE="${IFACE_PADRAO}"
DELAY="${DELAY_PADRAO}"
JITTER="${JITTER_PADRAO}"
DISTRIBUICAO="${DISTRIBUICAO_PADRAO}"
DURACAO="${DURACAO_PADRAO}"
DRY_RUN=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --node)
            [[ $# -ge 2 ]] || { echo "Erro: --node exige valor" >&2; exit 2; }
            NODE="$2"; shift 2 ;;
        --iface)
            [[ $# -ge 2 ]] || { echo "Erro: --iface exige valor" >&2; exit 2; }
            IFACE="$2"; shift 2 ;;
        --delay)
            [[ $# -ge 2 ]] || { echo "Erro: --delay exige valor" >&2; exit 2; }
            DELAY="$2"; shift 2 ;;
        --jitter)
            [[ $# -ge 2 ]] || { echo "Erro: --jitter exige valor" >&2; exit 2; }
            JITTER="$2"; shift 2 ;;
        --distribution)
            [[ $# -ge 2 ]] || { echo "Erro: --distribution exige valor" >&2; exit 2; }
            DISTRIBUICAO="$2"; shift 2 ;;
        --duration)
            [[ $# -ge 2 ]] || { echo "Erro: --duration exige valor" >&2; exit 2; }
            DURACAO="$2"; shift 2 ;;
        --dry-run)
            DRY_RUN=1; shift ;;
        --help|-h)
            usage; exit 0 ;;
        *)
            echo "Erro: argumento desconhecido '$1'" >&2
            usage >&2
            exit 2 ;;
    esac
done

# --delay/--jitter: numero (inteiro ou decimal) com sufixo de tempo do tc.
TEMPO_RE='^[0-9]+(\.[0-9]+)?(us|ms|s)$'
if ! [[ "${DELAY}" =~ ${TEMPO_RE} ]]; then
    echo "Erro: --delay deve ser <numero>{us|ms|s}, recebido '${DELAY}'" >&2
    exit 2
fi
if ! [[ "${JITTER}" =~ ${TEMPO_RE} ]]; then
    echo "Erro: --jitter deve ser <numero>{us|ms|s}, recebido '${JITTER}'" >&2
    exit 2
fi

case "${DISTRIBUICAO}" in
    normal|lognormal|pareto|paretonormal) ;;
    *)
        echo "Erro: --distribution deve ser normal, lognormal, pareto ou paretonormal" >&2
        exit 2 ;;
esac

if ! [[ "${DURACAO}" =~ ^[0-9]+$ ]] || [[ "${DURACAO}" -lt 1 ]]; then
    echo "Erro: --duration deve ser inteiro positivo, recebido '${DURACAO}'" >&2
    exit 2
fi

log() {
    echo "[${TIMESTAMP}] ${NOME}: $*"
}

PLANO_ADD="podman exec ${NODE} tc qdisc add dev ${IFACE} root netem delay ${DELAY} ${JITTER} distribution ${DISTRIBUICAO}"
PLANO_SHOW="podman exec ${NODE} tc qdisc show dev ${IFACE}"
PLANO_DEL="podman exec ${NODE} tc qdisc del dev ${IFACE} root"

log "Plano: NODE=${NODE} IFACE=${IFACE} DELAY=${DELAY} JITTER=${JITTER} DIST=${DISTRIBUICAO} DURACAO=${DURACAO}s DRY_RUN=${DRY_RUN}"

if [[ "${DRY_RUN}" -eq 1 ]]; then
    log "Comandos previstos:"
    log "  ${PLANO_ADD}"
    log "  sleep ${DURACAO}"
    log "  ${PLANO_DEL}"
    log "dry-run: nada executado (sem podman/tc/sch_netem)"
    exit 0
fi

# ---------------------------------------------------------- dependencias
if ! command -v podman >/dev/null 2>&1; then
    echo "Erro: 'podman' nao encontrado no PATH" >&2
    exit 3
fi

if ! podman inspect "${NODE}" >/dev/null 2>&1; then
    echo "Erro: container '${NODE}' nao encontrado" >&2
    exit 4
fi

ESTADO="$(podman inspect -f '{{.State.Status}}' "${NODE}")"
if [[ "${ESTADO}" != "running" ]]; then
    echo "Erro: container '${NODE}' nao esta running (estado='${ESTADO}')" >&2
    exit 4
fi

# Sonda netem: aplica e remove uma regra trivial DENTRO do container. Se o
# 'sch_netem' nao existir (sintoma do WSL2: "Specified qdisc kind is
# unknown") ou 'tc' faltar, falha aqui com diagnostico, em vez de stack
# trace mais adiante. Falha de sonda => exit 3 (dependencia ausente).
log "sondando netem em ${NODE} (${IFACE})"
SONDA_OUT="$(podman exec "${NODE}" sh -c \
    "tc qdisc add dev ${IFACE} root netem delay 1ms && tc qdisc del dev ${IFACE} root" 2>&1)" \
    || {
        echo "Erro: sonda netem falhou em '${NODE}' (${IFACE})." >&2
        echo "      Saida: ${SONDA_OUT}" >&2
        echo "      Provavel sch_netem/tc ausente no kernel (sintoma do WSL2)." >&2
        echo "      Veja docs/plano-f3-vm-netem.md (gate da VM, secao 3.5)." >&2
        exit 3
    }

# ----------------------------------------------------------- cleanup/trap
# Registrar o cleanup ANTES de aplicar a disciplina: requisito de robustez
# nº1 do F3. Mesmo em Ctrl-C/erro o netem e removido. Idempotente: nao
# falha se a disciplina ja nao existir (2>/dev/null || true).
cleanup() {
    podman exec "${NODE}" tc qdisc del dev "${IFACE}" root >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

# -------------------------------------------------------------- aplicar
log "${PLANO_ADD}"
if ! ADD_OUT="$(podman exec "${NODE}" tc qdisc add dev "${IFACE}" root netem \
        delay "${DELAY}" "${JITTER}" distribution "${DISTRIBUICAO}" 2>&1)"; then
    echo "Erro: netem rejeitado ao aplicar a disciplina em '${NODE}' (${IFACE})." >&2
    echo "      Saida: ${ADD_OUT}" >&2
    if echo "${ADD_OUT}" | grep -qi "unknown"; then
        echo "      'qdisc kind unknown' => sch_netem ausente no kernel." >&2
    fi
    echo "      (o trap de cleanup removera qualquer disciplina parcial)" >&2
    exit 5
fi

log "disciplina efetiva:"
podman exec "${NODE}" tc qdisc show dev "${IFACE}" | sed "s/^/    /" || true

log "aguardando ${DURACAO}s com F3 ativa"
sleep "${DURACAO}"

# -------------------------------------------------------------- remover
log "${PLANO_DEL}"
podman exec "${NODE}" tc qdisc del dev "${IFACE}" root >/dev/null 2>&1 || true

# Verificacao: nenhuma disciplina netem residual na interface.
if podman exec "${NODE}" tc qdisc show dev "${IFACE}" 2>/dev/null | grep -q netem; then
    echo "Aviso: ainda ha netem residual em ${NODE} (${IFACE}); o trap tentara remover." >&2
else
    log "OK: F3 (jitter) injetada por ${DURACAO}s e removida; sem netem residual"
fi
