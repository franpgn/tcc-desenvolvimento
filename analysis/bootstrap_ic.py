#!/usr/bin/env python3
"""
analysis/bootstrap_ic.py
========================

Realiza B-17 do backlog: calcula intervalos de confiança bootstrap
para p50, p95 e p99 das distribuições de latência por operação.

Linha T22 da Tabela 1 do Cap. 3 §3.3.5: bootstrap com 10 000
reamostragens para IC de 95% por percentil. As distribuições de
latência são assimétricas, o que invalida a hipótese de normalidade
necessária para IC analíticos; o bootstrap não-paramétrico contorna
essa restrição.

Entrada: o mesmo diretório com CSVs já consumido por percentis.py.
Saída: grava runs/<cenário>/bootstrap.json com a estrutura:

    {
      "cenario": "<nome>",
      "n_reamostragens": 10000,
      "operacoes": {
          "<operacao>": {
              "n": <int>,
              "p50_ns": {"estimativa": ..., "ic95_inferior": ..., "ic95_superior": ...},
              "p95_ns": {...},
              "p99_ns": {...}
          },
          ...
      }
    }

Uso:
    python3 bootstrap_ic.py runs/<cenário>
    python3 bootstrap_ic.py runs/S1-sem-falha --reamostragens 10000
"""
from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path
from collections import defaultdict

import numpy as np


def carregar_latencias(diretorio: Path) -> dict[str, np.ndarray]:
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


def ic_bootstrap(amostras: np.ndarray, percentil: float, n_reamostragens: int,
                 rng: np.random.Generator) -> dict:
    """Calcula estimativa de percentil + IC 95% por bootstrap.

    Reamostra com reposição n_reamostragens vezes; para cada reamostra
    calcula o percentil; retorna média + percentis 2,5 e 97,5 da
    distribuição reamostrada.
    """
    n = len(amostras)
    if n == 0:
        return {"estimativa": None, "ic95_inferior": None, "ic95_superior": None}

    # Reamostragem vetorizada: matriz (n_reamostragens, n) de índices.
    # Para n grande (10^6) e 10 000 reamostragens, isto seria 10^10 itens —
    # consume memória demais. Usamos amostragem em loop por reamostra para n grande.
    if n * n_reamostragens > 5_000_000:
        estimativas = np.empty(n_reamostragens)
        for i in range(n_reamostragens):
            indices = rng.integers(0, n, size=n)
            reamostra = amostras[indices]
            estimativas[i] = np.percentile(reamostra, percentil, method="lower")
    else:
        indices = rng.integers(0, n, size=(n_reamostragens, n))
        reamostras = amostras[indices]
        estimativas = np.percentile(reamostras, percentil, axis=1, method="lower")

    return {
        "estimativa": int(np.percentile(amostras, percentil, method="lower")),
        "ic95_inferior": int(np.percentile(estimativas, 2.5, method="lower")),
        "ic95_superior": int(np.percentile(estimativas, 97.5, method="lower")),
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="IC 95% via bootstrap para p50, p95 e p99 por operação."
    )
    parser.add_argument("diretorio", type=Path)
    parser.add_argument(
        "--cenario",
        type=str,
        default=None,
        help="Nome do cenário (default: nome do diretório)",
    )
    parser.add_argument(
        "--reamostragens",
        type=int,
        default=10_000,
        help="Quantidade de reamostragens bootstrap (default 10 000, conforme T22)",
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=42,
        help="Semente do gerador pseudoaleatório (reprodutibilidade)",
    )
    args = parser.parse_args()

    cenario = args.cenario or args.diretorio.name
    por_op = carregar_latencias(args.diretorio)

    rng = np.random.default_rng(args.seed)
    resultado = {
        "cenario": cenario,
        "n_reamostragens": args.reamostragens,
        "seed": args.seed,
        "operacoes": {},
    }

    for op, amostras in sorted(por_op.items()):
        n = len(amostras)
        resultado["operacoes"][op] = {
            "n": int(n),
            "p50_ns": ic_bootstrap(amostras, 50, args.reamostragens, rng),
            "p95_ns": ic_bootstrap(amostras, 95, args.reamostragens, rng),
            "p99_ns": ic_bootstrap(amostras, 99, args.reamostragens, rng),
        }

    saida_path = args.diretorio / "bootstrap.json"
    saida_path.write_text(json.dumps(resultado, indent=2, ensure_ascii=False) + "\n")

    print(f"Cenário: {cenario}")
    print(f"Reamostragens bootstrap: {args.reamostragens}")
    for op, stats in resultado["operacoes"].items():
        print(f"  {op}  n={stats['n']:,d}")
        for chave in ("p50_ns", "p95_ns", "p99_ns"):
            v = stats[chave]
            print(
                f"    {chave:<10} estimativa={v['estimativa']/1e6:.3f}ms  "
                f"IC95=[{v['ic95_inferior']/1e6:.3f}, {v['ic95_superior']/1e6:.3f}]ms"
            )

    print(f"\nResumo gravado em {saida_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
