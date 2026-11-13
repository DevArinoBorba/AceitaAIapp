package br.com.aceitaai.app.reader

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Grava a oferta lida no histórico do app.
 *
 * O card aparece com o app fechado, então quem registra a oferta é o serviço
 * de acessibilidade. O histórico é o mesmo que o Flutter lê: a chave
 * `history_v1` do arquivo do `shared_preferences` (`FlutterSharedPreferences`,
 * prefixo `flutter.`), no formato de `OfferVerdict.toJson()`:
 *
 *   [{"offer": {...}, "goals": {...}}, ...]
 *
 * As metas são copiadas inteiras do JSON do Flutter (`goals_v1`) — assim a
 * oferta é reavaliada depois com as metas da hora em que foi lida, e não com
 * as metas de hoje.
 *
 * Falhar aqui nunca pode derrubar a leitura: tudo é silencioso.
 */
object OfferHistory {

    /** Arquivo de preferências usado pelo plugin shared_preferences. */
    private const val FLUTTER_PREFS = "FlutterSharedPreferences"
    private const val KEY_HISTORY = "flutter.history_v1"
    private const val KEY_GOALS = "flutter.goals_v1"

    /** Preferências do leitor: guardam a assinatura da última oferta gravada. */
    private const val PREFS = "aceita_ai_reader"
    private const val KEY_LAST = "last_history_offer"
    private const val KEY_LAST_AT = "last_history_offer_at"

    /** Mesmo teto do `HistoryRepository` no Dart. */
    const val MAX_ENTRIES = 300

    /**
     * A mesma oferta continua na tela por minutos (o card se redesenha a cada
     * poucos segundos). Dentro dessa janela, números iguais são a mesma
     * oferta, não uma oferta nova.
     */
    const val DEDUPE_MS = 5 * 60_000L

    /**
     * Registra a oferta, se ela ainda não estiver registrada.
     *
     * @return true se entrou no histórico agora.
     */
    fun record(
        context: Context,
        offer: ParsedOffer,
        at: Long = System.currentTimeMillis(),
    ): Boolean {
        val signature = signatureOf(offer)
        val readerPrefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val last = readerPrefs.getString(KEY_LAST, null)
        val lastAt = readerPrefs.getLong(KEY_LAST_AT, 0L)
        if (signature == last && at - lastAt < DEDUPE_MS) return false

        return try {
            val prefs = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
            val history = JSONArray(prefs.getString(KEY_HISTORY, null) ?: "[]")

            // Mais nova primeiro, como a lista do app espera.
            val next = JSONArray().put(entryOf(offer, goalsJson(context, prefs), at))
            for (index in 0 until minOf(history.length(), MAX_ENTRIES - 1)) {
                next.put(history.get(index))
            }

            // commit (e não apply): a oferta pode ser a última coisa antes de o
            // sistema matar o processo do serviço.
            val saved = prefs.edit().putString(KEY_HISTORY, next.toString()).commit()
            if (saved) {
                readerPrefs.edit()
                    .putString(KEY_LAST, signature)
                    .putLong(KEY_LAST_AT, at)
                    .apply()
            }
            saved
        } catch (_: Exception) {
            false
        }
    }

    /**
     * Marca a oferta mais recente como aceita ou recusada.
     *
     * A decisão do motorista só aparece depois, na tela seguinte, quando a
     * entrada já está gravada. Atualiza a entrada 0 — mas só se ela ainda for
     * a oferta observada (a assinatura confere): se outra corrida entrou no
     * meio, marcar a errada seria pior do que não marcar.
     */
    fun markLatest(context: Context, signature: String, accepted: Boolean): Boolean {
        return try {
            val prefs = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
            val next = markIn(prefs.getString(KEY_HISTORY, null) ?: "[]", signature, accepted)
                ?: return false
            prefs.edit().putString(KEY_HISTORY, next).commit()
        } catch (_: Exception) {
            false
        }
    }

    /**
     * A mesma marcação, só no JSON (sem tocar no arquivo).
     *
     * @return o histórico novo, ou `null` se a entrada 0 não é a observada.
     */
    fun markIn(historyJson: String, signature: String, accepted: Boolean): String? {
        val history = JSONArray(historyJson)
        if (history.length() == 0) return null

        val entry = history.getJSONObject(0)
        if (signatureOf(entry) != signature) return null

        // O campo é lido pelo `OfferVerdict` no Dart (`accepted`).
        entry.put("accepted", accepted)
        return history.toString()
    }

    /** Identidade da oferta: o que muda quando é outra corrida. */
    fun signatureOf(offer: ParsedOffer): String =
        "${offer.appId}|${offer.value}|${offer.totalKm}|${offer.totalMin}"

    /** A mesma assinatura, lida de uma entrada já gravada. */
    fun signatureOf(entry: JSONObject): String {
        val offer = entry.optJSONObject("offer") ?: return ""
        return "${offer.optString("appId")}|${offer.optDouble("value")}|" +
            "${offer.optDouble("distanceKm")}|${offer.optInt("timeMin")}"
    }

    /**
     * Metas atuais. Prefere o JSON do Flutter (tem margem e metas de
     * faturamento, que o card não usa); sem ele, monta com o que o card sabe.
     */
    private fun goalsJson(context: Context, prefs: SharedPreferences): JSONObject =
        goalsJson(prefs.getString(KEY_GOALS, null), ReaderBridge.goals(context))

    fun goalsJson(goals: Goals): JSONObject = goalsJson(null, goals)

    fun goalsJson(raw: String?, goals: Goals = Goals()): JSONObject {
        if (!raw.isNullOrBlank()) {
            try {
                return JSONObject(raw)
            } catch (_: Exception) {
                // JSON quebrado: cai no fallback abaixo.
            }
        }

        return JSONObject()
            .put("minPerKm", goals.minPerKm)
            .put("goodPerKm", goals.goodPerKm)
            .put("minPerHour", goals.minPerHour)
            .put("goodPerHour", goals.goodPerHour)
            .put("minProfitPct", goals.minProfitPct)
            .put("goodProfitPct", goals.goodProfitPct)
            .put("costPerKm", goals.costPerKm)
            .put("minRating", goals.minRating)
            .put("goodRating", goals.goodRating)
    }

    /** Mesmo formato de `Offer.toJson()` no Dart. */
    fun entryOf(offer: ParsedOffer, goals: JSONObject, at: Long): JSONObject {
        val offerJson = JSONObject()
            .put("appId", offer.appId)
            .put("value", offer.value)
            .put("distanceKm", offer.totalKm)
            .put("timeMin", offer.totalMin)
            .put("passengerRating", offer.rating ?: JSONObject.NULL)
            .put("label", JSONObject.NULL)
            .put("createdAt", iso(at))

        return JSONObject()
            .put("offer", offerJson)
            .put("goals", goals)
    }

    /** ISO-8601 sem fuso, que é o que `DateTime.tryParse` espera. */
    fun iso(at: Long): String =
        SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US).format(Date(at))
}
