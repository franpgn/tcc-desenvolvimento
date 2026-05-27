#!/usr/bin/env python3
"""
analysis/compare_scenarios.py
=============================

Realiza B-18 do backlog: comparação não-paramétrica entre dois
cenários experimentais por operação e por percentil de latência.

Aplica o teste de Mann-Whitney U bilateral sobre as latências por
operação dos dois cenários, conforme linha T22 da Tabela 1 do
Cap. 3 §3.3.5 (testes não paramétricos para distribuições assimétricas
de latência). Reporta também a diferença pontual de p50, p95 e p99
em milissegundos.

Significância: alfa = 0,05 conforme critério C1 do Cap. 3 §3.3.5.

Entrada:
    diretório-A  e  diretório-B,   ambos com CSVs no formato
    op_id,operation,start_ns,end_ns,replica,return_code,key

Saída: imprime tabela em stdout e grava um JSON no caminho indicado
por --saida (default: comparacao.json no diretório-B).

Estrutura do JSON:

    {
      "cenario_a": "<nome>",
      "cenario_b": "<nome>",
      "alfa": 0.05,
      "operacoes": {
          "<operacao>": {
              "n_a": <int>,
              "n_b": <int>,
              "p50_a_ns": <int>,  "p50_b_ns": <int>,  "delta_p50_ms": <float>,
              "p95_a_ns": <int>,  "p95_b_ns": <int>,  "delta_p95_ms": <float>,
              "p99_a_ns": <int>,  "p99_b_ns": <int>,  "delta_p99_ms": <float>,
              "mann_whitney_u": <float>,
              "p_value": <float>,
              "significativo_a_5pct": <bool>,
              "tamanho_efeito_aproximado": <float>   # r = Z / sqrt(N)
          },
          ...
      }
    }

Uso:
    python3 compare_scenarios.py runs/S1-sem-falha runs/S1-F1
"""
from __future__ import annotations

import argparse
import csv
import json
import math
import sys
from pathlib import Path
from collections import defaultdict

import numpy as np
from scipy import stats


def carregar(diretorio: Path) -> dict[str, np.ndarray]:
    csvs = sorted(diretorio.glob("*.csv"))
    if not csvs:
        raise FileNotFoundError(f"nenhum CSV em {diretorio}")

    por_op: dict[str, list[int]] = defaultdict(list)
    for csvfile in csvs:
        with csvfile.open() as fh:
            reader = csv.DictReader(fh)
            for row in reader:
                try:
                    lat = int(row["end_ns"]) - int(row["start_ns"])
                    if lat >= 0:
                        por_op[row["operation"]].append(lat)
                except (KeyError, ValueError):
                    continue

    return {op: np.array(v, dtype=np.int64) for op, v in por_op.items() if v}


def comparar(a: np.ndarray, b: np.ndarray, alfa: float) -> dict:
    """Compara duas amostras: percentis, Mann-Whitney U, tamanho de efeito."""
    n_a, n_b = len(a), len(b)
    if n_a == 0 or n_b == 0:
        return {"erro": "uma das amostras é vazia"}

    p50_a = int(np.percentile(a, 50, method="lower"))
    p95_a = int(np.percentile(a, 95, method="lower"))
    p99_a = int(np.percentile(a, 99, method="lower"))
    p50_b = int(np.percentile(b, 50, method="lower"))
    p95_b = int(np.percentile(b, 95, method="lower"))
    p99_b = int(np.percentile(b, 99, method="lower"))

    # Mann-Whitney U bilateral; method="auto" usa exata para n pequeno e
    # aproximação normal para n grande.
    u, p_valor = stats.mannwhitneyu(a, b, alternative="two-sided")

    # Tamanho de efeito r = Z / sqrt(N), conforme prática em estudos não
    # paramétricos. Aproximação válida para n grande.
    N = n_a + n_b
    media_u = n_a * n_b / 2.0
    desvio_u = math.sqrt(n_a * n_b * (N + 1) / 12.0)
    z = (u - media_u) / desvio_u if desvio_u > 0 else 0.0
    r = abs(z) / math.sqrt(N) if N > 0 else 0.0

    return {
        "n_a": int(n_a),
        "n_b": int(n_b),
        "p50_a_ns": p50_a,
        "p50_b_ns": p50_b,
        "delta_p50_ms": (p50_b - p50_a) / 1e6,
        "p95_a_ns": p95_a,
        "p95_b_ns": p95_b,
        "delta_p95_ms": (p95_b - p95_a) / 1e6,
        "p99_a_ns": p99_a,
        "p99_b_ns": p99_b,
        "delta_p99_ms": (p99_b - p99_a) / 1e6,
        "mann_whitney_u": float(u),
        "p_value": float(p_valor),
        "significativo_a_5pct": bool(p_valor < alfa),
        "tamanho_efeito_aproximado": float(r),
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Compara dois cenários por Mann-Whitney pareado por operação."
    )
    parser.add_argument("dir_a", type=Path, help="Diretório do cenário A (base)")
    parser.add_argument("dir_b", type=Path, help="Diretório do cenário B (comparação)")
    parser.add_argument("--alfa", type=float, default=0.05)
    parser.add_argument("--saida", type=Path, default=None,
                        help="Caminho do JSON de saída (default: dir_b/comparacao.json)")
    args = parser.parse_args()

    saida_path = args.saida or args.dir_b / "comparacao.json"

    a = carregar(args.dir_a)
    b = carregar(args.dir_b)
    operacoes_comuns = sorted(set(a) & set(b))

    resultado = {
        "cenario_a": args.dir_a.name,
        "cenario_b": args.dir_b.name,
        "alfa": args.alfa,
        "operacoes": {},
    }
    for op in operacoes_comuns:
        resultado["operacoes"][op] = comparar(a[op], b[op], args.alfa)

    saida_path.write_text(json.dumps(resultado, indent=2, ensure_ascii=False) + "\n")

    print(f"A = {args.dir_a.name}      B = {args.dir_b.name}")
    print(f"alfa = {args.alfa}")
    for op, st in resultado["operacoes"].items():
        if "erro" in st:
            print(f"  {op}: {st['erro']}")
            continue
        sig = "*" if st["significativo_a_5pct"] else " "
        print(
            f"  {op:<20}  Δp50={st['delta_p50_ms']:+8.3f}ms  "
            f"Δp95={st['delta_p95_ms']:+8.3f}ms  "
            f"Δp99={st['delta_p99_ms']:+8.3f}ms  "
            f"p={st['p_value']:.2e}{sig}  r={st['tamanho_efeito_aproximado']:.3f}"
        )

    print(f"\nResumo gravado em {saida_path}")
    print("* = significativo a alfa")
    return 0


if __name__ == "__main__":
    sys.exit(main())
