package br.com.aceitaai.app.reader

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

    @Test
    fun `ocr com contador de ganhos no topo escolhe o valor da oferta`() {
        // O OCR lê a tela inteira: o topo do Uber traz "-R$ 628,82" (ganhos
        // do dia) muito acima do card. O valor certo é o que está colado nos
        // km/min — 7,15, não 628,82.
        val offer = OfferParser.parse(
            "com.ubercab.driver",
            nodes(
                "22:08",
                "-R$ 628,82",
                "Upper Gran Park",
                "R$ 7,15",
                "Est. de R$3,40/km",
                "4 min • 0.9 km",
                "5 minutos • 1.2 km",
                "Tenho interesse",
            ),
        )!!
        assertEquals(7.15, offer.value, 0.001)
        assertEquals(2.1, offer.totalKm, 0.001)
    }

    @Test
    fun `rotulo de preco por km em linha separada nao vira valor`() {
        // Layout de coluna: o rótulo "R$/km" fica numa linha e o número na
        // seguinte. O número sozinho não é o valor da corrida.
        val offer = OfferParser.parse(
            "com.ubercab.driver",
            nodes(
                "R$/km",
                "R$ 3,40",
                "R$/h",
                "R$ 47",
                "4 min • 0.9 km",
                "5 min • 1.2 km",
                "R$ 7,15",
            ),
        )!!
        assertEquals(7.15, offer.value, 0.001)
    }

    @Test
    fun `ocr que troca 1 por l ainda le a viagem`() {
        // Texto real do OCR na foto da oferta: "5 minutos•l.2 km".
        val offer = OfferParser.parse(
            "com.ubercab.driver",
            nodes(
                "2 UberX",
                "27 de out. >",
                "R$ 7,15",
                "Est. de R$3,40/km",
                "4 min 0.9 km",
                "+10% de ganhos Uber Pro",
                "* 4,95 (1643)",
                "5 minutos•l.2 km",
                "Tenho interesse",
            ),
        )!!
        assertEquals(7.15, offer.value, 0.001)
        assertEquals(0.9, offer.pickupKm!!, 0.001)
        assertEquals(1.2, offer.tripKm!!, 0.001)
        assertEquals(2.1, offer.totalKm, 0.001)
        assertEquals(9, offer.totalMin)
    }

    @Test
    fun `ocr com km e minuto em linhas separadas ainda forma o trecho`() {
        val offer = OfferParser.parse(
            "com.ubercab.driver",
            nodes("R$ 9,80", "4 min", "0.9 km", "6 min", "1.2 km"),
        )!!
        assertEquals(9.80, offer.value, 0.001)
        assertEquals(2.1, offer.totalKm, 0.001)
        assertEquals(10, offer.totalMin)
    }

    @Test
    fun `tela em corrida com saldo do dia no topo nao vira oferta`() {
        val inTrip = OfferParser.parse(
            "com.ubercab.driver",
            nodes(
                "R$ 184,50",
                "A caminho do passageiro",
                "12 min • 4,5 km",
            ),
        )
        assertNull(inTrip)

        val labeledBalance = OfferParser.parse(
            "com.ubercab.driver",
            nodes(
                "Hoje",
                "R$ 184,50",
                "12 min • 4,5 km",
            ),
        )
        assertNull(labeledBalance)

        val farHeaderValue = OfferParser.parse(
            "com.ubercab.driver",
            nodes(
                "R$ 184,50",
                "Linha 1",
                "Linha 2",
                "Linha 3",
                "Linha 4",
                "Linha 5",
                "Linha 6",
                "12 min • 4,5 km",
            ),
        )
        assertNull(farHeaderValue)

        // 99 em corrida ("Deslize para chegar" / "Embarque"):
        val inTrip99 = OfferParser.parse(
            "com.app99.driver",
            nodes(
                "R$ 210,40",
                "Embarque em 3 min (0,8 km)",
                "Deslize para chegar",
            ),
        )
        assertNull(inTrip99)

        // inDrive em corrida ("Cheguei"):
        val inTripInDrive = OfferParser.parse(
            "sinet.startup.inDriver",
            nodes(
                "R$ 25,00",
                "7 min • 2,4 km",
                "Cheguei",
                "Cancelar corrida",
            ),
        )
        assertNull(inTripInDrive)

        // Resumo de fim de viagem / recibo ("Viagem concluída" / "Você ganhou R$"):
        val tripSummary = OfferParser.parse(
            "com.ubercab.driver",
            nodes(
                "Viagem concluída",
                "Você ganhou R$ 18,90",
                "Duração: 14 min • Distância: 5,2 km",
                "Avalie o passageiro",
            ),
        )
        assertNull(tripSummary)
    }

    @Test
    fun `oferta real tocando durante viagem e lida normalmente`() {
        // Com botão "Aceitar" e 2 trechos durante corrida em andamento:
        val withAccept = OfferParser.parse(
            "com.ubercab.driver",
            nodes(
                "Hoje R$ 184,50",
                "A caminho do passageiro",
                "R$ 14,50",
                "3 min (1,2 km) de distância",
                "Viagem de 11 min (5,0 km)",
                "Aceitar",
            ),
        )
        assertNotNull(withAccept)
        assertEquals(14.50, withAccept!!.value, 0.001)
        assertEquals(6.2, withAccept.totalKm, 0.001)
        assertEquals(14, withAccept.totalMin)

        // Com "Est. de R$..." durante viagem:
        val withEst = OfferParser.parse(
            "com.ubercab.driver",
            nodes(
                "Finalizar viagem",
                "R$ 11,20",
                "Est. de R$2,80/km",
                "10 min • 4,0 km",
            ),
        )
        assertNotNull(withEst)
        assertEquals(11.20, withEst!!.value, 0.001)

        // Com 2 trechos (busca + viagem) durante viagem:
        val withTwoSegments = OfferParser.parse(
            "com.ubercab.driver",
            nodes(
                "A caminho do destino",
                "R$ 12,00",
                "3 min • 1,0 km",
                "9 min • 4,0 km",
            ),
        )
        assertNotNull(withTwoSegments)
        assertEquals(12.00, withTwoSegments!!.value, 0.001)
        assertEquals(5.0, withTwoSegments.totalKm, 0.001)
        assertEquals(12, withTwoSegments.totalMin)
    }

    @Test
    fun `reconhece ambos os pacotes do inDrive`() {
        val offerInDrive = OfferParser.parse(
            "sinet.startup.inDrive",
            nodes("R$ 18,00", "4 min • 1,5 km", "14 min • 7,5 km"),
        )
        assertNotNull(offerInDrive)
        assertEquals("indrive", offerInDrive!!.appId)
        assertEquals(18.00, offerInDrive.value, 0.001)

        val offerInDriver = OfferParser.parse(
            "sinet.startup.inDriver",
            nodes("R$ 18,00", "4 min • 1,5 km", "14 min • 7,5 km"),
        )
        assertNotNull(offerInDriver)
        assertEquals("indrive", offerInDriver!!.appId)
    }
}
