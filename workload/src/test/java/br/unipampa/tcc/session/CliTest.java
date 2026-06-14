package br.unipampa.tcc.session;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import picocli.CommandLine;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Testes para {@link Cli} cobrindo defaults, parse de opções nominais
 * e validação de parâmetros inválidos.
 */
class CliTest {

    private static Cli parse(String... args) {
        Cli c = new Cli();
        new CommandLine(c).parseArgs(args);
        return c;
    }

    @Test
    @DisplayName("Defaults seguem a Tabela 1 (T9=10^6, T10=30, T11=60s, T14=600s)")
    void defaultsConfirmadosPelaTabela1() {
        Cli c = parse();
        assertEquals(Scenario.S1, c.scenario);
        assertEquals(600L, c.duracaoSeg);
        assertEquals(1_000_000L, c.ops);
        assertEquals(30, c.repeticoes);
        assertEquals(8, c.threads);
        assertEquals(60L, c.warmupMinimoSeg);
        assertEquals(42L, c.seedBase);
        assertFalse(c.dryRun);
    }

    @Test
    @DisplayName("Opcoes longas e curtas escolhem o cenario")
    void escolhaDeCenario() {
        assertEquals(Scenario.S2, parse("--scenario", "S2").scenario);
        assertEquals(Scenario.S2, parse("-s", "S2").scenario);
        assertEquals(Scenario.S1, parse("-s", "S1").scenario);
    }

    @Test
    @DisplayName("Opcao --servers aceita lista host:port,host:port")
    void parseServers() {
        Cli c = parse("--servers", "a:1,b:2,c:3");
        assertEquals("a:1,b:2,c:3", c.servidores);
    }

    @Test
    @DisplayName("Opcoes numericas aceitam tamanhos da Tabela 1")
    void parseNumericos() {
        Cli c = parse("--duration", "1800", "--ops", "10000000",
                      "--rep", "5", "--threads", "16", "--seed", "12345");
        assertEquals(1800L, c.duracaoSeg);
        assertEquals(10_000_000L, c.ops);
        assertEquals(5, c.repeticoes);
        assertEquals(16, c.threads);
        assertEquals(12345L, c.seedBase);
    }

    @Test
    @DisplayName("--dry-run liga o flag boolean")
    void flagDryRun() {
        assertTrue(parse("--dry-run").dryRun);
    }

    @Test
    @DisplayName("--csv-dir captura o caminho")
    void parseCsvDir() {
        Cli c = parse("--csv-dir", "/tmp/saida");
        assertEquals("/tmp/saida", c.csvDir);
    }

    @Test
    @DisplayName("validar rejeita parametros invalidos")
    void validacaoRejeitaInvalidos() {
        Cli c = parse("--duration", "0");
        assertThrows(IllegalArgumentException.class, c::validar);

        Cli c2 = parse("--rep", "0");
        assertThrows(IllegalArgumentException.class, c2::validar);

        Cli c3 = parse("--threads", "-1");
        assertThrows(IllegalArgumentException.class, c3::validar);

        Cli c4 = parse("--servers", "");
        assertThrows(IllegalArgumentException.class, c4::validar);
    }

    @Test
    @DisplayName("validar aceita parametros validos")
    void validacaoAceitaPadroes() {
        parse().validar();
        parse("--duration", "60", "--rep", "1", "--threads", "1",
              "--ops", "0", "--warmup-min-sec", "0").validar();
    }

    @Test
    @DisplayName("toString não expoe senha")
    void toStringNaoExpoeSenha() {
        Cli c = parse("--password", "secreta-123");
        assertFalse(c.toString().contains("secreta-123"),
            "toString nao deveria conter a senha");
    }
}
