package br.unipampa.tcc.session;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Instant;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Supplier;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class InvariantAuditorTest {

    @Test
    void registrarViolacaoAcumula() {
        InvariantAuditor a = new InvariantAuditor();
        a.registrarViolacao("I1", "sid-1", "logout revertido");
        a.registrarViolacao("I3", "user-2", "contador regrediu");
        assertEquals(2, a.total());
        List<InvariantAuditor.Violacao> drenadas = a.drenar();
        assertEquals(2, drenadas.size());
        assertEquals(0, a.total());
    }

    @Test
    void rodadaUnicaDetectaI5_divergenciaDeEstado() {
        InvariantAuditor a = new InvariantAuditor();
        Instant t = Instant.now();
        SessionState valida = SessionState.criar("sid-1", "alice", t);
        SessionState invalida = valida.invalidar(SessionState.Motivo.LOGOUT, t);

        Map<String, SessionState> replicaA = new HashMap<>();
        Map<String, SessionState> replicaB = new HashMap<>();
        replicaA.put("sid-1", valida);
        replicaB.put("sid-1", invalida);

        Supplier<Map<String, SessionState>> sa = () -> replicaA;
        Supplier<Map<String, SessionState>> sb = () -> replicaB;
        a.rodadaUnica(List.of(sa, sb), List.of());

        assertEquals(1, a.total());
        InvariantAuditor.Violacao v = a.drenar().get(0);
        assertEquals("I5", v.invariante());
        assertEquals("sid-1", v.chave());
    }

    @Test
    void rodadaUnicaDetectaI6_divergenciaDeContador() {
        InvariantAuditor a = new InvariantAuditor();
        Instant t = Instant.now();
        IdentityState comUm = IdentityState.criar("bob", t).incrementar(5, t);
        IdentityState comZero = IdentityState.criar("bob", t);

        Map<String, IdentityState> replicaA = new HashMap<>();
        Map<String, IdentityState> replicaB = new HashMap<>();
        replicaA.put("bob", comUm);
        replicaB.put("bob", comZero);

        a.rodadaUnica(List.of(),
            List.of(() -> replicaA, () -> replicaB));

        assertEquals(1, a.total());
        InvariantAuditor.Violacao v = a.drenar().get(0);
        assertEquals("I6", v.invariante());
        assertEquals("bob", v.chave());
    }

    @Test
    void rodadaUnicaSemDivergenciaNaoRegistra() {
        InvariantAuditor a = new InvariantAuditor();
        Instant t = Instant.now();
        SessionState s = SessionState.criar("sid-1", "alice", t);
        IdentityState i = IdentityState.criar("alice", t);

        Map<String, SessionState> replicaA = Map.of("sid-1", s);
        Map<String, SessionState> replicaB = Map.of("sid-1", s);
        Map<String, IdentityState> idA = Map.of("alice", i);
        Map<String, IdentityState> idB = Map.of("alice", i);

        a.rodadaUnica(List.of(() -> replicaA, () -> replicaB),
                      List.of(() -> idA, () -> idB));

        assertEquals(0, a.total());
    }

    @Test
    void dumpCsvProduzCabecalhoELinhas(@TempDir Path tmp) throws IOException {
        InvariantAuditor a = new InvariantAuditor();
        a.registrarViolacao("I1", "sid-1", "logout revertido");
        a.registrarViolacao("I5", "sid-2", "divergencia, com virgula");
        Path csv = tmp.resolve("violations.csv");
        a.dumpCsv(csv);
        List<String> linhas = Files.readAllLines(csv);
        assertEquals(3, linhas.size());
        assertEquals("instante,invariante,chave,mensagem", linhas.get(0));
        assertTrue(linhas.get(1).contains(",I1,sid-1,logout revertido"));
        assertTrue(linhas.get(2).contains("\"divergencia, com virgula\""));
    }
}
