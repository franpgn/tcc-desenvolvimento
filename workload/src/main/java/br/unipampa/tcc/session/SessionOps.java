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

    private final RemoteCache<String, SessionState> sessions;
    private final RemoteCache<String, IdentityState> identities;
    private final LatencyRegistry latency;
    private final InvariantAuditor auditor;

    public SessionOps(RemoteCacheManager rcm, LatencyRegistry latency, InvariantAuditor auditor) {
        this.sessions = rcm.getCache("sessions");
        this.identities = rcm.getCache("counters");
        this.latency = latency;
        this.auditor = auditor;
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
                return OpResult.blocked();
            }
            String sid = UUID.randomUUID().toString();
            SessionState s = SessionState.criar(sid, identidade, Instant.now());
            sessions.put(sid, s);
            latency.record("login_ok", t0);
            return OpResult.okLogin(sid);
        } catch (RuntimeException e) {
            latency.record("login_err", t0);
            return OpResult.errorTransport();
        }
    }

    /** O2, validate. */
    public OpResult validate(String sid) {
        long t0 = System.nanoTime();
        SessionState s = sessions.get(sid);
        latency.record("validate", t0);
        if (s == null) return OpResult.notFound();

        IdentityState idSt = identities.get(s.identidade());
        if (idSt != null && idSt.status() == IdentityState.Status.BLOCKED
                && s.estado() == SessionState.Estado.VALID) {
            auditor.registrarViolacao("I2", sid, "valida sob bloqueio");
        }
        return OpResult.okValidate(s.estado());
    }

    /** O3, logout. Idempotente. */
    public OpResult logout(String sid) {
        long t0 = System.nanoTime();
        SessionState s = sessions.get(sid);
        if (s == null) {
            latency.record("logout_noop", t0);
            return OpResult.notFound();
        }
        if (s.estado() == SessionState.Estado.INVALID) {
            latency.record("logout_noop", t0);
            return OpResult.okNoop();
        }
        SessionState atual = s.invalidar(SessionState.Motivo.LOGOUT, Instant.now());
        sessions.put(sid, atual);
        latency.record("logout_ok", t0);
        return OpResult.okNoop();
    }

    /** O4, incrementFailure. */
    public OpResult incrementFailure(String identidade) {
        long t0 = System.nanoTime();
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
        return OpResult.okStatus(after.status());
    }

    /** O5, resetFailures. */
    public OpResult resetFailures(String identidade) {
        long t0 = System.nanoTime();
        IdentityState st = identities.get(identidade);
        if (st == null) {
            latency.record("reset_noop", t0);
            return OpResult.notFound();
        }
        identities.put(identidade, st.resetar(Instant.now()));
        latency.record("reset_ok", t0);
        return OpResult.okNoop();
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
