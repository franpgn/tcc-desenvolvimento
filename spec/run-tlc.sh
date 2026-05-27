#!/usr/bin/env bash
# Executa o TLC sobre SessionStore.tla em uma das três configurações
# previstas pela linha T21 da Tabela 1 do Cap. 3 §3.3.5.
#
# Uso:
#   ./run-tlc.sh small        # 2 ids, 3 sids, 2 réplicas
#   ./run-tlc.sh medium       # 3 ids, 3 sids, 2 réplicas
#   ./run-tlc.sh full         # 3 ids, 3 sids, 3 réplicas
#
# Requisitos:
#   - tla2tools.jar disponível em $TLA_TOOLS ou ./tla2tools.jar
#   - Java 11 ou superior
#
# Saída:
#   - stdout: log do TLC, com estados explorados e veredito por invariante
#   - código de retorno 0 se OK, não-zero se houve contraexemplo

set -euo pipefail

SIZE="${1:-}"

case "$SIZE" in
  small|medium|full)
    CFG="MC-${SIZE}.cfg"
    ;;
  *)
    echo "Uso: $0 {small|medium|full}" >&2
    exit 2
    ;;
esac

if [[ ! -f "$CFG" ]]; then
  echo "Arquivo de configuração não encontrado: $CFG" >&2
  exit 3
fi

TLA_TOOLS="${TLA_TOOLS:-./tla2tools.jar}"
if [[ ! -f "$TLA_TOOLS" ]]; then
  echo "tla2tools.jar não encontrado em $TLA_TOOLS" >&2
  echo "Defina a variável TLA_TOOLS ou coloque o jar neste diretório." >&2
  exit 4
fi

OUTDIR="../runs/tlc/${SIZE}"
mkdir -p "$OUTDIR"

echo "Executando TLC com configuração: $CFG"
echo "Saída em:                       $OUTDIR/output.txt"
echo

java -XX:+UseParallelGC -cp "$TLA_TOOLS" tlc2.TLC \
     -config "$CFG" \
     -workers auto \
     -metadir "$OUTDIR/states" \
     SessionStore.tla 2>&1 | tee "$OUTDIR/output.txt"
