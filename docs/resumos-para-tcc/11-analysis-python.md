# Pipeline de análise estatística em Python (B-16, B-17, B-18)

## O que foi feito

Três scripts Python implementam a análise estatística dos resultados do *baseline*, conforme as linhas T13 e T22 da Tabela 1. O `analysis/percentis.py` lê os CSVs de latência produzidos pelo `LatencyRegistry` (formato `op,count,mean_ns,p50_ns,p95_ns,p99_ns,p999_ns,max_ns`) e agrega por cenário, calculando os percentis p50, p95, p99 e (quando $n \ge 10^6$) p99,9 com base nos histogramas reportados; o `analysis/bootstrap_ic.py` aplica reamostragem *bootstrap* com 10\,000 réplicas para estimar intervalo de confiança de 95\,\% por percentil; o `analysis/compare_scenarios.py` aplica teste de Mann-Whitney pareado por percentil para comparar dois cenários, devolvendo p-valor não corrigido por cenário.

O pipeline foi validado em 750\,000 operações sintéticas geradas pelo `analysis/gerar_dados_sinteticos.py`, com resultados depositados em `analysis/exemplo-pipeline/`. Os três scripts são executados em sequência pelo `scripts/run-baseline.sh` após o término de cada combinação cenário × falha, gerando `summary.json` por (cenário, falha) com os campos `p50`, `p95`, `p99`, `p999`, IC95, e — quando comparado a outro cenário — p-valor de Mann-Whitney. A escolha de Python + NumPy + SciPy seguiu D-003 (aprovada).

A correção para múltiplas comparações (Bonferroni ou Benjamini-Hochberg sobre 84 testes para o experimento completo de 12 cenários × 7 operações) está registrada como decisão pendente do autor; o script atual reporta p-valor bruto, com a correção a ser aplicada na agregação final pelo Escritor antes da inclusão no Capítulo 4.

## O que isso significa para a monografia

- **Cap. 3 §3.3.4 e §3.3.5** já citam Mann-Whitney por percentil e *bootstrap* com 10\,000 reamostragens; este resumo registra a operacionalização.
- **Cap. 4** quando o *baseline* real for executado: pode citar que `summary.json` é o entregável da análise por cenário, com IC95 *bootstrap* e p-valor não corrigido entre cenários comparados.
- A pendência da correção de múltiplas comparações está nas decisões do autor (D-001 da Rodada 8 da discussão `24-...md`); cabe ao Escritor ajustar o texto conforme a decisão final.

## Arquivos no repositório

- `analysis/percentis.py` — agregação de percentis por cenário.
- `analysis/bootstrap_ic.py` — IC95 *bootstrap*.
- `analysis/compare_scenarios.py` — Mann-Whitney pareado.
- `analysis/gerar_dados_sinteticos.py` — gerador de dados para validação.
- `analysis/exemplo-pipeline/` — exemplos validados.
- `analysis/requirements.txt` — `numpy`, `scipy`.
