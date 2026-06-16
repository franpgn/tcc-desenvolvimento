#!/usr/bin/env bash
#
# run-baseline.sh
#
# Pipeline end-to-end para o baseline experimental: orquestra cenarios
# de carga (T7), modos de falha (T17, T18), repeticoes (T10), coleta
# de metricas (T19, T20) e analise estatistica posterior (T13, T22).
# Cobertura indireta da Tabela 1 do Cap. 3 secao 3.3.5 via os scripts
# delegados.
#
# Para cada combinacao (cenario, falha, repeticao), o pipeline:
#   1. Cria o diretorio de saida runs/<baseline>/<cenario>/<falha>/rep-NNN
#   2. Inicia collect-metrics.sh em background
#   3. Inicia o workload Java (via jar) em background
#   4. Aguarda o inicio da janela de medicao
#   5. Se aplicavel, dispara inject-crash.sh ou inject-jitter.sh
#   6. Aguarda fim do workload e do coletor
#   7. Move latencies CSV e metrics para o diretorio da repeticao
#   8. Opcional: invoca analysis/percentis.py + bootstrap_ic.py
#
# Dependencias: bash, java (para o workload), curl (collect-metrics),
# podman (inject-crash) e tc/NET_ADMIN (inject-jitter). Sem essas
# dependencias, --dry-run inspeciona o plano sem executar.
#
# Exit codes:
#   0  sucesso (todas as combinacoes executaram)
#   1  erro generico
#   2  argumento invalido ou --help
#   3  dependencia ausente (java, jar do workload)
#   4  falha em alguma combinacao
#
set -euo pipefail

NOME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

JAR_PADRAO="${REPO_DIR}/workload/target/session-workload-0.1.0-SNAPSHOT.jar"
SCENARIOS_PADRAO="S1,S2"
FALHAS_PADRAO="none,F1,F3"
REP_PADRAO=30
DURATION_PADRAO=600
OUTPUT_PADRAO="${REPO_DIR}/runs/baseline-$(date -u +%Y%m%dT%H%M%SZ)"
ANALYZE_PADRAO=1

usage() {
    cat <<EOF
Uso: ${NOME} [--scenarios <lista>] [--falhas <lista>] [--rep <n>]
            [--duration <segundos>] [--jar <caminho>]
            [--output <diretorio>] [--no-analysis]
            [--dry-run] [--help]

Orquestra o baseline experimental completo: cenarios x falhas x
repeticoes, com coleta de metricas e analise estatistica posterior.

Opcoes:
  --scenarios <lista>    Cenarios a executar. Padrao: ${SCENARIOS_PADRAO}
  --falhas <lista>       Modos de falha. Valores: none, F1, F3. Padrao: ${FALHAS_PADRAO}
  --rep <n>              Repeticoes por (cenario,falha). Padrao: ${REP_PADRAO}
  --duration <segundos>  Duracao do workload por repeticao. Padrao: ${DURATION_PADRAO}
  --jar <caminho>        Caminho do jar do workload. Padrao: ${JAR_PADRAO}
  --output <diretorio>   Diretorio raiz da bateria. Padrao: <repo>/runs/baseline-<TS>
  --no-analysis          Pula a fase de analise estatistica em Python
  --dry-run              Imprime o plano e sai sem executar
  --help                 Mostra esta mensagem

Estrutura de saida:
  <output>/
    <cenario>/
      <falha>/
        rep-NNN/
          latencies.csv         (LatencyRegistry)
          metrics-*.prom        (coletor)
          manifest.csv          (indice dos snapshots)
          workload.log          (stdout do jar)
        summary.json            (gerado por analysis/percentis.py)

Exemplos:
  ${NOME} --rep 5 --duration 120 --scenarios S1 --falhas none,F1
  ${NOME} --dry-run
EOF
}

