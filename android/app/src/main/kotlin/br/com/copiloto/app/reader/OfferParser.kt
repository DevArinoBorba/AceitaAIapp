package br.com.copiloto.app.reader

/** Oferta extraída da tela, ainda sem veredito. */
data class ParsedOffer(
    val appId: String,
    val value: Double,
    val totalKm: Double,
    val totalMin: Int,
    val pickupKm: Double? = null,
    val pickupMin: Int? = null,
    val tripKm: Double? = null,
    val tripMin: Int? = null,
    val uberPerKm: Double? = null,
    val rating: Double? = null,
)

/**
 * Traduz o texto lido da tela em uma oferta.
 *
 * Regra de ouro: nada de depender de `viewId`. O Uber troca id a cada versão
 * (e o 99/inDrive usam outro conjunto), mas o texto da oferta é estável:
 * sempre tem um valor em reais, um tempo e uma distância. Então o parser
 * trabalha em cima de padrões de texto, do jeito que o motorista lê.
 *
 * Formas conhecidas (Uber, out/2026):
 *   radar:      "R$ 7,15" · "Est. de R$3,40/km" · "4 min • 0.9 km" · "5 minutos • 1.2 km"
 *   solicitação: "R$ 12,34" · "3 min (1,2 km) de distância" · "Viagem de 12 min (5,4 km)"
 */
object OfferParser {

    /** Valor em reais. Aceita "R$ 7,15", "R$7,15" e "R$ 1.234,56". */
    private val money = Regex(
        """R\$\s*([0-9]{1,3}(?:\.[0-9]{3})+(?:,[0-9]{1,2})?|[0-9]+(?:[.,][0-9]{1,2})?)""",
    )

    /** Marca preço por unidade ("/km", "/min"): é estimativa, não o valor. */
    private val perUnit = Regex("""/\s*(km|min|h|hora)""", RegexOption.IGNORE_CASE)

    /** "4 min • 0.9 km", "3 min (1,2 km)" */
    private val minutesThenKm = Regex(
        """([0-9]{1,3})\s*min(?:uto)?s?\b[^0-9]{0,12}?([0-9]+(?:[.,][0-9]+)?)\s*km""",
        RegexOption.IGNORE_CASE,
    )

    /** "0.9 km • 4 min" (ordem invertida) */
    private val kmThenMinutes = Regex(
        """([0-9]+(?:[.,][0-9]+)?)\s*km[^0-9]{0,12}?([0-9]{1,3})\s*min(?:uto)?s?\b""",
        RegexOption.IGNORE_CASE,
    )

    /** "4,95 (1643)" — nota do passageiro. */
    private val rating = Regex("""([0-5][.,][0-9]{1,2})\s*\(""")

    fun appIdOf(pkg: String): String = when {
        pkg.contains("ubercab") -> "uber"
        pkg.contains("app99") -> "99"
        pkg.contains("indriver", ignoreCase = true) -> "indrive"
        pkg.contains("ifood", ignoreCase = true) -> "ifood"
        else -> "outro"
    }

    fun parse(pkg: String, nodes: List<Map<String, String>>): ParsedOffer? {
        val texts = nodes
            .mapNotNull { it["text"] }
            .map { it.trim() }
            .filter { it.isNotEmpty() }
        if (texts.isEmpty()) return null

        val lines = mergeSplitMoney(texts)
        val value = findValue(lines) ?: return null
        val uberPerKm = findUberPerKm(lines)
        val segments = findSegments(lines)
        if (segments.isEmpty()) return null

        val pickup = if (segments.size >= 2) segments[0] else null
        val trip = if (segments.size >= 2) segments[1] else segments[0]

        val totalKm = if (segments.size >= 2) {
            segments.take(2).sumOf { it.km }
        } else {
            // Um trecho só: assume que é a viagem inteira. É o caso mais
            // conservador — se fosse só a busca, o R$/km sairia otimista.
            segments[0].km
        }
        val totalMin = if (segments.size >= 2) {
            segments.take(2).sumOf { it.minutes }
        } else {
            segments[0].minutes
        }

        if (totalKm <= 0 || totalMin <= 0) return null

        return ParsedOffer(
            appId = appIdOf(pkg),
            value = value,
            totalKm = totalKm,
            totalMin = totalMin,
            pickupKm = pickup?.km,
            pickupMin = pickup?.minutes,
            tripKm = trip?.km,
            tripMin = trip?.minutes,
            uberPerKm = uberPerKm,
            rating = findRating(lines),
        )
    }

    // ------------------------------------------------------------- interno

    private data class Segment(val km: Double, val minutes: Int)

    /**
     * O motorista vê "R$" e o número em nós separados em alguns aparelhos
     * (o Uber usa a mesma fonte em dois TextView). Junta antes de procurar.
     */
    private fun mergeSplitMoney(texts: List<String>): List<String> {
        val out = ArrayList<String>(texts.size)
        var index = 0
        while (index < texts.size) {
            val current = texts[index]
            val next = texts.getOrNull(index + 1)
            val isBareCurrency = current == "R$" || current == "R $" || current == "R$:"
            if (isBareCurrency && next != null && next.matches(Regex("""[0-9][0-9.,]*"""))) {
                out.add("R$ $next")
                index += 2
                continue
            }
            out.add(current)
            index += 1
        }
        return out
    }

    private fun findValue(lines: List<String>): Double? {
        for (line in lines) {
            if (perUnit.containsMatchIn(line)) continue
            if (line.contains('%')) continue
            val match = money.find(line) ?: continue
            // "+R$ 7,25" é bônus/área de alta demanda no mapa, não oferta.
            if (line.trimStart().startsWith("+")) continue
            val parsed = toDouble(match.groupValues[1]) ?: continue
            if (parsed <= 0) continue
            return parsed
        }
        return null
    }

    private fun findUberPerKm(lines: List<String>): Double? {
        for (line in lines) {
            if (!perUnit.containsMatchIn(line)) continue
            val match = money.find(line) ?: continue
            val parsed = toDouble(match.groupValues[1]) ?: continue
            if (parsed > 0) return parsed
        }
        return null
    }

    private fun findSegments(lines: List<String>): List<Segment> {
        val found = ArrayList<Segment>(3)
        for (line in lines) {
            minutesThenKm.findAll(line).forEach { match ->
                val minutes = match.groupValues[1].toIntOrNull() ?: return@forEach
                val km = toDouble(match.groupValues[2]) ?: return@forEach
                if (minutes in 1..180 && km in 0.1..300.0) {
                    found.add(Segment(km, minutes))
                }
            }
            kmThenMinutes.findAll(line).forEach { match ->
                val km = toDouble(match.groupValues[1]) ?: return@forEach
                val minutes = match.groupValues[2].toIntOrNull() ?: return@forEach
                if (minutes in 1..180 && km in 0.1..300.0) {
                    found.add(Segment(km, minutes))
                }
            }
        }
        return found.distinct()
    }

    private fun findRating(lines: List<String>): Double? {
        for (line in lines) {
            val match = rating.find(line) ?: continue
            val parsed = toDouble(match.groupValues[1]) ?: continue
            if (parsed in 1.0..5.0) return parsed
        }
        return null
    }

    /** "1.234,56" / "7,15" / "7.15" → Double. */
    fun toDouble(raw: String): Double? {
        val cleaned = raw.trim()
        if (cleaned.isEmpty()) return null
        val normalized = when {
            cleaned.contains(',') -> cleaned.replace(".", "").replace(",", ".")
            else -> cleaned
        }
        return normalized.toDoubleOrNull()
    }
}
