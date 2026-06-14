# Gerador Zipfian e cenários de mistura (B-08)

## O que foi feito

A classe `KeyGenerator` implementa o algoritmo Rejection-Inversion de Hörmann e Derflinger (1996) para amostragem Zipfian sobre um universo de inteiros $[1, n]$. O construtor padrão usa $n = 100\,000$ e $\rho = 0{,}99$, valores prescritos pelas linhas T6 (distribuição) e T8 (cardinalidade) da Tabela 1, e os parâmetros são reproduzíveis dada uma *seed*. A implementação é autocontida (cerca de 140 linhas), sem dependência externa para Zipf, com custo $O(1)$ por amostra e $O(1)$ na construção; a escolha contrasta com a `ZipfianGenerator` do YCSB (dependência pesada) e com `org.apache.commons:commons-math3` (dependência por uma única classe). O método `nextSessionKey()` produz chaves formatadas como `sid-NNNNNN` (seis dígitos), o que mantém o universo determinístico entre rodadas.

O enum `Scenario` codifica a mistura de operações T7. O cenário **S1** distribui 50\,\% em validação (O2), 25\,\% em tríade *login*-validate-*logout* (O1+O2+O3), 10\,\% em *logout* isolado (O3), 10\,\% em incremento de tentativas falhas (O4) e 5\,\% em *reset* (O5), totalizando 50/50 leituras/escritas. O cenário **S2** concentra 95\,\% em validação e distribui 5\,\% entre as escritas, modelando uma carga 95/5 do tipo *session store* já estabilizada. Ambos os cenários são selecionáveis via CLI (`--scenario`) e a mistura é sorteada por `ThreadLocalRandom` em cada chamada de `proximaOperacao`.

## O que isso significa para a monografia

- **Cap. 3 §3.3.5** já cita Zipfian com $\rho=0{,}99$ e os cenários S1 e S2 na Tabela 1 (linhas T6, T7); este resumo registra que a implementação está pronta e que ela é determinística.
- **Cap. 4 §4.1** pode acrescentar uma frase nas próximas versões mencionando que a seleção de chaves usa o gerador Zipfian autocontido cuja distribuição empírica foi validada por teste JUnit ($< 5\,\%$ de erro relativo nos primeiros 100 *bins* em $10^6$ amostras).

## Arquivos no repositório

- `workload/src/main/java/br/unipampa/tcc/session/KeyGenerator.java` — Rejection-Inversion.
- `workload/src/main/java/br/unipampa/tcc/session/Scenario.java` — enum S1/S2 com pesos.
- `workload/src/test/java/br/unipampa/tcc/session/KeyGeneratorTest.java` — distribuição, reprodutibilidade, cobertura.
- `workload/src/test/java/br/unipampa/tcc/session/ScenarioTest.java` — pesos S1 e S2 com erro \(< 2\,\%\).
