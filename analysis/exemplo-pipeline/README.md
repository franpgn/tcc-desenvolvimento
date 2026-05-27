# exemplo-pipeline

> **Aviso:** os JSONs deste diretório foram gerados por dados sintéticos produzidos por `analysis/gerar_dados_sinteticos.py`. **Não são resultados experimentais do Infinispan real.** Servem exclusivamente como evidência de que o *pipeline* de análise (B-16, B-17, B-18) funciona ponta a ponta quando alimentado por CSVs no formato definido em `analysis/README.md`.

## O que está aqui

| Arquivo | Origem | Conteúdo |
|---|---|---|
| `S1-sem-falha/summary.json` | `percentis.py runs/S1-sem-falha` | p50/p95/p99 por operação, taxa de erro |
| `S1-sem-falha/bootstrap.json` | `bootstrap_ic.py runs/S1-sem-falha --reamostragens 5000` | IC 95% para p50/p95/p99 |
| `S1-F1/summary.json` | `percentis.py runs/S1-F1` | mesma forma, sob cenário F1 simulado |
| `S1-F1/comparacao.json` | `compare_scenarios.py runs/S1-sem-falha runs/S1-F1` | Mann-Whitney pareado por operação, p-valor, $r$ |
| `S1-F3/summary.json` | idem F1 | sob cenário F3 |
| `S1-F3/comparacao.json` | idem F1 | F3 versus *baseline* |

## Como esses JSONs foram produzidos

Com OpenJDK Temurin 17 e Python 3.11 + numpy 2.4 + scipy 1.17, na sessão de implementação de B-16/17/18 (2026-05-27):

```bash
cd analysis
python3 gerar_dados_sinteticos.py ../runs/S1-sem-falha --cenario S1-sem-falha --repeticoes 5 --operacoes 50000
python3 gerar_dados_sinteticos.py ../runs/S1-F1        --cenario S1-F1        --repeticoes 5 --operacoes 50000
python3 gerar_dados_sinteticos.py ../runs/S1-F3        --cenario S1-F3        --repeticoes 5 --operacoes 50000

python3 percentis.py            ../runs/S1-sem-falha
python3 percentis.py            ../runs/S1-F1
python3 percentis.py            ../runs/S1-F3
python3 bootstrap_ic.py         ../runs/S1-sem-falha --reamostragens 5000
python3 compare_scenarios.py    ../runs/S1-sem-falha ../runs/S1-F1
python3 compare_scenarios.py    ../runs/S1-sem-falha ../runs/S1-F3
```

Volume: 3 cenários × 5 repetições × 50 000 operações = 750 000 operações sintéticas distribuídas entre sete tipos de operação. Tempo total dos seis comandos: poucos segundos.

## O que os resultados sintéticos confirmam

A geração de dados aplica perfis lognormais ajustados para reproduzir, em ordem de magnitude, o que se espera do experimento real:

- **`S1-sem-falha`**: latência base com cauda comportada, p99 entre 1 e 3 ms por operação.
- **`S1-F1` (*crash*)**: cauda inflada e mediana levemente deslocada, conforme F1 do Cap. 3 §3.3.2.
- **`S1-F3` (*jitter*)**: cauda inflada **preservando** mediana, conforme F3 do mesmo recorte.

A comparação Mann-Whitney detecta essa distinção: para F1, todas as sete operações têm p-valor $< 0,05$ (efeito generalizado). Para F3, operações com distribuição mais larga (`Block`, `Login`, `Logout`, `Unblock`) **não** rejeitam a hipótese nula na mediana, mas mostram delta positivo em p95 e p99 — exatamente o padrão de efeito-na-cauda esperado. Operações com distribuição mais estreita (`Validate`, contadores) rejeitam mesmo com efeitos pequenos por causa do volume de amostras.

Esse padrão é diagnóstico de um pipeline funcional: se o pipeline reportasse F1 e F3 com o mesmo perfil estatístico, isso indicaria que os testes não estão sensíveis à diferença qualitativa entre falhas.

## O que vem depois do experimento real

Quando o *workload* (`workload/`) estiver implementado por B-05 a B-10 e o *baseline* rodar com Infinispan + injeção de falhas (B-11, B-12, B-13, B-19), as saídas reais entram em `runs/<cenário>/` com os mesmos formatos. Os scripts de análise não precisam de ajuste; basta apontar para os novos diretórios.
