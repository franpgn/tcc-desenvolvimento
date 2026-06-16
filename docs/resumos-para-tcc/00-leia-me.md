# Resumos para o TCC

> Diretório consumido pelo agente acadêmico (Escritor + Revisor + Bibliotecário) quando precisa redigir trechos do Capítulo 4 (Desenvolvimento e Resultados Parciais) ou do Capítulo 5 (Considerações Finais). Cada arquivo cobre um bloco fechado do *backlog* da frente prática e sugere onde a informação se encaixa na monografia.

## Convenção

- Cada arquivo é nomeado `NN-tema.md` onde `NN` ordena por dependência conceitual.
- Cada arquivo tem três seções: **O que foi feito**, **O que isso significa para a monografia** e **Arquivos no repositório**.
- Status de cada bloco está em [`docs/planejamento-inicial.md`](../planejamento-inicial.md) §"Backlog inicial".

## Índice

| Arquivo | Bloco(s) coberto(s) | Camada |
|---|---|---|
| [01-cluster-infinispan.md](01-cluster-infinispan.md) | B-02, B-03 | cluster |
| [02-workload-esqueleto-opresult.md](02-workload-esqueleto-opresult.md) | B-04, B-05 | workload |
| [03-latency-registry.md](03-latency-registry.md) | B-06 | workload |
| [04-invariant-auditor.md](04-invariant-auditor.md) | B-07 | workload |
| [05-keygenerator-scenario.md](05-keygenerator-scenario.md) | B-08 | workload |
| [06-warmup-policy.md](06-warmup-policy.md) | B-09 | workload |
| [07-cli-picocli.md](07-cli-picocli.md) | B-10 | workload |
| [08-scripts-injecao-falha.md](08-scripts-injecao-falha.md) | B-11, B-12 | scripts |
| [09-collect-metrics.md](09-collect-metrics.md) | B-13 | scripts |
| [10-spec-tla-tlc.md](10-spec-tla-tlc.md) | B-14, B-15 | spec |
| [11-analysis-python.md](11-analysis-python.md) | B-16, B-17, B-18 | análise |
| [12-run-baseline.md](12-run-baseline.md) | B-19 | scripts |
| [13-cobertura-tabela1.md](13-cobertura-tabela1.md) | mapeamento geral | meta |

## Como usar (Escritor)

1. Identifique o trecho da monografia a redigir ou ajustar.
2. Localize o(s) bloco(s) correspondente(s) por meio do índice ou da §"Backlog inicial" do planejamento.
3. Leia o resumo, confira o caminho dos arquivos, copie/parafraseie nas seções pertinentes do `.tex`.
4. Confirme com [`13-cobertura-tabela1.md`](13-cobertura-tabela1.md) quais linhas T1 a T22 da Tabela 1 estão sustentadas pela implementação atual.
