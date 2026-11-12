package br.com.aceitaai.app.reader

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Contrato do motor de cálculo nativo.
 *
 * Espelha `test/engine_parity_test.dart` (Dart): os mesmos casos e os mesmos
 * resultados esperados. Se um lado mudar, o outro tem que mudar junto — é o
 * que impede a tela do app e o card flutuante de darem respostas diferentes
 * para a mesma oferta.
 */
class EarningsEngineTest {

    @Test
    fun `custo de aluguel recebido do app usa o mesmo lucro`() {
        // Dart calcula 0,60 + (600 + 150 + 30 + 20) / 1000 = 1,40/km.
        val v = EarningsEngine.evaluate(
            offer(value = 20.0, km = 10.0, min = 20),
            Goals(costPerKm = 1.4),
        )
        assertEquals(6.0, v.profit, 1e-12)
        assertEquals(30.0, v.profitPct, 1e-12)
        assertEquals(Grade.GOOD, v.overall)
    }

    private fun offer(
        value: Double = 20.0,
        km: Double = 8.0,
        min: Int = 20,
        rating: Double? = null,
    ) = ParsedOffer(
        appId = "uber",
        value = value,
        totalKm = km,
        totalMin = min,
        rating = rating,
    )

    @Test
    fun `centavos fecham com a conta do app`() {
        val v = EarningsEngine.evaluate(offer(value = 7.15, km = 2.1, min = 9), Goals())

        assertEquals(3.4047619047619047, v.perKm, 1e-12)
        assertEquals(47.666666666666664, v.perHour, 1e-12)
        assertEquals(0.7944444444444444, v.perMin, 1e-12)
        assertEquals(5.575, v.profit, 1e-12)
        assertEquals(77.97202797202797, v.profitPct, 1e-12)

        assertEquals(Grade.GOOD, v.perKmGrade)
        assertEquals(Grade.GOOD, v.perHourGrade)
        assertEquals(Grade.GOOD, v.profitGrade)
        assertEquals(Grade.GOOD, v.overall)
    }

    @Test
    fun `distancia zero nao divide por zero e o veredito e ruim`() {
        val v = EarningsEngine.evaluate(offer(value = 10.0, km = 0.0, min = 10), Goals())

        assertEquals(0.0, v.perKm, 1e-12)
        assertEquals(60.0, v.perHour, 1e-12)
        assertEquals(10.0, v.profit, 1e-12)
        assertEquals(100.0, v.profitPct, 1e-12)

        assertEquals(Grade.BAD, v.perKmGrade)
        assertEquals(Grade.BAD, v.overall)
    }

    @Test
    fun `minutos zero nao divide por zero e o veredito e ruim`() {
        val v = EarningsEngine.evaluate(offer(value = 12.0, km = 5.0, min = 0), Goals())

        assertEquals(0.0, v.perHour, 1e-12)
        assertEquals(0.0, v.perMin, 1e-12)
        assertEquals(2.4, v.perKm, 1e-12)

        assertEquals(Grade.BAD, v.perHourGrade)
        assertEquals(Grade.BAD, v.overall)
    }

    @Test
    fun `valor zero da margem zero sem NaN`() {
        val v = EarningsEngine.evaluate(offer(value = 0.0, km = 5.0, min = 10), Goals())

        assertEquals(0.0, v.profitPct, 1e-12)
        assertEquals(-3.75, v.profit, 1e-12)
        assertEquals(Grade.BAD, v.overall)
    }

    @Test
    fun `custo zero deixa o lucro igual ao valor`() {
        val v = EarningsEngine.evaluate(
            offer(value = 10.0, km = 10.0, min = 10),
            Goals(costPerKm = 0.0),
        )

        assertEquals(10.0, v.profit, 1e-12)
        assertEquals(100.0, v.profitPct, 1e-12)
        assertEquals(Grade.BAD, v.perKmGrade) // 1,00 < 1,20 mínima
        assertEquals(Grade.BAD, v.overall)
    }

    @Test
    fun `margem negativa e sempre ruim`() {
        val v = EarningsEngine.evaluate(offer(value = 3.0, km = 10.0, min = 10), Goals())

        assertEquals(-4.5, v.profit, 1e-12)
        assertEquals(-150.0, v.profitPct, 1e-12)
        assertEquals(Grade.BAD, v.perKmGrade)
        assertEquals(Grade.BAD, v.profitGrade)
        assertEquals(Grade.BAD, v.overall)
    }

    @Test
    fun `limiar exato de reais por km e media`() {
        // Era o bug D1: com Float, 1,20 virava 1.2000000476 e caía para ruim.
        val v = EarningsEngine.evaluate(offer(value = 12.0, km = 10.0, min = 10), Goals())

        assertEquals(1.2, v.perKm, 1e-12)
        assertEquals(Grade.AVERAGE, v.perKmGrade)
    }

    @Test
    fun `limiar exato de reais por hora e media`() {
        val v = EarningsEngine.evaluate(offer(value = 3.0, km = 10.0, min = 10), Goals())

        assertEquals(18.0, v.perHour, 1e-12)
        assertEquals(Grade.AVERAGE, v.perHourGrade)
    }

    @Test
    fun `nota 4,80 exata e boa`() {
        // Era o bug D2: goodRating como Float derrubava 4,80 para média.
        val v = EarningsEngine.evaluate(offer(rating = 4.8), Goals())

        assertEquals(Grade.GOOD, v.ratingGrade)
    }

    @Test
    fun `nota 4,60 exata e media`() {
        val v = EarningsEngine.evaluate(offer(rating = 4.6), Goals())

        assertEquals(Grade.AVERAGE, v.ratingGrade)
    }

    @Test
    fun `metas de margem do motorista sao respeitadas`() {
        // Era o bug D3: o nativo usava 15/30 fixos e ignorava os ajustes.
        val v = EarningsEngine.evaluate(
            offer(value = 10.0, km = 10.0, min = 30),
            Goals(minProfitPct = 30.0, goodProfitPct = 50.0),
        )

        assertEquals(25.0, v.profitPct, 1e-12)
        assertEquals(Grade.BAD, v.profitGrade)
        assertEquals(Grade.BAD, v.overall)
    }

    @Test
    fun `veredito geral considera a margem`() {
        // Era o bug D4: perKm e perHour bons escondiam a margem média.
        val v = EarningsEngine.evaluate(
            offer(value = 10.0, km = 5.0, min = 10),
            Goals(costPerKm = 1.6),
        )

        assertEquals(20.0, v.profitPct, 1e-12)
        assertEquals(Grade.GOOD, v.perKmGrade)
        assertEquals(Grade.GOOD, v.perHourGrade)
        assertEquals(Grade.AVERAGE, v.profitGrade)
        assertEquals(Grade.AVERAGE, v.overall)
    }
}
