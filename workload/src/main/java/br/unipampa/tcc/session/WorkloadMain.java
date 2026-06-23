package br.unipampa.tcc.session;

import org.infinispan.client.hotrod.RemoteCacheManager;
import org.infinispan.client.hotrod.configuration.ConfigurationBuilder;

import picocli.CommandLine;

import java.nio.file.Path;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.ThreadLocalRandom;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Ponto de entrada do workload.
 *
 * <p>Conecta ao cluster Infinispan, executa operacoes concorrentes do
 * protocolo de sessao por um intervalo configurado e registra latencias
 * e violacoes. A configuracao de execucao vem da CLI ({@link Cli}),
 * parseada por Picocli. Para ajuda completa, execute o jar com
 * {@code --help}.</p>
 *
 * <p>Cobertura na Tabela 1 do Cap. 3 secao 3.3.5: a CLI parametriza
 * T7 (cenarios), T9 (operacoes), T10 (repeticoes), T11 (warm-up),
 * T13 (CSV de latencia), T14 (duracao); KeyGenerator cobre T5, T6, T8;
 * Scenario cobre T7; WarmupPolicy cobre T11.</p>
 */
public final class WorkloadMain {

    private WorkloadMain() { /* utility */ }

    public static void main(String[] args) {
        Cli cli = new Cli();
        CommandLine cmd = new CommandLine(cli);
        try {
            CommandLine.ParseResult pr = cmd.parseArgs(args);
            if (CommandLine.printHelpIfRequested(pr)) {
                return;
            }
        } catch (CommandLine.ParameterException e) {
            System.err.println(e.getMessage());
            cmd.usage(System.err);
            System.exit(2);
        }
        try {
            cli.validar();
        } catch (IllegalArgumentException e) {
            System.err.println("Configuracao invalida: " + e.getMessage());
            System.exit(2);
        }
        if (cli.dryRun) {
            System.out.println("dry-run, configuracao OK: " + cli);
            return;
        }
        try {
            executar(cli);
        } catch (Exception e) {
            System.err.println("Falha na execucao: " + e.getMessage());
            e.printStackTrace(System.err);
            System.exit(3);
        }
    }

    /**
     * Executa o número de repetições configuradas; cada repetição abre
     * seu próprio {@link RemoteCacheManager}, sua {@link WarmupPolicy}
     * e seu {@link LatencyRegistry}.
     */
    static void executar(Cli cli) throws Exception {
        System.out.println("Configuracao: " + cli);

        for (int rep = 1; rep <= cli.repeticoes; rep++) {
            System.out.printf("== Repeticao %d / %d ==%n", rep, cli.repeticoes);
            executarRepeticao(cli, rep);
        }
    }

    static void executarRepeticao(Cli cli, int rep) throws Exception {
        ConfigurationBuilder cb = new ConfigurationBuilder();
        for (String s : cli.servidores.split(",")) {
            String[] hp = s.split(":");
            cb.addServer().host(hp[0].trim()).port(Integer.parseInt(hp[1].trim()));
        }
        cb.security().authentication()
                .enable()
                .username(cli.usuario)
                .password(cli.senha);

        try (RemoteCacheManager rcm = new RemoteCacheManager(cb.build())) {
            long inicioMs = System.currentTimeMillis();
            WarmupPolicy politica = WarmupPolicy.padrao(inicioMs, cli.duracaoSeg);
            LatencyRegistry latency = new LatencyRegistry(politica);
            InvariantAuditor auditor = new InvariantAuditor();
            // Âncora epoch-ns capturada no início da repetição (T2): pareia
            // Instant.now() (parede) com System.nanoTime() (monotônico) para
            // converter cada evento monotônico em epoch-ns no CSV.
            EpochClock relogio = EpochClock.capturarAgora();
            EventCsvWriter eventos = new EventCsvWriter(politica);
            SessionOps ops = new SessionOps(rcm, latency, auditor, eventos, relogio);

            System.out.printf(
                "Warm-up ate +%ds; medicao a partir de +%ds; total %ds%n",
                (politica.warmupAteMs() - inicioMs) / 1000L,
                (politica.medicaoInicioMs() - inicioMs) / 1000L,
                cli.duracaoSeg);

            ExecutorService pool = Executors.newFixedThreadPool(cli.threads);
            AtomicLong totalOps = new AtomicLong();
            long opsAlvoPorThread = cli.ops > 0 ? cli.ops / cli.threads : Long.MAX_VALUE;
            long fim = politica.medicaoFimMs();

            for (int t = 0; t < cli.threads; t++) {
                final int tid = t;
                final long seedThread = cli.seedBase + (long) tid + (long) rep * 1_000_003L;
                pool.submit(() -> rodarCliente(ops, tid, fim, cli.scenario,
                        seedThread, opsAlvoPorThread, totalOps));
            }
            pool.shutdown();
            pool.awaitTermination(cli.duracaoSeg + 30, TimeUnit.SECONDS);

            System.out.printf("Total de operacoes: %d%n", totalOps.get());
            System.out.println("Violacoes detectadas: " + auditor.total());
            latency.snapshot().forEach((op, h) ->
                System.out.printf(
                        "%-22s n=%d (descartados=%d) p50=%dns p95=%dns p99=%dns p999=%dns%n",
                        op,
                        h.getTotalCount(),
                        latency.descartados(op),
                        h.getValueAtPercentile(50.0),
                        h.getValueAtPercentile(95.0),
                        h.getValueAtPercentile(99.0),
                        h.getValueAtPercentile(99.9))
            );

            if (cli.csvDir != null && !cli.csvDir.isBlank()) {
                Path destino = Path.of(cli.csvDir,
                        String.format("rep-%03d.csv", rep));
                eventos.flush(destino);
                System.out.printf(
                        "Eventos gravados em %s (registrados=%d, descartados_warmup=%d)%n",
                        destino, eventos.totalRegistrados(), eventos.descartadosWarmup());
            }
        }
    }

    /**
     * Loop de geração de carga para uma thread; termina quando o tempo
     * limite for atingido ou quando a thread tiver gerado seu alvo de
     * operações ({@link Cli#ops} dividido pelo número de threads).
     */
    private static void rodarCliente(SessionOps ops, int tid, long deadline,
                                     Scenario cenario, long seed,
                                     long opsAlvo, AtomicLong totalOps) {
        ThreadLocalRandom r = ThreadLocalRandom.current();
        KeyGenerator chaves = new KeyGenerator(seed);
        String identidade = "user-" + tid;
        long executadas = 0;
        while (System.currentTimeMillis() < deadline && executadas < opsAlvo) {
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
                executadas++;
                totalOps.incrementAndGet();
            } catch (Exception e) {
                // erro de transporte; conta tentativa mas não interrompe.
                executadas++;
                totalOps.incrementAndGet();
            }
        }
    }
}
