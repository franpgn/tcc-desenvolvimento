package br.unipampa.tcc.session;

import java.time.Instant;
import java.util.concurrent.ConcurrentLinkedQueue;

/**
 * Registra violações de invariantes detectadas durante a execução do workload
 * ou pela auditoria periódica das réplicas.
 *
 * Invariantes monitorados:
 *  I1, irreversibilidade da invalidação após logout.
 *  I2, consistência de bloqueio.
 *  I3, monotonicidade local do contador de tentativas.
 *  I4, unicidade do motivo de invalidação.
 *  I5, convergência do estado lógico (sob quiescência).
 *  I6, convergência do contador (sob quiescência).
 */
public class InvariantAuditor {

    public record Violacao(Instant em, String invariante, String chave, String mensagem) {}

    private final ConcurrentLinkedQueue<Violacao> registros = new ConcurrentLinkedQueue<>();

    public void registrarViolacao(String invariante, String chave, String mensagem) {
        registros.add(new Violacao(Instant.now(), invariante, chave, mensagem));
    }

    public int total() { return registros.size(); }

    public java.util.List<Violacao> drenar() {
        java.util.List<Violacao> out = new java.util.ArrayList<>(registros);
        registros.clear();
        return out;
    }
}
