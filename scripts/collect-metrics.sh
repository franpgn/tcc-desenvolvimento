#!/usr/bin/env bash
#
# collect-metrics.sh
#
# Coleta o endpoint OpenMetrics nativo de cada no Infinispan em
# intervalos regulares, durante uma janela controlada. Cobertura T19
# (M1-M7) e T20 (endpoint OpenMetrics) da Tabela 1 do Cap. 3 secao
# 3.3.5. Cada snapshot e escrito como arquivo separado em
# <output>/metrics-<no>-<timestamp>.prom, e um manifest CSV indexa as
# coletas.
#
# Dependencias: curl. O endpoint /metrics do Infinispan 15 e exposto
# nativamente sem autenticacao adicional alem da configurada para o
# servidor.
#
# Exit codes:
#   0  sucesso
#   1  erro generico
#   2  argumento invalido ou --help
#   3  dependencia ausente (curl)
#   4  falha persistente em algum endpoint apos N tentativas
#
# Cobertura: T19 (metricas coletadas) e T20 (endpoint OpenMetrics).
set -euo pipefail

NOME="$(basename "$0")"
SERVERS_PADRAO="127.0.0.1:11222,127.0.0.1:11223,127.0.0.1:11224"
INTERVALO_PADRAO=5
DURACAO_PADRAO=600
OUTPUT_PADRAO="./runs/metrics"
PATH_METRICS="/metrics"
MAX_TENTATIVAS=3

usage() {
    cat <<EOF
Uso: ${NOME} [--servers <lista>] [--interval <segundos>]
            [--duration <segundos>] [--output <diretorio>]
            [--dry-run] [--help]

Coleta o endpoint OpenMetrics de cada no Infinispan em intervalos
regulares, durante a janela indicada. Cobre T19/T20 da Tabela 1.

Opcoes:
  --servers <lista>      host:port,host:port,... Padrao: ${SERVERS_PADRAO}
  --interval <segundos>  Periodo entre coletas. Padrao: ${INTERVALO_PADRAO}
  --duration <segundos>  Tempo total de coleta. Padrao: ${DURACAO_PADRAO}
  --output <diretorio>   Diretorio destino. Padrao: ${OUTPUT_PADRAO}
  --dry-run              Mostra plano e sai sem executar.
  --help                 Mostra esta mensagem.

Saida:
  <output>/metrics-<no>-<YYYYMMDDTHHMMSSZ>.prom
  <output>/manifest.csv (timestamp,server,arquivo,status_http,bytes)

Exemplos:
  ${NOME} --interval 5 --duration 300 --output ./runs/cenario-S1-F1-rep01
  ${NOME} --dry-run
EOF
}

SERVERS="${SERVERS_PADRAO}"
INTERVALO="${INTERVALO_PADRAO}"
DURACAO="${DURACAO_PADRAO}"
OUTPUT="${OUTPUT_PADRAO}"
DRY_RUN=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --servers)
            [[ $# -ge 2 ]] || { echo "Erro: --servers exige valor" >&2; exit 2; }
            SERVERS="$2"; shift 2 ;;
        --interval)
            [[ $# -ge 2 ]] || { echo "Erro: --interval exige valor" >&2; exit 2; }
            INTERVALO="$2"; shift 2 ;;
        --duration)
            [[ $# -ge 2 ]] || { echo "Erro: --duration exige valor" >&2; exit 2; }
            DURACAO="$2"; shift 2 ;;
        --output)
            [[ $# -ge 2 ]] || { echo "Erro: --output exige valor" >&2; exit 2; }
            OUTPUT="$2"; shift 2 ;;
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

validar_inteiro_positivo() {
    local flag="$1" val="$2"
    if ! [[ "${val}" =~ ^[0-9]+$ ]] || [[ "${val}" -lt 1 ]]; then
        echo "Erro: ${flag} deve ser inteiro positivo, recebido '${val}'" >&2
        exit 2
    fi
}
validar_inteiro_positivo "--interval" "${INTERVALO}"
validar_inteiro_positivo "--duration" "${DURACAO}"

log() {
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] ${NOME}: $*"
}

readarray -t HOSTS < <(echo "${SERVERS}" | tr ',' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
if [[ ${#HOSTS[@]} -eq 0 ]]; then
    echo "Erro: nenhum host derivado de '${SERVERS}'" >&2
    exit 2
fi

NUM_COLETAS=$((DURACAO / INTERVALO))
if [[ ${NUM_COLETAS} -lt 1 ]]; then
    NUM_COLETAS=1
fi

log "Plano: ${#HOSTS[@]} hosts; ${NUM_COLETAS} coletas a cada ${INTERVALO}s; total=${DURACAO}s"
log "Hosts: ${HOSTS[*]}"
log "Output: ${OUTPUT}"

if [[ "${DRY_RUN}" -eq 1 ]]; then
    log "Comandos previstos por iteracao:"
    for H in "${HOSTS[@]}"; do
        log "  curl -s -o ${OUTPUT}/metrics-${H//:/-}-<ts>.prom -w '%{http_code}\\n' http://${H}${PATH_METRICS}"
    done
    log "dry-run: nada executado"
    exit 0
fi

if ! command -v curl >/dev/null 2>&1; then
    echo "Erro: 'curl' nao encontrado no PATH" >&2
    exit 3
fi

mkdir -p "${OUTPUT}"
MANIFEST="${OUTPUT}/manifest.csv"
if [[ ! -f "${MANIFEST}" ]]; then
    echo "timestamp,server,arquivo,status_http,bytes" > "${MANIFEST}"
fi

falhas_consecutivas_por_host=()
for _ in "${HOSTS[@]}"; do falhas_consecutivas_por_host+=(0); done

for ((i = 1; i <= NUM_COLETAS; i++)); do
    TS="$(date -u +%Y%m%dT%H%M%SZ)"
    log "coleta ${i}/${NUM_COLETAS} (ts=${TS})"
    for idx in "${!HOSTS[@]}"; do
        H="${HOSTS[$idx]}"
        DEST="${OUTPUT}/metrics-${H//:/-}-${TS}.prom"
        if STATUS_CODE="$(curl -s --max-time 10 -o "${DEST}" \
                -w '%{http_code}' "http://${H}${PATH_METRICS}")"; then
            BYTES=0
            [[ -f "${DEST}" ]] && BYTES="$(wc -c < "${DEST}" | tr -d ' ')"
            echo "${TS},${H},$(basename "${DEST}"),${STATUS_CODE},${BYTES}" >> "${MANIFEST}"
            if [[ "${STATUS_CODE}" =~ ^2 ]]; then
                falhas_consecutivas_por_host[$idx]=0
            else
                falhas_consecutivas_por_host[$idx]=$((falhas_consecutivas_por_host[idx] + 1))
                log "AVISO host=${H} status=${STATUS_CODE} bytes=${BYTES}"
            fi
        else
            falhas_consecutivas_por_host[$idx]=$((falhas_consecutivas_por_host[idx] + 1))
            echo "${TS},${H},NA,curl_err,0" >> "${MANIFEST}"
            log "ERRO host=${H} curl falhou"
        fi
        if [[ ${falhas_consecutivas_por_host[idx]} -ge ${MAX_TENTATIVAS} ]]; then
            log "host=${H} acumulou ${MAX_TENTATIVAS} falhas consecutivas; abortando"
            exit 4
        fi
    done
    if [[ ${i} -lt ${NUM_COLETAS} ]]; then
        sleep "${INTERVALO}"
    fi
done

log "OK: ${NUM_COLETAS} coletas concluidas; manifest em ${MANIFEST}"
