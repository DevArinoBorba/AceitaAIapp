package br.com.aceitaai.app.reader

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Contrato do histórico: o serviço grava, o Flutter lê.
 *
 * Se este formato mudar sem o `Offer.fromJson`/`Goals.fromJson` do Dart mudar
 * junto, a oferta lida na rua some do histórico — por isso o teste fixa os
 * nomes dos campos.
 */
class OfferHistoryTest {

    private fun offer(value: Double = 17.04, km: Double = 13.2, min: Int = 24) =
        ParsedOffer(
            appId = "uber",
            value = value,
            totalKm = km,
            totalMin = min,
            pickupKm = 5.4,
            pickupMin = 8,
            tripKm = 7.8,
            tripMin = 16,
            uberPerKm = 1.29,
            rating = 4.95,
        )

    @Test
    fun `assinatura muda quando e outra corrida`() {
        assertEquals(OfferHistory.signatureOf(offer()), OfferHistory.signatureOf(offer()))
        assertNotEquals(
            OfferHistory.signatureOf(offer()),
            OfferHistory.signatureOf(offer(value = 17.05)),
        )
    }

    @Test
    fun `data vai em ISO sem fuso`() {
        val iso = OfferHistory.iso(1_772_000_000_000)
        assertTrue("formato: $iso", Regex("""\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}""").matches(iso))
    }

    @Test
    fun `entrada tem os campos que o Dart le`() {
        val goals = JSONObject().put("minPerKm", 1.45).put("goodPerKm", 2.2)
        val entry = OfferHistory.entryOf(offer(), goals, 1_772_000_000_000)

        val offerJson = entry.getJSONObject("offer")
        assertEquals("uber", offerJson.getString("appId"))
        assertEquals(17.04, offerJson.getDouble("value"), 0.001)
        assertEquals(13.2, offerJson.getDouble("distanceKm"), 0.001)
        assertEquals(24, offerJson.getInt("timeMin"))
        assertEquals(4.95, offerJson.getDouble("passengerRating"), 0.001)
        assertTrue(offerJson.has("label"))
        assertTrue(offerJson.getString("createdAt").startsWith("2026-"))

        assertEquals(1.45, entry.getJSONObject("goals").getDouble("minPerKm"), 0.001)
    }

    @Test
    fun `oferta sem nota grava null e nao zero`() {
        val entry = OfferHistory.entryOf(
            offer().copy(rating = null),
            JSONObject(),
            1_772_000_000_000,
        )
        assertTrue(entry.getJSONObject("offer").isNull("passengerRating"))
    }

    @Test
    fun `aceite marca a oferta mais recente`() {
        val history = org.json.JSONArray()
            .put(OfferHistory.entryOf(offer(), JSONObject(), 1_772_000_000_000))
            .put(OfferHistory.entryOf(offer(value = 9.9), JSONObject(), 1_771_000_000_000))

        val marked = OfferHistory.markIn(
            history.toString(),
            OfferHistory.signatureOf(offer()),
            accepted = true,
        )

        val parsed = org.json.JSONArray(marked)
        assertTrue(parsed.getJSONObject(0).getBoolean("accepted"))
        assertEquals(2, parsed.length())
        // A antiga não ganha o campo.
        assertFalse(parsed.getJSONObject(1).has("accepted"))
    }

    @Test
    fun `aceite nao marca a oferta errada`() {
        val history = org.json.JSONArray()
            .put(OfferHistory.entryOf(offer(), JSONObject(), 1_772_000_000_000))

        assertNull(
            OfferHistory.markIn(
                history.toString(),
                OfferHistory.signatureOf(offer(value = 9.9)),
                accepted = true,
            ),
        )
    }

    @Test
    fun `assinatura de entrada gravada bate com a da oferta`() {
        val entry = OfferHistory.entryOf(offer(), JSONObject(), 1_772_000_000_000)
        assertEquals(OfferHistory.signatureOf(offer()), OfferHistory.signatureOf(entry))
    }

    @Test
    fun `fallback de goalsJson inclui metas de margem de lucro`() {
        val goals = Goals(
            minPerKm = 1.35,
            goodPerKm = 2.10,
            minPerHour = 20.0,
            goodPerHour = 32.0,
            minProfitPct = 18.0,
            goodProfitPct = 35.0,
            costPerKm = 0.80,
            minRating = 4.65,
            goodRating = 4.85,
        )
        val json = OfferHistory.goalsJson(null, goals)

        assertEquals(1.35, json.getDouble("minPerKm"), 0.001)
        assertEquals(2.10, json.getDouble("goodPerKm"), 0.001)
        assertEquals(20.0, json.getDouble("minPerHour"), 0.001)
        assertEquals(32.0, json.getDouble("goodPerHour"), 0.001)
        assertEquals(18.0, json.getDouble("minProfitPct"), 0.001)
        assertEquals(35.0, json.getDouble("goodProfitPct"), 0.001)
        assertEquals(0.80, json.getDouble("costPerKm"), 0.001)
        assertEquals(4.65, json.getDouble("minRating"), 0.001)
        assertEquals(4.85, json.getDouble("goodRating"), 0.001)
    }
}
