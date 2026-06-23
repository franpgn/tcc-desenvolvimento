# Registro de problemas

> Diário técnico de problemas encontrados na frente prática e suas resoluções. Cada entrada registra sintoma, diagnóstico e correção, com referência ao *commit*/arquivo.

## 2026-06-22 — Formação do cluster e baseline F1

### P-01 — `Unknown security domain 'default'` ao subir o nó

- **Sintoma:** os três nós saíam com `FATAL ISPN080028 ... ISPN080014: Unknown security domain 'default'`.
- **Causa:** `cluster/infinispan-cluster.xml` substitui integralmente o `infinispan.xml` da imagem; o `<endpoints security-realm="default"/>` referenciava um *realm* que a imagem definia, mas que se perdeu na substituição.
- **Correção:** redeclarar `<security><security-realms><security-realm name="default"><properties-realm/></security-realm></security-realms></security>` no `<server>`. O usuário `admin` continua sendo criado pelo *entrypoint* (env `USER`/`PASS`). Commit `fix(cluster): forma cluster size=3`.

### P-02 — TCPPING: `num_initial_members` não reconhecido

- **Sintoma:** `JGRP000001: configuration error: the following properties in TCPPING are not recognized: {num_initial_members=3}`.
- **Causa:** o atributo `num_initial_members` foi **removido** de `TCPPING` no JGroups 5.x (a contagem passou a ser derivada de `initial_hosts`). A imagem usa JGroups 5.3.16.Final.
- **Correção:** remover `num_initial_members` do `cluster/jgroups-tcp.xml`; a formação determinística do *cluster* fica a cargo do GMS sobre os 3 hosts estáticos.

### P-03 — `bind_addr=0.0.0.0` inválido no TCP do JGroups

- **Sintoma:** `BindException: [TCP] /0.0.0.0 is not a valid address on any local network interface`.
- **Causa:** o protocolo `TCP` do JGroups não aceita o literal `0.0.0.0` como `bind_addr`.
- **Correção:** usar o símbolo `SITE_LOCAL`, resolvido pelo JGroups para o IP privado da interface do *container* na rede *bridge*. Após isso o *cluster* forma: `Received new cluster view ... (3) [isn3, isn1, isn2]`, `health HEALTHY`, `number_of_nodes=3`.

### P-04 — REST health retorna 403 com BASIC auth

- **Sintoma:** `curl -u admin:infinispan` → `403 ISPN080052: The request authentication mechanism 'null' is not supported`.
- **Causa:** o *endpoint* REST do Infinispan 15 exige autenticação **DIGEST**; `curl -u` usa BASIC por padrão.
- **Correção:** usar `curl --digest -u admin:infinispan` (e nos *healthchecks* do `podman-compose.yml`).

### P-05 — Hot Rod: `ISPN004015 Failed adding new server 10.89.x.x`

- **Sintoma:** ~35% das operações com `ERROR_TRANSPORT`; cliente registrava `Failed adding new server 10.89.1.4/<unresolved>:11222`.
- **Causa:** o cliente Hot Rod recebia a topologia com os **IPs internos** dos *containers* (`10.89.x.x`), inalcançáveis a partir do *host* Windows/WSL2. As chaves cujo *owner* não fosse o nó de conexão falhavam.
- **Correção:** `<endpoint><hotrod-connector external-host="127.0.0.1" external-port="..."/></endpoint>`. O `external-port` por nó (11222/11223/11224) é passado como **argumento de servidor** `-Dinfinispan.hotrod.external-port=...` no `command` do *compose* — `JAVA_OPTS` via *env* é sobrescrito por `server.conf` e não funciona. A topologia passou a anunciar `127.0.0.1:11222/11223/11224` e `ISPN004015` zerou.

### P-06 — Hot Rod: erro de *marshalling* de POJOs (ERROR_TRANSPORT residual)

- **Sintoma:** mesmo após P-05, ~35% `ERROR_TRANSPORT`; todo `put` de `SessionState`/`IdentityState` falhava.
- **Causa:** o *marshaller* padrão do Hot Rod é **ProtoStream**, que exige *schema* registrado; os valores são POJOs `Serializable` sem *schema*.
- **Correção:** configurar `JavaSerializationMarshaller` no `ConfigurationBuilder` do `WorkloadMain`, com *allow-list* `br.unipampa.tcc.session.*` e `java.time.*`. Smoke passou a `0 ERROR_TRANSPORT` / `taxa_erro 0%`. Commit `fix(workload): usa JavaSerializationMarshaller`.

### P-07 — Janela de medição vazia em execuções curtas

- **Sintoma:** *smoke* de 60s não gravava eventos; resumo parava em "Warm-up ate +10s".
- **Causa:** `WarmupPolicy.padrao` usava o piso fixo de 60s de warm-up (`max(60, 10%*dur)`), consumindo toda uma execução curta; `--warmup-min-sec` da CLI não era repassado.
- **Correção:** *overload* `WarmupPolicy.padrao(..., warmupMinimoSeg, clock)` e fiação de `cli.warmupMinimoSeg` no `WorkloadMain`. O *default* de 60s permanece para as baterias reais. Commit `feat(workload): wire --warmup-min-sec`.

## 2026-06-23 — Baseline F3 na VM Ubuntu

### P-08 — `podman exec <node> tc ...` não aplica netem (F3)

- **Sintoma:** ao rodar o baseline F3 na VM, a injeção falhava: a imagem oficial Infinispan (UBI minimal) não tem `tc` no `PATH` e o container não recebe a capability `NET_ADMIN`, então `podman exec <node> tc qdisc add ... netem` é rejeitado.
- **Diagnóstico/validação:** aplicar o `netem` **a partir do host**, entrando no *namespace de rede* do container via `nsenter`, funciona (exit 0; `qdisc netem ... delay 20ms 13ms` aplicado no `eth0` do container e removido limpo). Comandos validados manualmente: `PID=$(podman inspect -f '{{.State.Pid}}' isn2)`; `sudo nsenter -t $PID -n tc qdisc add dev eth0 root netem delay 20ms 13ms distribution normal`; `... qdisc show`; `... qdisc del dev eth0 root`.
- **Correção:** `scripts/inject-jitter.sh` e `verificar_sem_netem()` em `scripts/run-baseline.sh` migrados de `podman exec` para `sudo nsenter -t <pid> -n tc ...`, com o PID resolvido por `podman inspect` antes de registrar o `trap` de cleanup (cleanup idempotente em EXIT/INT/TERM mesmo se o `add` falhar). Dependências da execução real agora incluem `nsenter` (util-linux) e `sudo` no host (container não precisa de `tc`/`NET_ADMIN`); `--dry-run` segue sem dependências. Exit codes preservados (3 dependência ausente, 4 container/PID, 5 netem rejeitado). Recomenda-se `sudo` sem senha para a bateria (cache do sudo expira em ~15 min). Detalhe em `docs/implementacao.md` TD-007. Commit `fix(f3): aplica netem via nsenter host-side`.

## Observação de modelagem (não é defeito)

Com 8 *threads* = 8 identidades fixas (`user-<tid>`), `incrementFailure`
atinge o limite (5) cedo e bloqueia a identidade; logins subsequentes
retornam `BLOCKED` e `validate` retorna `NONE` (sem sessão criada).
Isso é comportamento de domínio correto (códigos de sucesso, não erro) e
produz dados válidos com `taxa_erro ~0`. Para variar mais o estado em
baterias futuras, ampliar o universo de identidades.
