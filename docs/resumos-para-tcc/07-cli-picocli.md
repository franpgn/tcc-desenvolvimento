# CLI Picocli do workload (B-10)

## O que foi feito

A linha de comando do `WorkloadMain` foi migrada de *parsing* posicional (`args[0]`, `args[1]`, ...) para uma classe `Cli` anotada com `@Command` e `@Option` do Picocli 4.7.6. A CLI oferece onze opções nomeadas, com aliases curtos para as mais frequentes: `--scenario`/`-s`, `--duration`/`-d`, `--ops`/`-o`, `--rep`/`-r`, `--threads`/`-t`, além de `--servers`, `--username`, `--password`, `--seed`, `--csv-dir`, `--warmup-min-sec`, `--dry-run`, `--help` e `--version`. Os *defaults* seguem a Tabela 1: $10^6$ operações (T9), 30 repetições (T10), 600\,s de duração (T14), 60\,s de warm-up mínimo (T11).

A separação entre parsing e execução é deliberada: `Cli` é um *value object* sem regra de negócio, e `WorkloadMain.main` usa `CommandLine.parseArgs()` em vez de `execute()`. Essa formulação permite testar a CLI sem instanciar dependências do Hot Rod e simplifica a futura adição de subcomandos. A validação dos parâmetros (`Cli.validar()`) rejeita valores fora de faixa (duração não-positiva, *threads* negativos, *servers* vazio) com mensagem informativa e *exit code* 2; falhas de execução produzem *exit code* 3 com *stack trace* em `stderr`. O *jar shaded* gerado por `mvn package` é o executável final, com `--version` retornando `session-workload 0.1.0-SNAPSHOT`.

## O que isso significa para a monografia

- **Cap. 4 §4.1** pode citar (em versões futuras) que o programa de carga é executado por uma CLI com onze opções nomeadas, validação por contrato e *help* autogerado, com *defaults* alinhados a T9, T10, T11 e T14 da Tabela 1.
- A frase atual em **Cap. 4 §4.4** ("o programa de carga compila e empacota como artefato Maven; sua execução contra o cluster vivo aguarda ambiente com Podman e NET_ADMIN disponíveis") pode ser complementada com a observação de que o *jar* já aceita as opções necessárias para a Sem. 9-10 (`--scenario`, `--rep`, `--csv-dir`, `--seed`).

## Arquivos no repositório

- `workload/src/main/java/br/unipampa/tcc/session/Cli.java` — `@Command` e `@Option`.
- `workload/src/main/java/br/unipampa/tcc/session/WorkloadMain.java` — `parseArgs` + `executar(Cli)`.
- `workload/src/test/java/br/unipampa/tcc/session/CliTest.java` — 9 testes cobrem *defaults*, parsing curto/longo, validação, `--dry-run`, `--csv-dir`, `toString` não expõe senha.
