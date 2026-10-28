package br.com.aceitaai.app.reader

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * A aceitação é deduzida da tela seguinte: estas frases são o contrato com o
 * app de corrida. Se o Uber/99/inDrive mudarem o texto, é aqui que quebra.
 */
class AcceptanceParserTest {

    @Test
    fun `tela da viagem e aceite`() {
        assertEquals(
            Acceptance.accepted,
            AcceptanceParser.detect(listOf("A caminho do passageiro", "4 min · 1,2 km")),
        )
        assertEquals(
            Acceptance.accepted,
            AcceptanceParser.detect(listOf("Deslize para iniciar a viagem")),
        )
        assertEquals(
            Acceptance.accepted,
            AcceptanceParser.detect(listOf("Finalizar viagem")),
        )
        assertEquals(
            Acceptance.accepted,
            AcceptanceParser.detect(listOf("Você chegou", "Aguardando o passageiro")),
        )
    }

    @Test
    fun `mapa de espera e recusa`() {
        assertEquals(
            Acceptance.declined,
            AcceptanceParser.detect(listOf("Procurando viagens", "Você está online")),
        )
        assertEquals(
            Acceptance.declined,
            AcceptanceParser.detect(listOf("Aguardando solicitações")),
        )
    }

    @Test
    fun `acento e caixa nao importam`() {
        assertEquals(
            Acceptance.accepted,
            AcceptanceParser.detect(listOf("A CAMINHO DO PASSAGEIRO")),
        )
        // OCR come acento com frequência.
        assertEquals(
            Acceptance.accepted,
            AcceptanceParser.detect(listOf("A caminho do passageiro")),
        )
        assertEquals(
            Acceptance.declined,
            AcceptanceParser.detect(listOf("Aguardando solicitacoes")),
        )
    }

    @Test
    fun `tela sem resposta devolve null`() {
        assertNull(AcceptanceParser.detect(emptyList()))
        assertNull(AcceptanceParser.detect(listOf("R\$ 17,04", "24 min · 13,2 km")))
    }

    @Test
    fun `aceite ganha da recusa quando as duas frases aparecem`() {
        // O topo do mapa pode continuar atrás da tela da viagem.
        assertEquals(
            Acceptance.accepted,
            AcceptanceParser.detect(listOf("Procurando viagens", "Iniciar viagem")),
        )
    }

    @Test
    fun `card na tela protege contra recusa falsa`() {
        // O card da oferta fica por cima do mapa: "Procurando viagens" está
        // atrás dele e não significa que o motorista recusou.
        val lines = listOf("Procurando viagens", "R\$ 17,04", "24 min · 13,2 km")
        assertTrue(AcceptanceParser.offerVisible(lines, 17.04))
        // OCR pode ler ponto no lugar da vírgula.
        assertTrue(AcceptanceParser.offerVisible(listOf("R\$ 17.04"), 17.04))
        assertFalse(AcceptanceParser.offerVisible(listOf("R\$ 628,82"), 17.04))
    }
}
