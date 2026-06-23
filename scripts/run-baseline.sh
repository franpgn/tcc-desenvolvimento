#!/usr/bin/env bash
#
# run-baseline.sh
#
# Executa a bateria baseline F1 do TCC: cenarios {S1, S2} x falhas
# {none, F1}, gravando os CSVs de eventos em runs/<cenario>-<falha>/ e
# acionando o pipeline analysis/ para produzir summary.json por cenario e
# comparacao.json (none x F1) por cenario de carga.
#
# Falha F1 (crash silencioso de no): durante a janela de medicao, um no e
# suspenso via scripts/inject-crash.sh (podman stop) por DURACAO_CRASH
# segundos e reativado. Nao requer netem/VM (isso e F3).
#
# Pre-requisitos verificados pelo Worker:
#   - cluster Infinispan size=3 HEALTHY (cluster/podman-compose.yml up -d);
#   - jar empacotado em workload/target/session-workload-*.jar;
#   - Python 3 + numpy/scipy para analysis/.
#
# Uso:
#   scripts/run-baseline.sh [--reps N] [--duration SEG] [--warmup-min SEG]
#                           [--threads N] [--crash-node NOME]
#                           [--crash-duration SEG] [--scenarios "S1 S2"]
#                           [--faults "none F1"] [--dry-run]
#
# Defaults sao curtos (validacao): 3 reps x 120s. Aumente para a bateria
# final. NAO faz git push.
set -euo pipefail

# ------------------------------------------------------------------ paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
RUNS_DIR="${REPO_DIR}/runs"
ANALYSIS_DIR="${REPO_DIR}/analysis"
INJECT="${SCRIPT_DIR}/inject-crash.sh"

# --------------------------------------------------------------- defaults
REPS=3
DURATION=120
WARMUP_MIN=20
THREADS=8
CRASH_NODE="isn2"
CRASH_DURATION=60
SERVERS="127.0.0.1:11222,127.0.0.1:11223,127.0.0.1:11224"
USERNAME="admin"
PASSWORD="infinispan"
SEED_BASE=42
SCENARIOS="S1 S2"
FAULTS="none F1"
DRY_RUN=0

JAR="$(ls "${REPO_DIR}"/workload/target/session-workload-*.jar 2>/dev/null \
        | grep -v original | head -1 || true)"

# ----------------------------------------------------------------- parse
while [[ $# -gt 0 ]]; do
    case "$1" in
        --reps)            REPS="$2"; shift 2 ;;
        --duration)        DURATION="$2"; shift 2 ;;
        --warmup-min)      WARMUP_MIN="$2"; shift 2 ;;
        --threads)         THREADS="$2"; shift 2 ;;
        --crash-node)      CRASH_NODE="$2"; shift 2 ;;
        --crash-duration)  CRASH_DURATION="$2"; shift 2 ;;
        --scenarios)       SCENARIOS="$2"; shift 2 ;;
        --faults)          FAULTS="$2"; shift 2 ;;
        --servers)         SERVERS="$2"; shift 2 ;;
        --seed)            SEED_BASE="$2"; shift 2 ;;
        --dry-run)         DRY_RUN=1; shift ;;
        --help|-h)
            sed -n '2,40p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *) echo "Erro: argumento desconhecido '$1'" >&2; exit 2 ;;
    esac
done

log() { echo "[$(date -u +%H:%M:%S)] run-baseline: $*"; }

if [[ -z "${JAR}" || ! -f "${JAR}" ]]; then
    echo "Erro: jar do workload nao encontrado em ${REPO_DIR}/workload/target/" >&2
    echo "      Rode: mvn -f workload/pom.xml package" >&2
    exit 3
fi
log "jar: ${JAR}"
log "reps=${REPS} duration=${DURATION}s warmup-min=${WARMUP_MIN}s threads=${THREADS}"
log "scenarios={${SCENARIOS}} faults={${FAULTS}} crash=${CRASH_NODE}/${CRASH_DURATION}s"

