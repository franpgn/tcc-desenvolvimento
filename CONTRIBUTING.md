# Contribuindo com tcc-desenvolvimento

Este repositório segue um fluxo de trabalho estruturado. Resumo operacional:

## Papéis

- **Autor** — Francesco Pagani Galvão, autor do trabalho. Aprova planejamentos, decisões arquiteturais e *merges*.
- **Orientador** — Prof. Dr. Leonardo Bidese de Pinho. Acompanha decisões técnicas e valida entregas relevantes ao TCC.

## Fluxo

1. Leitura do conteúdo acadêmico do TCC e produção de planejamento técnico em `docs/`.
2. Validação do planejamento pelo autor.
3. Definição da próxima tarefa, com critérios de aceite e *branch* nominal.
4. Criação da *branch* `feature/<nome>` (ou `fix/`, `docs/`, `refactor/`, `test/`).
5. Implementação, teste e atualização da documentação relevante.
6. Reporte da entrega com objetivo, alterações, testes, evidências e pontos pendentes.
7. Revisão; se necessário, ajustes.
8. Validação final do autor.
9. Após validação, *merge* para `main` (ou abertura de PR equivalente).

## Padrão de *branches*

```
main                          # linha de entrega; só recebe merge após validação do autor
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
- Pontos para validação do autor

## Regras vinculantes

1. **Nada vai para `main` sem aprovação explícita do autor.**
2. **Nenhum `git push` ocorre sem aprovação do autor.** O ambiente de trabalho mantém *commits* locais até a publicação ser autorizada.
3. **A estrutura textual da monografia é imutável** a partir deste repositório.
4. **Toda decisão técnica precisa de respaldo no texto do TCC.** Se o texto não cobre, é necessária validação prévia do autor antes de prosseguir.
5. **Resumos técnicos para o TCC** entram em `docs/resumos-para-tcc/` no formato fixado em `docs/planejamento-inicial.md`.
