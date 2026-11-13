package br.com.aceitaai.app.reader

import java.text.Normalizer
import java.util.Locale

/** Resposta do motorista à oferta, deduzida da tela seguinte. */
enum class Acceptance(val label: String) {
    accepted("aceitou"),
    declined("recusou"),
}

/**
 * Descobre se a oferta foi aceita olhando a PRÓXIMA tela do app de corrida.
 *
 * A oferta em si não diz nada sobre a decisão — quem responde é o que vem
 * depois:
 *
 *   aceitou → tela da viagem: "A caminho do passageiro", "Iniciar viagem",
 *             "Deslize para iniciar", "Finalizar viagem"
 *   recusou → volta para o mapa de espera: "Procurando viagens",
 *             "Aguardando solicitações"
 *
 * A aceitação é conclusiva: essas frases não existem antes de aceitar. A
 * recusa é uma inferência — o mapa de espera também aparece antes da oferta —
 * então ela só vale quando o card já saiu da tela, o que [offerVisible]
 * confere pelo valor da corrida.
 *
 * Tudo compara texto normalizado (sem acento, minúsculo): o OCR erra acento
 * com frequência e o app de corrida muda a caixa das frases entre versões.
 */
object AcceptanceParser {

    /** Frases que só aparecem depois de aceitar. */
    private val accepted = listOf(
        "a caminho do passageiro",
        "a caminho do embarque",
        "a caminho do destino",
        "indo buscar o passageiro",
        "indo buscar",
        "iniciar viagem",
        "iniciar corrida",
        "deslize para iniciar",
        "deslize para comecar",
        "deslize para chegar",
        "deslize para finalizar",
        "deslize para concluir",
        "aguardando o passageiro",
        "chegando ao local",
        "cheguei ao local",
        "chegou ao local",
        "cheguei",
        "embarque",
        "desembarque",
        "viagem em andamento",
        "corrida em andamento",
        "em viagem",
        "em corrida",
        "finalizar viagem",
        "finalizar corrida",
        "encerrar viagem",
        "encerrar corrida",
    )

    /** Frases do mapa de espera: se voltaram, a oferta foi recusada. */
    private val declined = listOf(
        "procurando viagens",
        "procurando por viagens",
        "procurando corridas",
        "procurando pedidos",
        "buscando viagens",
        "aguardando solicitacoes",
        "aguardando chamadas",
        "aguardando pedidos",
        "aguardando corridas",
    )

    /** O que a tela diz, ou `null` se ela não responde nada. */
    fun detect(lines: List<String>): Acceptance? {
        val text = normalize(lines.joinToString(" "))
        if (text.isEmpty()) return null
        if (accepted.any { text.contains(it) }) return Acceptance.accepted
        if (declined.any { text.contains(it) }) return Acceptance.declined
        return null
    }

    /** A tela atual mostra uma viagem já em andamento? */
    fun isInTrip(lines: List<String>): Boolean {
        val text = normalize(lines.joinToString(" "))
        if (text.isEmpty()) return false
        return accepted.any { text.contains(it) }
    }

    /**
     * O card flutuante deve ser fechado diante desta leitura de tela?
     *
     * Fecha imediatamente no aceite (para liberar o mapa de navegação) e
     * também na recusa ou expiração assim que o valor da oferta sai da tela.
     */
    fun shouldCloseCard(lines: List<String>, offerValue: Double): Boolean {
        return when (detect(lines)) {
            Acceptance.accepted -> true
            Acceptance.declined -> !offerVisible(lines, offerValue)
            null -> !offerVisible(lines, offerValue)
        }
    }

    /**
     * O card da oferta ainda está na tela?
     *
     * O card mostra o valor da corrida ("R$ 7,15"). Enquanto ele aparece, o
     * mapa de espera continua atrás — ler "Procurando viagens" ali não quer
     * dizer que o motorista recusou.
     */
    fun offerVisible(lines: List<String>, value: Double): Boolean {
        if (value <= 0) return false
        val text = normalize(lines.joinToString(" "))
        val dot = String.format(Locale.US, "%.2f", value)
        return text.contains(dot) || text.contains(dot.replace('.', ','))
    }

    /** Minúsculo, sem acento e com espaços colapsados. */
    fun normalize(raw: String): String {
        val stripped = Normalizer.normalize(raw, Normalizer.Form.NFD)
            .replace(Regex("\\p{Mn}+"), "")
        return stripped.lowercase(Locale.ROOT).replace(Regex("\\s+"), " ").trim()
    }
}
