package br.com.copiloto.app.reader

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * O parser é validado contra textos reais de tela.
 *
 * O caso principal é a oferta de radar do Uber, copiada do dump de
 * 27/10/2026 (prints + `dumps.jsonl`): "R$ 7,15", busca de 4 min / 0,9 km e
 * viagem de 5 min / 1,2 km. O próprio Uber imprime "Est. de R$3,40/km", e
 * 7,15 ÷ (0,9 + 1,2) = 3,40 — ou seja, a conta do app tem que fechar com a
 * do Uber. É esse número que o teste protege.
 */
class OfferParserTest {

    private fun nodes(vararg lines: String) =
        lines.map { mapOf("text" to it, "id" to "", "cls" to "android.widget.TextView") }

    private val radarOffer = nodes(
        "UberX",
        "R$ 7,15",
        "Est. de R$3,40/km",
        "+10% de ganhos Uber Pro",
        "4 min • 0.9 km",
        "R. Barão do Rio Branco, 1234",
        "Centro",
        "4,95 (1643)",
        "Verificado",
        "5 minutos • 1.2 km",
        "Av. Afonso Pena, 567",
        "Tenho interesse",
    )

    @Test
    fun `le a oferta de radar e soma busca mais viagem`() {
        val offer = OfferParser.parse("com.ubercab.driver", radarOffer)
        assertNotNull(offer)
        offer!!

        assertEquals("uber", offer.appId)
        assertEquals(7.15, offer.value, 0.001)
        assertEquals(0.9, offer.pickupKm!!, 0.001)
        assertEquals(4, offer.pickupMin)
        assertEquals(1.2, offer.tripKm!!, 0.001)
        assertEquals(5, offer.tripMin)
        assertEquals(2.1, offer.totalKm, 0.001)
        assertEquals(9, offer.totalMin)
        assertEquals(3.40, offer.uberPerKm!!, 0.001)
        assertEquals(4.95, offer.rating!!, 0.001)
    }

    @Test
    fun `a conta fecha com a estimativa do proprio Uber`() {
        val offer = OfferParser.parse("com.ubercab.driver", radarOffer)!!
        val verdict = EarningsEngine.evaluate(offer, Goals())

        // 7,15 / 2,1 km = 3,4047...
        assertEquals(3.4047, verdict.perKm, 0.001)
        // 7,15 / (9/60) = 47,66/h
        assertEquals(47.66, verdict.perHour, 0.05)
        assertEquals(Grade.GOOD, verdict.perKmGrade)
        assertEquals(Grade.GOOD, verdict.overall)
    }

    @Test
    fun `le solicitacao normal com distancia em parenteses`() {
        val offer = OfferParser.parse(
            "com.ubercab.driver",
            nodes(
                "Nova solicitação",
                "R$ 12,34",
                "3 min (1,2 km) de distância",
                "Viagem de 12 min (5,4 km)",
                "Aceitar",
            ),
        )
        assertNotNull(offer)
        assertEquals(12.34, offer!!.value, 0.001)
        assertEquals(6.6, offer.totalKm, 0.001)
        assertEquals(15, offer.totalMin)
    }

    @Test
    fun `valor quebrado em dois nos e remontado`() {
        val offer = OfferParser.parse(
            "com.ubercab.driver",
            nodes("R$", "7,15", "4 min • 0.9 km", "5 min • 1.2 km"),
        )
        assertNotNull(offer)
        assertEquals(7.15, offer!!.value, 0.001)
    }

    @Test
    fun `tela inicial com bonus no mapa nao vira oferta`() {
        val offer = OfferParser.parse(
            "com.ubercab.driver",
            nodes(
                "Alta demanda aqui!",
                "+R$ 7,25",
                "+R$ 5",
                "1-3 min",
                "Oportunidades",
                "Ficar online",
            ),
        )
        assertNull(offer)
    }

    @Test
    fun `conversa de whatsapp nao vira oferta`() {
        val offer = OfferParser.parse(
            "com.whatsapp",
            nodes("R$ 20 cada", "chego em 4 min", "Av. Afonso Pena, 567"),
        )
        assertNull(offer)
    }

    @Test
    fun `oferta ruim e recusada`() {
        val offer = OfferParser.parse(
            "com.app99.driver",
            nodes("R$ 6,00", "8 min (6,0 km) de distância", "Viagem de 15 min (9,0 km)"),
        )!!
        val verdict = EarningsEngine.evaluate(offer, Goals())

        assertEquals("99", offer.appId)
        assertEquals(15.0, offer.totalKm, 0.001)
        // 6,00 / 15 km = 0,40/km
        assertEquals(0.40, verdict.perKm, 0.001)
        assertEquals(Grade.BAD, verdict.overall)
    }
}