SCENARIOS="${SCENARIOS_PADRAO}"
FALHAS="${FALHAS_PADRAO}"
REP="${REP_PADRAO}"
DURATION="${DURATION_PADRAO}"
JAR="${JAR_PADRAO}"
OUTPUT="${OUTPUT_PADRAO}"
ANALYZE="${ANALYZE_PADRAO}"
DRY_RUN=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --scenarios) [[ $# -ge 2 ]] || { echo "Erro: --scenarios exige valor" >&2; exit 2; }; SCENARIOS="$2"; shift 2 ;;
        --falhas)    [[ $# -ge 2 ]] || { echo "Erro: --falhas exige valor" >&2; exit 2; };    FALHAS="$2"; shift 2 ;;
        --rep)       [[ $# -ge 2 ]] || { echo "Erro: --rep exige valor" >&2; exit 2; };       REP="$2"; shift 2 ;;
        --duration)  [[ $# -ge 2 ]] || { echo "Erro: --duration exige valor" >&2; exit 2; };  DURATION="$2"; shift 2 ;;
        --jar)       [[ $# -ge 2 ]] || { echo "Erro: --jar exige valor" >&2; exit 2; };       JAR="$2"; shift 2 ;;
        --output)    [[ $# -ge 2 ]] || { echo "Erro: --output exige valor" >&2; exit 2; };    OUTPUT="$2"; shift 2 ;;
        --no-analysis) ANALYZE=0; shift ;;
        --dry-run)   DRY_RUN=1; shift ;;
        --help|-h)   usage; exit 0 ;;
        *)
            echo "Erro: argumento desconhecido '$1'" >&2; usage >&2; exit 2 ;;
    esac
done

validar_inteiro_positivo() {
    local flag="$1" val="$2"
    if ! [[ "${val}" =~ ^[0-9]+$ ]] || [[ "${val}" -lt 1 ]]; then
        echo "Erro: ${flag} deve ser inteiro positivo, recebido '${val}'" >&2
        exit 2
    fi
}
validar_inteiro_positivo "--rep" "${REP}"
validar_inteiro_positivo "--duration" "${DURATION}"

readarray -t LISTA_SCENARIOS < <(echo "${SCENARIOS}" | tr ',' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
readarray -t LISTA_FALHAS    < <(echo "${FALHAS}"    | tr ',' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

for FALHA in "${LISTA_FALHAS[@]}"; do
    case "${FALHA}" in
        none|F1|F3) ;;
        *) echo "Erro: falha '${FALHA}' invalida (use none, F1 ou F3)" >&2; exit 2 ;;
    esac
done
for SCEN in "${LISTA_SCENARIOS[@]}"; do
    case "${SCEN}" in
        S1|S2) ;;
        *) echo "Erro: cenario '${SCEN}' invalido (use S1 ou S2)" >&2; exit 2 ;;
    esac
done

TOTAL=$(( ${#LISTA_SCENARIOS[@]} * ${#LISTA_FALHAS[@]} * REP ))

log() {
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] ${NOME}: $*"
}

log "Plano: cenarios=${LISTA_SCENARIOS[*]} falhas=${LISTA_FALHAS[*]} rep=${REP} duration=${DURATION}s"
log "Total de execucoes: ${TOTAL}"
log "Jar: ${JAR}"
log "Output: ${OUTPUT}"

if [[ "${DRY_RUN}" -eq 1 ]]; then
    log "dry-run: nenhuma execucao real"
    log "Estrutura prevista:"
    for SCEN in "${LISTA_SCENARIOS[@]}"; do
        for FALHA in "${LISTA_FALHAS[@]}"; do
            for ((REPN = 1; REPN <= REP; REPN++)); do
                printf "  %s/%s/%s/rep-%03d/\n" "${OUTPUT}" "${SCEN}" "${FALHA}" "${REPN}"
            done
        done
    done | head -20
    if [[ ${TOTAL} -gt 20 ]]; then
        log "(... mais $((TOTAL - 20)) diretorios omitidos)"
    fi
    exit 0
fi

if ! command -v java >/dev/null 2>&1; then
    echo "Erro: 'java' nao encontrado no PATH" >&2
    exit 3
fi
if [[ ! -f "${JAR}" ]]; then
    echo "Erro: jar do workload nao encontrado em '${JAR}'. Rode 'mvn package' antes." >&2
    exit 3
fi

mkdir -p "${OUTPUT}"
log "criando ${OUTPUT}"

ITER=0
FALHAS_ITER=0

for SCEN in "${LISTA_SCENARIOS[@]}"; do
    for FALHA in "${LISTA_FALHAS[@]}"; do
        for ((REPN = 1; REPN <= REP; REPN++)); do
            ITER=$((ITER + 1))
            DEST="${OUTPUT}/${SCEN}/${FALHA}/rep-$(printf '%03d' "${REPN}")"
            mkdir -p "${DEST}"
            log "execucao ${ITER}/${TOTAL}: ${SCEN}/${FALHA}/rep-${REPN}"

            # 1) coletor de metricas em background
            "${SCRIPT_DIR}/collect-metrics.sh" \
                --interval 5 \
                --duration "${DURATION}" \
                --output "${DEST}" \
                >"${DEST}/metrics.log" 2>&1 &
            PID_METRICS=$!

            # 2) workload em background
            java -jar "${JAR}" \
                --scenario "${SCEN}" \
                --duration "${DURATION}" \
                --rep 1 \
                --csv-dir "${DEST}" \
                >"${DEST}/workload.log" 2>&1 &
            PID_WORKLOAD=$!

            # 3) injecao opcional de falha
            case "${FALHA}" in
                F1)
                    sleep $(( DURATION / 4 ))
                    "${SCRIPT_DIR}/inject-crash.sh" --duration 60 \
                        >"${DEST}/falha.log" 2>&1 || true
                    ;;
                F3)
                    sleep 5
                    "${SCRIPT_DIR}/inject-jitter.sh" --duration $(( DURATION - 10 )) \
                        >"${DEST}/falha.log" 2>&1 &
                    PID_FALHA=$!
                    ;;
                none)
                    : ;;
            esac

            # 4) aguardar workload e coletor
            if ! wait "${PID_WORKLOAD}"; then
                log "AVISO workload falhou em ${SCEN}/${FALHA}/rep-${REPN}"
                FALHAS_ITER=$((FALHAS_ITER + 1))
            fi
            if [[ "${FALHA}" == "F3" ]] && [[ -n "${PID_FALHA:-}" ]]; then
                wait "${PID_FALHA}" 2>/dev/null || true
            fi
            wait "${PID_METRICS}" 2>/dev/null || true
        done
    done
