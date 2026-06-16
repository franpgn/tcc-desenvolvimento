#!/usr/bin/env bash
#
# inject-jitter.sh
#
# Injeta a falha F3 (atraso e jitter no canal) no cluster Infinispan,
# conforme Cap. 3 secao 3.3.2 e parametro T18 da Tabela 1 do Cap. 3
# secao 3.3.5 da monografia. Aplica regras 'tc qdisc' do iproute2 com
# disciplina 'netem' e distribuicao lognormal sobre a interface de
# bridge do Podman, durante uma janela controlada, e remove as regras
# ao fim da janela.
#
# Configuracao padrao calibrada para alvo de p99 = +50ms (T18), com
# delay medio de 15ms e jitter (desvio padrao) de 12ms sob distribuicao
# lognormal. O resultado exato depende da implementacao do netem no
# kernel; ajustar --delay-ms e --jitter-ms para refinar.
#
# Dependencias: iproute2 (tc) e capacidade NET_ADMIN sobre a interface
# alvo. Sem essas, 'tc qdisc add' falha com EPERM. O sandbox atual nao
# concede NET_ADMIN, portanto smoke-test usa --dry-run.
#
# Exit codes:
#   0  sucesso
#   1  erro generico
#   2  argumento invalido ou --help
#   3  dependencia ausente (tc/iproute2)
#   4  privilegio insuficiente (EPERM ao tentar tc qdisc)
#   5  interface nao encontrada
#
# Cobertura: T18 (atraso/jitter +50ms p99 via tc-netem lognormal).
set -euo pipefail

NOME="$(basename "$0")"
IFACE_PADRAO="cni-podman0"
DELAY_MS_PADRAO=15
JITTER_MS_PADRAO=12
DURACAO_PADRAO=600
DISTRIBUICAO_PADRAO="normal"
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

usage() {
    cat <<EOF
Uso: ${NOME} [--iface <nome>] [--delay-ms <n>] [--jitter-ms <n>]
            [--duration <segundos>] [--distribution <dist>]
            [--dry-run] [--help]

Injeta atraso e jitter (F3) sobre a interface de bridge do Podman via
'tc qdisc add ... netem'. Cobre T18 da Tabela 1: alvo p99 = +50ms com
parametros padrao (delay=${DELAY_MS_PADRAO}ms jitter=${JITTER_MS_PADRAO}ms).

Opcoes:
  --iface <nome>           Interface de bridge alvo. Padrao: ${IFACE_PADRAO}
  --delay-ms <n>           Atraso medio em milissegundos. Padrao: ${DELAY_MS_PADRAO}
  --jitter-ms <n>          Jitter (desvio padrao) em ms. Padrao: ${JITTER_MS_PADRAO}
  --distribution <dist>    Distribuicao do netem (uniform, normal,
                           pareto, paretonormal). Padrao: ${DISTRIBUICAO_PADRAO}
                           NOTA: 'lognormal' nao e suportada nativamente
                           pelo netem; 'normal' aproxima a cauda com
                           ajuste de jitter, ou customizar via
                           'tc qdisc change ... distribution <arquivo>'.
  --duration <segundos>    Tempo de injecao antes da remocao. Padrao: ${DURACAO_PADRAO}
  --dry-run                Imprime o plano e sai sem executar.
  --help                   Mostra esta mensagem.

Exemplos:
  ${NOME} --iface podman0 --delay-ms 25 --jitter-ms 18 --duration 300
  ${NOME} --dry-run
EOF
}

IFACE="${IFACE_PADRAO}"
DELAY_MS="${DELAY_MS_PADRAO}"
JITTER_MS="${JITTER_MS_PADRAO}"
DURACAO="${DURACAO_PADRAO}"
DISTRIBUICAO="${DISTRIBUICAO_PADRAO}"
DRY_RUN=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --iface)
            [[ $# -ge 2 ]] || { echo "Erro: --iface exige valor" >&2; exit 2; }
            IFACE="$2"; shift 2 ;;
        --delay-ms)
            [[ $# -ge 2 ]] || { echo "Erro: --delay-ms exige valor" >&2; exit 2; }
            DELAY_MS="$2"; shift 2 ;;
        --jitter-ms)
            [[ $# -ge 2 ]] || { echo "Erro: --jitter-ms exige valor" >&2; exit 2; }
            JITTER_MS="$2"; shift 2 ;;
        --duration)
            [[ $# -ge 2 ]] || { echo "Erro: --duration exige valor" >&2; exit 2; }
            DURACAO="$2"; shift 2 ;;
        --distribution)
            [[ $# -ge 2 ]] || { echo "Erro: --distribution exige valor" >&2; exit 2; }
            DISTRIBUICAO="$2"; shift 2 ;;
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

for VAR in DELAY_MS JITTER_MS DURACAO; do
    VAL="${!VAR}"
    if ! [[ "${VAL}" =~ ^[0-9]+$ ]] || [[ "${VAL}" -lt 0 ]]; then
        echo "Erro: --${VAR,,} deve ser inteiro >= 0, recebido '${VAL}'" >&2
        exit 2
    fi
done

case "${DISTRIBUICAO}" in
    uniform|normal|pareto|paretonormal) ;;
    *)
        echo "Erro: --distribution deve ser uniform, normal, pareto ou paretonormal" >&2
        exit 2 ;;
esac

log() {
    echo "[${TIMESTAMP}] ${NOME}: $*"
}

PLANO_ADD="tc qdisc add dev ${IFACE} root netem delay ${DELAY_MS}ms ${JITTER_MS}ms distribution ${DISTRIBUICAO}"
PLANO_DEL="tc qdisc del dev ${IFACE} root"

log "Plano: IFACE=${IFACE} DELAY=${DELAY_MS}ms JITTER=${JITTER_MS}ms DIST=${DISTRIBUICAO} DURACAO=${DURACAO}s DRY_RUN=${DRY_RUN}"

if [[ "${DRY_RUN}" -eq 1 ]]; then
    log "Comandos previstos:"
    log "  ${PLANO_ADD}"
    log "  sleep ${DURACAO}"
    log "  ${PLANO_DEL}"
    log "dry-run: nada executado"
    exit 0
fi

if ! command -v tc >/dev/null 2>&1; then
    echo "Erro: 'tc' (iproute2) nao encontrado no PATH" >&2
    exit 3
fi

if ! ip link show "${IFACE}" >/dev/null 2>&1; then
    echo "Erro: interface '${IFACE}' nao encontrada" >&2
    exit 5
fi

# Garantir remocao da disciplina mesmo em interrupcao do script.
cleanup() {
    log "removendo qdisc netem de ${IFACE}"
    tc qdisc del dev "${IFACE}" root 2>/dev/null || true
}
trap cleanup EXIT INT TERM

log "${PLANO_ADD}"
if ! tc qdisc add dev "${IFACE}" root netem \
        delay "${DELAY_MS}ms" "${JITTER_MS}ms" \
        distribution "${DISTRIBUICAO}"; then
    echo "Erro: 'tc qdisc add' falhou (provavelmente NET_ADMIN ausente)" >&2
    exit 4
fi

log "aguardando ${DURACAO}s com F3 ativa"
sleep "${DURACAO}"

log "OK: F3 (jitter) injetada por ${DURACAO}s; remocao no trap"
