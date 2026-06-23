package br.unipampa.tcc.session;

import org.infinispan.client.hotrod.RemoteCache;
import org.infinispan.client.hotrod.RemoteCacheManager;
import java.time.Instant;
import java.util.UUID;

/**
 * Operações O1 a O7 do protocolo de estado de sessão, conforme Seção 4.1 da monografia.
 *
 * O1 login(id, cred): cria nova sessão para id se OPEN.
 * O2 validate(s): retorna estado lógico da sessão s.
 * O3 logout(s): marca s como Invalid com motivo logout (idempotente).
 * O4 incrementFailure(id): incrementa contador da id; bloqueia se >= limite.
 * O5 resetFailures(id): zera contador da id.
 * O6 block(id, motivo): marca id como Blocked e invalida sessões ativas associadas.
 * O7 unblock(id): remove a marca Blocked.
 *
 * Cada operação retorna um {@link OpResult} e registra timestamps de início e fim em
 * {@link LatencyRegistry}.
 */
public class SessionOps {

    public static final int LIMITE_TENTATIVAS = 5;

    /** Nomes canônicos das operações O1–O5 na coluna {@code operation} do CSV. */
    public static final String OP_LOGIN = "Login";              // O1
    public static final String OP_VALIDATE = "Validate";        // O2
    public static final String OP_LOGOUT = "Logout";            // O3
    public static final String OP_INCREMENT_FAILURE = "IncrementFailure"; // O4
    public static final String OP_RESET_FAILURES = "ResetFailures";       // O5

    private final RemoteCache<String, SessionState> sessions;
    private final RemoteCache<String, IdentityState> identities;
    private final LatencyRegistry latency;
    private final InvariantAuditor auditor;
    private final EventCsvWriter eventos;
    private final EpochClock relogio;
    private final String replica;

    /**
     * Construtor sem trilha de eventos (mantém compatibilidade com testes
     * existentes e com execuções que só geram o resumo de latência).
     */
    public SessionOps(RemoteCacheManager rcm, LatencyRegistry latency, InvariantAuditor auditor) {
        this(rcm, latency, auditor, null, null);
    }

    /**
     * Construtor com trilha de eventos. Se {@code eventos} ou {@code relogio}
     * forem nulos, a instrumentação de eventos crus é desligada e apenas o
     * {@link LatencyRegistry} é alimentado.
     *
     * <p>A {@code replica} é resolvida como o servidor de conexão (primeiro
     * servidor configurado no {@link RemoteCacheManager}), conforme o
     * <i>default</i> aprovado: obter o <i>owner</i> real por Hot Rod seria
     * caro, então o servidor de conexão é o fallback aceito.</p>
     */
    public SessionOps(RemoteCacheManager rcm, LatencyRegistry latency,
                      InvariantAuditor auditor, EventCsvWriter eventos,
                      EpochClock relogio) {
        this.sessions = rcm.getCache("sessions");
        this.identities = rcm.getCache("counters");
        this.latency = latency;
        this.auditor = auditor;
        this.eventos = eventos;
        this.relogio = relogio;
        this.replica = resolverReplica(rcm);
    }

    /**
     * Resolve o rótulo da replica a partir do primeiro servidor configurado
     * no cliente Hot Rod (fallback aceito ao owner real). Em caso de
     * qualquer falha de introspecção, devolve {@code "unknown"}.
     */
    private static String resolverReplica(RemoteCacheManager rcm) {
        try {
            return rcm.getConfiguration().servers().stream()
                    .findFirst()
                    .map(s -> s.host() + ":" + s.port())
                    .orElse("unknown");
        } catch (RuntimeException e) {
            return "unknown";
        }
    }

    /**
     * Emite um evento cru para a trilha de CSV, convertendo os instantes
     * monotônicos em epoch-ns. Faz no-op se a trilha estiver desligada.
     */
    private void emitir(String operation, long startMono, long endMono,
                        OpResult result, String key) {
        if (eventos == null || relogio == null) {
            return;
        }
        eventos.registrar(
                operation,
                relogio.paraEpochNanos(startMono),
                relogio.paraEpochNanos(endMono),
                replica,
                result.returnCode(),
                key);
    }

    /** O1, login. */
    public OpResult login(String identidade, String credencial) {
        long t0 = System.nanoTime();
        try {
            IdentityState idSt = identities.get(identidade);
            if (idSt == null) {
                idSt = IdentityState.criar(identidade, Instant.now());
                identities.put(identidade, idSt);
            }
            if (idSt.status() == IdentityState.Status.BLOCKED) {
                latency.record("login_blocked", t0);
                OpResult r = OpResult.blocked();
                emitir(OP_LOGIN, t0, System.nanoTime(), r, identidade);
                return r;
            }
            String sid = UUID.randomUUID().toString();
            SessionState s = SessionState.criar(sid, identidade, Instant.now());
            sessions.put(sid, s);
            latency.record("login_ok", t0);
            OpResult r = OpResult.okLogin(sid);
            emitir(OP_LOGIN, t0, System.nanoTime(), r, identidade);
            return r;
        } catch (RuntimeException e) {
            latency.record("login_err", t0);
            OpResult r = OpResult.errorTransport();
            emitir(OP_LOGIN, t0, System.nanoTime(), r, identidade);
            return r;
        }
    }

