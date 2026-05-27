#!/usr/bin/env python3
"""
analysis/gerar_dados_sinteticos.py
==================================

Gera CSVs sintéticos no formato produzido pelo programa de carga,
para validar o pipeline de análise (percentis.py, bootstrap_ic.py,
compare_scenarios.py) antes que o workload real esteja disponível.

A distribuição de latência por operação é simulada como lognormal
com cauda longa, parametrizada por (mu, sigma) em log-espaço de
milissegundos. Cenários com falha (F1, F3) recebem ajustes nesses
parâmetros conforme as linhas T17 e T18 da Tabela 1 do Cap. 3 §3.3.5.

NÃO substitui execução real: serve apenas para garantir que os scripts
de análise funcionam corretamente quando alimentados com dados no
formato esperado.

Uso:
    python3 gerar_dados_sinteticos.py <diretorio_saida> --cenario S1-sem-falha
    python3 gerar_dados_sinteticos.py <diretorio_saida> --cenario S1-F1 --repeticoes 3
"""
from __future__ import annotations

import argparse
import csv
import sys
import os
from pathlib import Path

import numpy as np


CENARIOS = {
    # latência base lognormal em ms: (mu_log, sigma_log)
    "S1-sem-falha":  {"login": (0.0, 0.4), "validate": (-0.7, 0.3),
                      "logout": (0.0, 0.4), "incrementFailure": (-0.5, 0.3),
                      "resetFailures": (-0.5, 0.3), "block": (0.1, 0.4),
                      "unblock": (0.1, 0.4)},
    # F1: durante a janela de crash, p99 sobe; modelado como mistura
    "S1-F1":         {"login": (0.1, 0.6), "validate": (-0.5, 0.5),
                      "logout": (0.1, 0.6), "incrementFailure": (-0.3, 0.5),
                      "resetFailures": (-0.3, 0.5), "block": (0.2, 0.6),
                      "unblock": (0.2, 0.6)},
    # F3: cauda inflada por jitter lognormal adicional
    "S1-F3":         {"login": (0.0, 0.7), "validate": (-0.5, 0.7),
                      "logout": (0.0, 0.7), "incrementFailure": (-0.3, 0.6),
                      "resetFailures": (-0.3, 0.6), "block": (0.1, 0.7),
                      "unblock": (0.1, 0.7)},
}

REPLICAS = ("r1", "r2", "r3")


def gerar_arquivo(saida: Path, perfis: dict, n_operacoes: int, seed: int) -> None:
    rng = np.random.default_rng(seed)
    operacoes = list(perfis.keys())

    nomes_op = {
        "login":            "Login",
        "validate":         "Validate",
        "logout":           "Logout",
        "incrementFailure": "IncrementFailure",
        "resetFailures":    "ResetFailures",
        "block":            "Block",
        "unblock":          "Unblock",
    }

    with saida.open("w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["op_id", "operation", "start_ns", "end_ns",
                    "replica", "return_code", "key"])

        agora_ns = 1_700_000_000 * 1_000_000_000
        for i in range(n_operacoes):
            op_key = rng.choice(operacoes)
            op_nome = nomes_op[op_key]
            mu, sigma = perfis[op_key]
            # latência em ms -> nanossegundos
            lat_ns = int(rng.lognormal(mean=mu, sigma=sigma) * 1_000_000)
            inicio_ns = agora_ns + int(rng.uniform(0, 1_000_000_000))
            fim_ns = inicio_ns + lat_ns
            rep = rng.choice(REPLICAS)
            chave = f"u_{int(rng.integers(0, 1000))}"
            # 1% de erro para simular código de retorno não-sucesso
            codigo = "OK" if rng.uniform() > 0.01 else "ERR"
            w.writerow([i, op_nome, inicio_ns, fim_ns, rep, codigo, chave])

            agora_ns += 1_000_000  # avança ~1ms por operação


def main() -> int:
    parser = argparse.ArgumentParser(description="Gerador sintético de CSVs por cenário.")
    parser.add_argument("diretorio", type=Path,
                        help="Diretório de saída (será criado se não existir)")
    parser.add_argument("--cenario", choices=sorted(CENARIOS), required=True)
    parser.add_argument("--repeticoes", type=int, default=3,
                        help="Número de arquivos CSV (representam repetições)")
    parser.add_argument("--operacoes", type=int, default=10_000,
                        help="Operações por CSV (default 10 000 — reduzido para testes)")
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()

    args.diretorio.mkdir(parents=True, exist_ok=True)
    perfis = CENARIOS[args.cenario]

    for rep in range(args.repeticoes):
        saida = args.diretorio / f"rep_{rep:03d}.csv"
        gerar_arquivo(saida, perfis, args.operacoes, args.seed + rep)
        print(f"  gerado: {saida}  ({args.operacoes:,d} operações)")

    print(f"\nCenário {args.cenario}: {args.repeticoes} arquivo(s) "
          f"de {args.operacoes:,d} operações em {args.diretorio}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
