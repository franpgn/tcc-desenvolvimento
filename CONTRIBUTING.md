# Contribuindo com tcc-desenvolvimento

Este repositório segue um fluxo de trabalho específico, descrito em `docs/planejamento-inicial.md` e em [`/workspace/memoria-tcc/20-agentes-desenvolvimento.md`](../memoria-tcc/20-agentes-desenvolvimento.md) do projeto acadêmico. Resumo operacional:

## Papéis

- **Gestor** — Francesco Pagani Galvão (autor) e Prof. Dr. Leonardo Bidese de Pinho (orientador). Aprova planejamentos, decisões arquiteturais e *merges*.
- **Senior** — agente responsável por planejar, decompor em tarefas, definir critérios de aceite e revisar.
- **Worker** — agente responsável por implementar, testar e documentar conforme o plano do Senior.

## Fluxo

1. Senior lê o conteúdo acadêmico do TCC e produz planejamento técnico em `docs/`.
2. Gestor valida o planejamento.
3. Senior define a próxima tarefa para o Worker, com critérios de aceite e *branch* nominal.
4. Worker cria a *branch* `feature/<nome>` (ou `fix/`, `docs/`, `refactor/`, `test/`).
5. Worker implementa, testa e atualiza a documentação relevante.
6. Worker reporta ao Senior no formato "Execução do Worker".
7. Senior revisa e, se necessário, pede ajustes.
8. Gestor valida a entrega final.
9. Após validação, *merge* para `main` (ou abertura de PR equivalente).

## Padrão de *branches*

```
main                          # linha de entrega; só recebe merge após validação do Gestor
feature/<descrição-curta>     # nova funcionalidade
fix/<descrição-curta>         # correção de bug
docs/<descrição-curta>        # somente documentação
refactor/<descrição-curta>    # reorganização sem mudança de comportamento
test/<descrição-curta>        # adição ou ajuste de testes
```

## Padrão de commits

Mensagens curtas em modo imperativo, com prefixo de tipo:

```
feat: <descrição>
fix: <descrição>
docs: <descrição>
test: <descrição>
refactor: <descrição>
chore: <descrição>
```

Exemplos:

```
feat: adiciona configuração DIST_ASYNC para o cache sessions
fix: corrige timeout do health check do nó isn3
docs: registra decisão D-005 sobre versionamento de runs
test: adiciona smoke test do workload contra cluster local
```

## Padrão de pull request

Todo PR deve usar o gabarito em [`docs/pull-request-template.md`](docs/pull-request-template.md), com as seções:

- Objetivo
- Alterações realizadas
- Como testar
- Evidências
- Relação com o TCC
- Pontos para validação do gestor

## Regras vinculantes

1. **Nada vai para `main` sem aprovação explícita do Gestor.**
2. **Nenhum `git push` ocorre sem aprovação do Gestor.** O ambiente de trabalho mantém *commits* locais até a publicação ser autorizada.
3. **`/workspace/prototipo/` e `/workspace/*.tex` são imutáveis** para os agentes de desenvolvimento.
4. **Toda decisão técnica precisa de respaldo no texto do TCC.** Se o texto não cobre, o Senior solicita validação antes de prosseguir.
5. **Resumos técnicos para os agentes acadêmicos** entram em `docs/resumos-para-tcc/` no formato fixado em `/workspace/memoria-tcc/20-agentes-desenvolvimento.md` (Seção 6).