    /** O2, validate. */
    public OpResult validate(String sid) {
        long t0 = System.nanoTime();
        try {
            SessionState s = sessions.get(sid);
            latency.record("validate", t0);
            if (s == null) {
                OpResult r = OpResult.notFound();
                emitir(OP_VALIDATE, t0, System.nanoTime(), r, sid);
                return r;
            }

            IdentityState idSt = identities.get(s.identidade());
            if (idSt != null && idSt.status() == IdentityState.Status.BLOCKED
                    && s.estado() == SessionState.Estado.VALID) {
                auditor.registrarViolacao("I2", sid, "valida sob bloqueio");
            }
            OpResult r = OpResult.okValidate(s.estado());
            emitir(OP_VALIDATE, t0, System.nanoTime(), r, sid);
            return r;
        } catch (RuntimeException e) {
            latency.record("validate", t0);
            OpResult r = OpResult.errorTransport();
            emitir(OP_VALIDATE, t0, System.nanoTime(), r, sid);
            return r;
        }
    }

    /** O3, logout. Idempotente. */
    public OpResult logout(String sid) {
        long t0 = System.nanoTime();
        try {
            SessionState s = sessions.get(sid);
            if (s == null) {
                latency.record("logout_noop", t0);
                OpResult r = OpResult.notFound();
                emitir(OP_LOGOUT, t0, System.nanoTime(), r, sid);
                return r;
            }
            if (s.estado() == SessionState.Estado.INVALID) {
                latency.record("logout_noop", t0);
                OpResult r = OpResult.okNoop();
                emitir(OP_LOGOUT, t0, System.nanoTime(), r, sid);
                return r;
            }
            SessionState atual = s.invalidar(SessionState.Motivo.LOGOUT, Instant.now());
            sessions.put(sid, atual);
            latency.record("logout_ok", t0);
            OpResult r = OpResult.okNoop();
            emitir(OP_LOGOUT, t0, System.nanoTime(), r, sid);
            return r;
        } catch (RuntimeException e) {
            latency.record("logout_noop", t0);
            OpResult r = OpResult.errorTransport();
            emitir(OP_LOGOUT, t0, System.nanoTime(), r, sid);
            return r;
        }
    }

    /** O4, incrementFailure. */
    public OpResult incrementFailure(String identidade) {
        long t0 = System.nanoTime();
        try {
            IdentityState before = identities.get(identidade);
            if (before == null) {
                before = IdentityState.criar(identidade, Instant.now());
            }
            IdentityState after = before.incrementar(LIMITE_TENTATIVAS, Instant.now());
            identities.put(identidade, after);
            latency.record("inc_failure", t0);

            if (after.contadorFalhas() < before.contadorFalhas()) {
                auditor.registrarViolacao("I3", identidade, "contador regrediu local");
            }
            OpResult r = OpResult.okStatus(after.status());
            emitir(OP_INCREMENT_FAILURE, t0, System.nanoTime(), r, identidade);
            return r;
        } catch (RuntimeException e) {
            latency.record("inc_failure", t0);
            OpResult r = OpResult.errorTransport();
            emitir(OP_INCREMENT_FAILURE, t0, System.nanoTime(), r, identidade);
            return r;
        }
    }

    /** O5, resetFailures. */
    public OpResult resetFailures(String identidade) {
        long t0 = System.nanoTime();
        try {
            IdentityState st = identities.get(identidade);
            if (st == null) {
                latency.record("reset_noop", t0);
                OpResult r = OpResult.notFound();
                emitir(OP_RESET_FAILURES, t0, System.nanoTime(), r, identidade);
                return r;
            }
            identities.put(identidade, st.resetar(Instant.now()));
            latency.record("reset_ok", t0);
            OpResult r = OpResult.okNoop();
            emitir(OP_RESET_FAILURES, t0, System.nanoTime(), r, identidade);
            return r;
        } catch (RuntimeException e) {
            latency.record("reset_noop", t0);
            OpResult r = OpResult.errorTransport();
            emitir(OP_RESET_FAILURES, t0, System.nanoTime(), r, identidade);
            return r;
        }
    }

    /** O6, block. */
    public OpResult block(String identidade) {
        long t0 = System.nanoTime();
        IdentityState st = identities.get(identidade);
        if (st == null) {
            st = IdentityState.criar(identidade, Instant.now());
        }
        identities.put(identidade, st.bloquear(Instant.now()));
        sessions.entrySet().forEach(e -> {
            if (e.getValue().identidade().equals(identidade)
                    && e.getValue().estado() == SessionState.Estado.VALID) {
                sessions.put(e.getKey(),
                        e.getValue().invalidar(SessionState.Motivo.ADMIN_BLOCK, Instant.now()));
            }
        });
        latency.record("block_ok", t0);
        return OpResult.okNoop();
    }

    /** O7, unblock. */
    public OpResult unblock(String identidade) {
        long t0 = System.nanoTime();
        IdentityState st = identities.get(identidade);
        if (st == null) {
            latency.record("unblock_noop", t0);
            return OpResult.notFound();
        }
        identities.put(identidade, st.desbloquear(Instant.now()));
        latency.record("unblock_ok", t0);
        return OpResult.okNoop();
    }
}