# ----------------------------------------------------- one workload run
# Executa uma repeticao gravando em <dir>/rep-NNN.csv. Para fault=F1, agenda
# inject-crash.sh para disparar apos o warm-up + uma folga, dentro da janela
# de medicao.
rodar_rep() {
    local cenario="$1" fault="$2" rep="$3" destino="$4"

    local crash_pid=""
    if [[ "${fault}" == "F1" ]]; then
        # Dispara o crash apos (warmup + 5s), ja na janela de medicao.
        local atraso=$(( WARMUP_MIN + 5 ))
        ( sleep "${atraso}"
          "${INJECT}" --node "${CRASH_NODE}" --duration "${CRASH_DURATION}" \
              >> "${destino}/inject-crash.log" 2>&1 ) &
        crash_pid=$!
        log "  rep ${rep}: crash F1 agendado em +${atraso}s (pid ${crash_pid})"
    fi

    java -jar "${JAR}" \
        --scenario "${cenario}" \
        --duration "${DURATION}" \
        --warmup-min-sec "${WARMUP_MIN}" \
        --ops 0 \
        --rep 1 \
        --threads "${THREADS}" \
        --servers "${SERVERS}" \
        --username "${USERNAME}" \
        --password "${PASSWORD}" \
        --seed "$(( SEED_BASE + rep ))" \
        --csv-dir "${destino}" \
        > "${destino}/rep-$(printf '%03d' "${rep}").stdout.log" 2>&1 || true

    # A CLI grava sempre rep-001.csv (rep=1 por invocacao); renomeia para a
    # repeticao da bateria para nao sobrescrever.
    if [[ -f "${destino}/rep-001.csv" && "${rep}" -ne 1 ]]; then
        mv "${destino}/rep-001.csv" \
           "${destino}/rep-$(printf '%03d' "${rep}").csv"
    fi

    if [[ -n "${crash_pid}" ]]; then
        wait "${crash_pid}" 2>/dev/null || true
        # Aguarda o no voltar a HEALTHY antes da proxima repeticao.
        aguardar_healthy
    fi
}

# ----------------------------------------------------- health gate
aguardar_healthy() {
    local i size
    for i in $(seq 1 30); do
        size=$(curl -s --digest -u "${USERNAME}:${PASSWORD}" \
            http://localhost:11222/rest/v2/cache-managers/default/health 2>/dev/null \
            | python -c 'import sys,json
try: print(json.load(sys.stdin)["cluster_health"]["number_of_nodes"])
except Exception: print(0)' 2>/dev/null || echo 0)
        if [[ "${size}" == "3" ]]; then
            log "  cluster reestabelecido (size=3)"
            return 0
        fi
        sleep 3
    done
    log "  AVISO: cluster nao voltou a size=3 apos a janela de espera"
    return 0
}

# ----------------------------------------------------- main loop
for cenario in ${SCENARIOS}; do
    for fault in ${FAULTS}; do
        destino="${RUNS_DIR}/${cenario}-${fault}"
        log "== ${cenario} / ${fault} -> ${destino} =="
        if [[ "${DRY_RUN}" -eq 1 ]]; then
            log "  dry-run: ${REPS} reps de ${DURATION}s seriam executadas"
            continue
        fi
        mkdir -p "${destino}"
        for rep in $(seq 1 "${REPS}"); do
            log "  rep ${rep}/${REPS}"
            rodar_rep "${cenario}" "${fault}" "${rep}" "${destino}"
        done
        # summary.json por cenario (glob nao-recursivo: aponta para a pasta).
        ( cd "${ANALYSIS_DIR}" && python percentis.py "${destino}" ) || \
            log "  AVISO: percentis.py falhou para ${destino}"
    done
done

# ----------------------------------------------------- comparacao none x F1
if [[ "${DRY_RUN}" -eq 0 ]] && echo "${FAULTS}" | grep -qw none \
        && echo "${FAULTS}" | grep -qw F1; then
    for cenario in ${SCENARIOS}; do
        dir_none="${RUNS_DIR}/${cenario}-none"
        dir_f1="${RUNS_DIR}/${cenario}-F1"
        if [[ -d "${dir_none}" && -d "${dir_f1}" ]]; then
            log "== comparacao ${cenario}: none x F1 =="
            ( cd "${ANALYSIS_DIR}" && \
              python compare_scenarios.py "${dir_none}" "${dir_f1}" \
                  --saida "${dir_f1}/comparacao.json" ) || \
                log "  AVISO: compare_scenarios.py falhou para ${cenario}"
        fi
    done
fi

log "bateria concluida."
