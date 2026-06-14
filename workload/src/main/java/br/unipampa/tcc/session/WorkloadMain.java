package br.unipampa.tcc.session;

import org.infinispan.client.hotrod.RemoteCacheManager;
import org.infinispan.client.hotrod.configuration.ConfigurationBuilder;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.ThreadLocalRandom;

/**
 * Ponto de entrada do workload.
 *
 * Conecta ao cluster Infinispan, executa operações concorrentes do protocolo
 * de sessão por um intervalo configurado e registra latências e violações.
 *
 * Argumentos posicionais (ou variáveis de ambiente equivalentes):
 *   args[0] = duração em segundos (padrão 60)
 *   args[1] = número de threads (padrão 8)
 *   args[2] = host:port,host:port,... (padrão 127.0.0.1:11222,127.0.0.1:11223,127.0.0.1:11224)
 *   args[3] = cenário S1 ou S2 (padrão S1; também aceito via env TCC_SCENARIO)
 *
 * Determinismo: a seed base do {@link KeyGenerator} é lida da variável de
 * ambiente {@code TCC_SEED} ou cai em 42; cada thread recebe seed = base + tid,
 * o que permite reprodução exata da sequência de chaves entre rodadas.
 */
public class WorkloadMain {

    private static final long SEED_PADRAO = 42L;

    public static void main(String[] args) throws Exception {
        int duracaoSeg = args.length > 0 ? Integer.parseInt(args[0]) : 60;
        int threads = args.length > 1 ? Integer.parseInt(args[1]) : 8;
        String servers = args.length > 2 ? args[2]
                : "127.0.0.1:11222,127.0.0.1:11223,127.0.0.1:11224";
        Scenario cenario = Scenario.porNome(
                args.length > 3 ? args[3] : System.getenv("TCC_SCENARIO"));
        long seedBase = lerSeedBase();

        System.out.printf("Cenario %s, seed base %d, threads %d, duracao %ds%n",
                cenario, seedBase, threads, duracaoSeg);

        ConfigurationBuilder cb = new ConfigurationBuilder();
        for (String s : servers.split(",")) {
            String[] hp = s.split(":");
            cb.addServer().host(hp[0]).port(Integer.parseInt(hp[1]));
        }
        cb.security().authentication()
                .enable()
                .username("admin")
                .password("infinispan");

        try (RemoteCacheManager rcm = new RemoteCacheManager(cb.build())) {
            long inicioMs = System.currentTimeMillis();
            WarmupPolicy politica = WarmupPolicy.padrao(inicioMs, duracaoSeg);
            LatencyRegistry latency = new LatencyRegistry(politica);
            InvariantAuditor auditor = new InvariantAuditor();
            SessionOps ops = new SessionOps(rcm, latency, auditor);

            System.out.printf(
                "Warm-up ate +%ds; medicao a partir de +%ds; total %ds%n",
                (politica.warmupAteMs() - inicioMs) / 1000L,
                (politica.medicaoInicioMs() - inicioMs) / 1000L,
                duracaoSeg);

            ExecutorService pool = Executors.newFixedThreadPool(threads);
            long fim = politica.medicaoFimMs();

            for (int t = 0; t < threads; t++) {
                final int tid = t;
                final long seedThread = seedBase + tid;
                pool.submit(() -> rodarCliente(ops, tid, fim, cenario, seedThread));
            }

            pool.shutdown();
            pool.awaitTermination(duracaoSeg + 30, TimeUnit.SECONDS);

            System.out.println("Violacoes detectadas: " + auditor.total());
            latency.snapshot().forEach((op, h) ->
                System.out.printf(
                        "%-16s n=%d (descartados=%d) p50=%dns p95=%dns p99=%dns p999=%dns%n",
                        op,
                        h.getTotalCount(),
                        latency.descartados(op),
                        h.getValueAtPercentile(50.0),
                        h.getValueAtPercentile(95.0),
                        h.getValueAtPercentile(99.0),
                        h.getValueAtPercentile(99.9))
            );

            String dump = System.getenv("LATENCY_CSV");
            if (dump != null && !dump.isBlank()) {
                latency.dumpCsv(java.nio.file.Path.of(dump));
                System.out.println("Latencias gravadas em " + dump);
            }
        }
    }

    /**
     * Loop de geração de carga para uma thread.
     *
     * <p>A distribuição das operações segue o cenário (T7 da Tabela 1);
     * a seleção das chaves de sessão segue Zipfian ρ=0,99 sobre um
     * universo de 100.000 chaves (T5, T6, T8 da Tabela 1). A identidade
     * fica associada à thread, refletindo o padrão típico de sessão por
     * usuário.</p>
     */
    private static void rodarCliente(SessionOps ops, int tid, long deadline,
                                     Scenario cenario, long seed) {
        ThreadLocalRandom r = ThreadLocalRandom.current();
        KeyGenerator chaves = new KeyGenerator(seed);
        String identidade = "user-" + tid;
        while (System.currentTimeMillis() < deadline) {
            String sid = chaves.nextSessionKey();
            try {
                switch (cenario.proximaOperacao(r)) {
                    case VALIDATE -> ops.validate(sid);
                    case LOGIN_VALIDATE_LOGOUT -> {
                        OpResult login = ops.login(identidade, "cred");
                        if (login.code() == OpResult.Code.OK_LOGIN) {
                            String novoSid = login.sessionId();
                            ops.validate(novoSid);
                            ops.logout(novoSid);
                        }
                    }
                    case LOGOUT -> ops.logout(sid);
                    case INCREMENT_FAILURE -> ops.incrementFailure(identidade);
                    case RESET_FAILURES -> ops.resetFailures(identidade);
                }
            } catch (Exception e) {
                // erro de transporte; registra mas não interrompe.
            }
        }
    }

    private static long lerSeedBase() {
        String env = System.getenv("TCC_SEED");
        if (env == null || env.isBlank()) {
            return SEED_PADRAO;
        }
        try {
            return Long.parseLong(env.trim());
        } catch (NumberFormatException e) {
            return SEED_PADRAO;
        }
    }
}
