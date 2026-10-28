package br.com.copiloto.app.reader

/**
 * Motor de decisão do lado nativo.
 *
 * O app Flutter tem o mesmo motor em Dart (`EarningsEngine`) para a tela de
 * veredito. Este aqui existe porque o card de sobreposição precisa calcular
 * com o Aceita AI fechado: só o serviço de acessibilidade está vivo.
 * As duas implementações usam as mesmas metas e as mesmas regras de semáforo
 * — se uma mudar, a outra muda junto (ver docs/arquitetura.md).
 */

enum class Grade { GOOD, AVERAGE, BAD }

data class Goals(
    val minPerKm: Double = 1.20,
    val goodPerKm: Double = 2.00,
    val minPerHour: Double = 18.0,
    val goodPerHour: Double = 30.0,
    val costPerKm: Double = 0.75,
    val minRating: Double = 4.6,
    val goodRating: Double = 4.8,
)

data class Verdict(
    val value: Double,
    val km: Double,
    val minutes: Int,
    val perKm: Double,
    val perHour: Double,
    val profit: Double,
    val profitPct: Double,
    val perKmGrade: Grade,
    val perHourGrade: Grade,
    val profitGrade: Grade,
    val overall: Grade,
    val ratingGrade: Grade?,
)

object EarningsEngine {

    fun gradeOf(value: Double, min: Double, good: Double): Grade = when {
        value >= good -> Grade.GOOD
        value >= min -> Grade.AVERAGE
        else -> Grade.BAD
    }

    fun evaluate(offer: ParsedOffer, goals: Goals): Verdict {
        val km = if (offer.totalKm > 0) offer.totalKm else 0.0
        val minutes = if (offer.totalMin > 0) offer.totalMin else 0

        val perKm = if (km > 0) offer.value / km else 0.0
        val perHour = if (minutes > 0) offer.value / (minutes / 60.0) else 0.0

        val profit = offer.value - (km * goals.costPerKm)
        val profitPct = if (offer.value > 0) (profit / offer.value) * 100 else 0.0

        val perKmGrade = gradeOf(perKm, goals.minPerKm, goals.goodPerKm)
        val perHourGrade = gradeOf(perHour, goals.minPerHour, goals.goodPerHour)
        val profitGrade = if (profit <= 0) {
            Grade.BAD
        } else {
            // A margem reaproveita os mesmos limites de R$/km, proporcionais.
            gradeOf(profitPct, 15.0, 30.0)
        }

        val overall = when {
            profit <= 0 -> Grade.BAD
            perKmGrade == Grade.BAD || perHourGrade == Grade.BAD -> Grade.BAD
            perKmGrade == Grade.GOOD && perHourGrade == Grade.GOOD -> Grade.GOOD
            else -> Grade.AVERAGE
        }

        return Verdict(
            value = offer.value,
            km = km,
            minutes = minutes,
            perKm = perKm,
            perHour = perHour,
            profit = profit,
            profitPct = profitPct,
            perKmGrade = perKmGrade,
            perHourGrade = perHourGrade,
            profitGrade = profitGrade,
            overall = overall,
            ratingGrade = offer.rating?.let {
                gradeOf(it, goals.minRating, goals.goodRating)
            },
        )
    }
}
