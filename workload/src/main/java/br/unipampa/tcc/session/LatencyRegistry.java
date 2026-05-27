package br.unipampa.tcc.session;

import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentLinkedQueue;

/**
 * Coleta latências por nome de operação em filas concorrentes,
 * para análise posterior por percentil (p50, p95, p99, p99.9).
 */
public class LatencyRegistry {

    private final ConcurrentHashMap<String, ConcurrentLinkedQueue<Long>> samples =
            new ConcurrentHashMap<>();

    public void record(String op, long startNs) {
        long deltaNs = System.nanoTime() - startNs;
        samples.computeIfAbsent(op, k -> new ConcurrentLinkedQueue<>()).add(deltaNs);
    }

    /** Exporta o estado atual como mapa op -> array de amostras (ns). */
    public java.util.Map<String, long[]> snapshot() {
        java.util.Map<String, long[]> out = new java.util.HashMap<>();
        samples.forEach((k, q) -> {
            long[] arr = q.stream().mapToLong(Long::longValue).toArray();
            out.put(k, arr);
        });
        return out;
    }
}
