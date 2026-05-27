package br.unipampa.tcc.session;

import org.infinispan.client.hotrod.RemoteCacheManager;
import org.infinispan.client.hotrod.configuration.ConfigurationBuilder;

import java.util.UUID;
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
 */
public class WorkloadMain {

    public static void main(String[] args) throws Exception {
        int duracaoSeg = args.length > 0 ? Integer.parseInt(args[0]) : 60;
        int threads = args.length > 1 ? Integer.parseInt(args[1]) : 8;
        String servers = args.length > 2 ? args[2]
                : "127.0.0.1:11222,127.0.0.1:11223,127.0.0.1:11224";

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
            LatencyRegistry latency = new LatencyRegistry();
            InvariantAuditor auditor = new InvariantAuditor();
            SessionOps ops = new SessionOps(rcm, latency, auditor);

            ExecutorService pool = Executors.newFixedThreadPool(threads);
            long fim = System.currentTimeMillis() + duracaoSeg * 1000L;

            for (int t = 0; t < threads; t++) {
                final int tid = t;
                pool.submit(() -> rodarCliente(ops, tid, fim));
            }

            pool.shutdown();
            pool.awaitTermination(duracaoSeg + 30, TimeUnit.SECONDS);

            System.out.println("Violacoes detectadas: " + auditor.total());
            latency.snapshot().forEach((op, arr) -> {
                long[] sorted = arr.clone();
                java.util.Arrays.sort(sorted);
                long p50 = sorted.length > 0 ? sorted[sorted.length / 2] : 0L;
                long p95 = sorted.length > 0 ? sorted[(int) (sorted.length * 0.95)] : 0L;
                long p99 = sorted.length > 0 ? sorted[(int) (sorted.length * 0.99)] : 0L;
                System.out.printf("%-16s n=%d p50=%dns p95=%dns p99=%dns%n",
                        op, sorted.length, p50, p95, p99);
            });
        }
    }

    private static void rodarCliente(SessionOps ops, int tid, long deadline) {
        ThreadLocalRandom r = ThreadLocalRandom.current();
        String identidade = "user-" + tid;
        while (System.currentTimeMillis() < deadline) {
            int op = r.nextInt(100);
            try {
                if (op < 50) {                       // 50% login + validate + logout
                    String sid = ops.login(identidade, "cred");
                    if (sid != null) {
                        ops.validate(sid);
                        ops.logout(sid);
                    }
                } else if (op < 75) {                // 25% validate aleatório (pode falhar)
                    ops.validate(UUID.randomUUID().toString());
                } else if (op < 95) {                // 20% incremento de falhas
                    ops.incrementFailure(identidade);
                } else {                              // 5% reset
                    ops.resetFailures(identidade);
                }
            } catch (Exception e) {
                // erro de transporte; registra mas não interrompe.
            }
        }
    }
}