done

log "${TOTAL} execucoes concluidas; ${FALHAS_ITER} com aviso de workload"

# 5) analise estatistica opcional
if [[ "${ANALYZE}" -eq 1 ]]; then
    if [[ -x "${HOME}/tools/venv/bin/python" ]]; then
        PYTHON_BIN="${HOME}/tools/venv/bin/python"
    elif command -v python3 >/dev/null 2>&1; then
        PYTHON_BIN="$(command -v python3)"
    else
        log "AVISO: python nao encontrado; pulando analise estatistica"
        exit $(( FALHAS_ITER > 0 ? 4 : 0 ))
    fi

    for SCEN_DIR in "${OUTPUT}"/*/; do
        [[ -d "${SCEN_DIR}" ]] || continue
        for FALHA_DIR in "${SCEN_DIR}"*/; do
            [[ -d "${FALHA_DIR}" ]] || continue
            log "analise: ${FALHA_DIR}"
            "${PYTHON_BIN}" "${REPO_DIR}/analysis/percentis.py" "${FALHA_DIR}" \
                >"${FALHA_DIR}summary.json" 2>>"${OUTPUT}/analysis.log" || true
        done
    done
    log "analise concluida; saidas em <output>/<scen>/<falha>/summary.json"
fi

exit $(( FALHAS_ITER > 0 ? 4 : 0 ))
