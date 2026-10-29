package br.com.aceitaai.app.reader

import android.accessibilityservice.AccessibilityServiceInfo
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.view.accessibility.AccessibilityManager
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/**
 * Ponte entre o AccessibilityService e o Flutter.
 *
 * Regra: o nativo só coleta e entrega texto. Cálculo, veredito e decisão de
 * mostrar ou não o card ficam no Dart — assim existe uma única fórmula no app.
 */
object ReaderBridge : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private const val METHOD_CHANNEL = "br.com.aceitaai.app/reader"
    private const val EVENT_CHANNEL = "br.com.aceitaai.app/reader_events"

    private const val PREFS = "aceita_ai_reader"
    private const val KEY_CAPTURE_ALL = "capture_all"
    private const val KEY_TARGETS = "targets"
    private const val KEY_LAST_DUMP = "last_dump"
    private const val KEY_READING = "reading_enabled"
    private const val KEY_BUBBLE = "bubble_enabled"
    private const val KEY_BUBBLE_X = "bubble_x"
    private const val KEY_BUBBLE_Y = "bubble_y"
    private const val KEY_MIN_PER_KM = "min_per_km"
    private const val KEY_GOOD_PER_KM = "good_per_km"
    private const val KEY_MIN_PER_HOUR = "min_per_hour"
    private const val KEY_GOOD_PER_HOUR = "good_per_hour"
    private const val KEY_COST_PER_KM = "cost_per_km"
    private const val KEY_MIN_RATING = "min_rating"
    private const val KEY_GOOD_RATING = "good_rating"
    private const val KEY_CARD_FIELDS = "card_fields"
    private const val LOG_FILE = "dumps.jsonl"

    /** Texto cru de cada leitura por imagem, para ajustar o parser. */
    private const val OCR_FILE = "ocr.jsonl"
    private const val MAX_LOG_LINES = 400
    private const val TAG = "AceitaAiReader"

    /** Apps lidos por padrão. Qualquer outro exige o modo "capturar todos". */
    val defaultTargets = listOf(
        "com.ubercab.driver",      // Uber Driver
        "com.app99.driver",        // 99 Motorista e Entregador
        "sinet.startup.inDriver",  // inDrive (modo motorista dentro do app)
    )

    private var appContext: Context? = null
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var sink: EventChannel.EventSink? = null

    private const val MAX_DUMPS = 8
    private val dumps = LinkedHashMap<String, Map<String, Any?>>()

    fun attach(messenger: BinaryMessenger, context: Context) {
        ensureContext(context)
        methodChannel = MethodChannel(messenger, METHOD_CHANNEL).also {
            it.setMethodCallHandler(this)
        }
        eventChannel = EventChannel(messenger, EVENT_CHANNEL).also {
            it.setStreamHandler(this)
        }
    }

    /**
     * O serviço de acessibilidade pode rodar com o app fechado — nesse caso
     * ele precisa de Context próprio, senão a captura é descartada em silêncio.
     */
    fun ensureContext(context: Context) {
        if (appContext == null) {
            appContext = context.applicationContext
            restoreLastDump(context.applicationContext)
        }
    }

    fun detach() {
        methodChannel?.setMethodCallHandler(null)
        eventChannel?.setStreamHandler(null)
        methodChannel = null
        eventChannel = null
        sink = null
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun captureAll(context: Context): Boolean =
        prefs(context).getBoolean(KEY_CAPTURE_ALL, false)

    /** Interruptor do balão: pausar não desliga o serviço, só para de ler. */
    fun readingEnabled(context: Context): Boolean =
        prefs(context).getBoolean(KEY_READING, true)

    fun bubbleEnabled(context: Context): Boolean =
        prefs(context).getBoolean(KEY_BUBBLE, true)

    fun bubbleX(context: Context): Int = prefs(context).getInt(KEY_BUBBLE_X, -1)

    fun bubbleY(context: Context): Int = prefs(context).getInt(KEY_BUBBLE_Y, -1)

    fun saveBubblePosition(context: Context, x: Int, y: Int) {
        prefs(context).edit().putInt(KEY_BUBBLE_X, x).putInt(KEY_BUBBLE_Y, y).apply()
    }

    fun setReadingEnabled(context: Context, enabled: Boolean) {
        prefs(context).edit().putBoolean(KEY_READING, enabled).apply()
        if (OfferReaderService.instance == null) {
            // Serviço fora do ar (Android pode religar em seguida): o painel,
            // se está na tela, ainda é deste turno e precisa acompanhar.
            if (ReaderNotifier.hasState(context)) {
                ReaderNotifier.update(
                    context,
                    if (enabled) ReaderNotifier.State.READING else ReaderNotifier.State.PAUSED,
                )
            }
        } else {
            OfferReaderService.instance?.refreshBubble()
        }
        emitStatus()
    }

    fun setBubbleEnabled(context: Context, enabled: Boolean) {
        prefs(context).edit().putBoolean(KEY_BUBBLE, enabled).apply()
        OfferReaderService.instance?.refreshBubble()
        emitStatus()
    }

    fun targets(context: Context): List<String> {
        val stored = prefs(context).getStringSet(KEY_TARGETS, null)
        return if (stored.isNullOrEmpty()) defaultTargets else stored.sorted()
    }

    /** Metas do motorista, gravadas pelo app; o card calcula com elas. */
    fun goals(context: Context): Goals {
        val stored = prefs(context)
        val defaults = Goals()
        return Goals(
            minPerKm = stored.getFloat(KEY_MIN_PER_KM, defaults.minPerKm.toFloat()).toDouble(),
            goodPerKm = stored.getFloat(KEY_GOOD_PER_KM, defaults.goodPerKm.toFloat()).toDouble(),
            minPerHour = stored.getFloat(KEY_MIN_PER_HOUR, defaults.minPerHour.toFloat()).toDouble(),
            goodPerHour = stored.getFloat(KEY_GOOD_PER_HOUR, defaults.goodPerHour.toFloat()).toDouble(),
            costPerKm = stored.getFloat(KEY_COST_PER_KM, defaults.costPerKm.toFloat()).toDouble(),
            minRating = stored.getFloat(KEY_MIN_RATING, defaults.minRating.toFloat()).toDouble(),
            goodRating = stored.getFloat(KEY_GOOD_RATING, defaults.goodRating.toFloat()).toDouble(),
        )
    }

    fun setGoals(
        context: Context,
        minPerKm: Double?,
        goodPerKm: Double?,
        minPerHour: Double?,
        goodPerHour: Double?,
        costPerKm: Double?,
        minRating: Double? = null,
        goodRating: Double? = null,
    ) {
        prefs(context).edit().apply {
            minPerKm?.let { putFloat(KEY_MIN_PER_KM, it.toFloat()) }
            goodPerKm?.let { putFloat(KEY_GOOD_PER_KM, it.toFloat()) }
            minPerHour?.let { putFloat(KEY_MIN_PER_HOUR, it.toFloat()) }
            goodPerHour?.let { putFloat(KEY_GOOD_PER_HOUR, it.toFloat()) }
            costPerKm?.let { putFloat(KEY_COST_PER_KM, it.toFloat()) }
            minRating?.let { putFloat(KEY_MIN_RATING, it.toFloat()) }
            goodRating?.let { putFloat(KEY_GOOD_RATING, it.toFloat()) }
            apply()
        }
    }

    /**
     * Quais números o card mostra. O card é desenhado pelo serviço, com o app
     * fechado, então quem lê o ajuste é o nativo — o Flutter só grava.
     */
    fun cardFields(context: Context): Set<CardField> =
        CardLayout.fromKeys(prefs(context).getStringSet(KEY_CARD_FIELDS, null))

    fun setCardFields(context: Context, keys: Collection<String>) {
        val fields = CardLayout.fromKeys(keys)
        prefs(context).edit()
            .putStringSet(KEY_CARD_FIELDS, fields.map { it.key }.toSet())
            .apply()
        // Um card de exemplo já na tela não muda de layout sozinho: some, e o
        // próximo (de exemplo ou de oferta real) já vem no novo formato.
        OfferReaderService.instance?.closeCard()
    }

    /** Chamado pelo serviço a cada captura. */
    fun publish(
        pkg: String,
        reason: String,
        nodes: List<Map<String, String>>,
        signature: String,
    ) {
        val context = appContext ?: return

        // Nunca ler a própria tela: gera laço (o card muda a tela, que gera
        // evento, que muda o card...) e não tem valor nenhum.
        if (pkg == context.packageName) return
        if (pkg.isBlank()) return
        if (!readingEnabled(context)) return

        val allowed = captureAll(context) || targets(context).contains(pkg)
        Log.d(
            TAG,
            "captura pkg=$pkg nodes=${nodes.size} permitido=$allowed " +
                "captureAll=${captureAll(context)}",
        )
        if (!allowed) return

        val dump = mapOf(
            "package" to pkg,
            "appLabel" to labelOf(context, pkg),
            "reason" to reason,
            "at" to System.currentTimeMillis(),
            "hash" to signature,
            "nodes" to nodes,
        )

        synchronized(dumps) {
            dumps[pkg] = dump
            while (dumps.size > MAX_DUMPS) {
                val oldest = dumps.keys.firstOrNull() ?: break
                dumps.remove(oldest)
            }
        }

        // Sobrevive à morte do processo (comum em Xiaomi/Samsung agressivos).
        persistLastDump(context, dump)

        sink?.success(mapOf("kind" to "dump", "dump" to dump))
    }

    private fun persistLastDump(context: Context, dump: Map<String, Any?>) {
        try {
            val json = JSONObject()
                .put("package", dump["package"] as? String ?: "")
                .put("appLabel", dump["appLabel"] as? String ?: "")
                .put("reason", dump["reason"] as? String ?: "")
                .put("at", dump["at"] as? Long ?: System.currentTimeMillis())
                .put("hash", dump["hash"] as? String ?: "")

            @Suppress("UNCHECKED_CAST")
            val nodes = dump["nodes"] as? List<Map<String, String>> ?: emptyList()
            val array = JSONArray()
            for (node in nodes) {
                array.put(
                    JSONObject()
                        .put("text", node["text"].orEmpty())
                        .put("id", node["id"].orEmpty())
                        .put("cls", node["cls"].orEmpty()),
                )
            }
            json.put("nodes", array)

            val payload = json.toString()
            prefs(context).edit().putString(KEY_LAST_DUMP, payload).apply()
            appendDumpLog(context, payload)
        } catch (_: Exception) {
            // Conveniência: falhar ao persistir não pode derrubar a leitura.
        }
    }

    /**
     * Histórico em texto (uma captura por linha) na pasta externa do app.
     *
     * É o insumo para escrever o parser: `adb pull` deste arquivo dá telas
     * reais, na versão real do app do motorista. Rotaciona para não crescer.
     */
    private fun appendDumpLog(context: Context, line: String) {
        try {
            val dir = context.getExternalFilesDir(null) ?: return
            if (!dir.exists()) dir.mkdirs()
            val file = File(dir, LOG_FILE)

            if (file.exists()) {
                val lines = file.readLines()
                if (lines.size >= MAX_LOG_LINES) {
                    file.writeText(
                        lines.takeLast(MAX_LOG_LINES / 2).joinToString("\n") + "\n",
                    )
                }
            }
            file.appendText(line + "\n")
        } catch (_: Exception) {
            // idem: log é diagnóstico, não pode derrubar a leitura.
        }
    }

    private fun clearDumpLog(context: Context) {
        try {
            val dir = context.getExternalFilesDir(null) ?: return
            File(dir, LOG_FILE).delete()
        } catch (_: Exception) {
            // ignora
        }
    }

    /**
     * Texto cru de uma leitura por imagem, uma leitura por linha em
     * `ocr.jsonl`.
     *
     * O diag só guarda um resumo (as primeiras linhas), e é justamente o
     * resto — o card da oferta fica no meio da tela — que precisa ser visto
     * para ajustar o parser. Vai para arquivo pelo mesmo motivo dos dumps:
     * logcat nesta MIUI é inutilizável.
     */
    fun appendOcrLog(context: Context, pkg: String, lines: List<String>) {
        try {
            val dir = context.getExternalFilesDir(null) ?: return
            if (!dir.exists()) dir.mkdirs()
            val file = File(dir, OCR_FILE)

            if (file.exists()) {
                val existing = file.readLines()
                if (existing.size >= MAX_LOG_LINES) {
                    file.writeText(
                        existing.takeLast(MAX_LOG_LINES / 2).joinToString("\n") + "\n",
                    )
                }
            }

            val json = JSONObject()
            json.put("at", System.currentTimeMillis())
            json.put("package", pkg)
            json.put("lines", JSONArray(lines))
            file.appendText(json.toString() + "\n")
        } catch (_: Exception) {
            // diagnóstico não pode derrubar a leitura
        }
    }

    private fun restoreLastDump(context: Context) {
        val raw = prefs(context).getString(KEY_LAST_DUMP, null) ?: return
        try {
            val json = JSONObject(raw)
            val array = json.optJSONArray("nodes") ?: JSONArray()

            val nodes = ArrayList<Map<String, String>>(array.length())
            for (index in 0 until array.length()) {
                val node = array.optJSONObject(index) ?: continue
                nodes.add(
                    mapOf(
                        "text" to node.optString("text"),
                        "id" to node.optString("id"),
                        "cls" to node.optString("cls"),
                    ),
                )
            }

            val dump = mapOf(
                "package" to json.optString("package"),
                "appLabel" to json.optString("appLabel"),
                "reason" to json.optString("reason"),
                "at" to json.optLong("at"),
                "hash" to json.optString("hash"),
                "nodes" to nodes,
            )

            val pkg = dump["package"] as? String
            if (!pkg.isNullOrBlank()) {
                synchronized(dumps) { dumps[pkg] = dump }
            }
        } catch (_: Exception) {
            prefs(context).edit().remove(KEY_LAST_DUMP).apply()
        }
    }

    fun onServiceStateChanged() {
        emitStatus()
    }

    private fun emitStatus() {
        val context = appContext ?: return
        sink?.success(mapOf("kind" to "status", "status" to statusMap(context)))
    }

    private fun statusMap(context: Context): Map<String, Any?> {
        val last = synchronized(dumps) { dumps.values.lastOrNull() }
        return mapOf(
            "serviceEnabled" to isAccessibilityEnabled(context),
            "serviceConnected" to OfferReaderService.connected,
            "captureAll" to captureAll(context),
            "readingEnabled" to readingEnabled(context),
            "bubbleEnabled" to bubbleEnabled(context),
            "canDrawOverlays" to Settings.canDrawOverlays(context),
            "batteryUnrestricted" to isBatteryUnrestricted(context),
            "notificationsEnabled" to areNotificationsEnabled(context),
            "targets" to targets(context),
            "lastPackage" to last?.get("package"),
            "lastAt" to last?.get("at"),
            "dumpCount" to synchronized(dumps) { dumps.size },
            "cardFields" to cardFields(context).map { it.key }.sorted(),
        )
    }

    /**
     * O Android está livre para manter a leitura viva?
     *
     * Com "economia de bateria" ligada o MIUI corta o processo do app no meio
     * do turno: a acessibilidade continua marcada como ligada, mas para de
     * receber eventos. É a causa mais comum de "o card parou de aparecer".
     */
    private fun isBatteryUnrestricted(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val manager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
            ?: return true
        return manager.isIgnoringBatteryOptimizations(context.packageName)
    }

    private fun areNotificationsEnabled(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return true
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE)
            as? NotificationManager ?: return true
        return manager.areNotificationsEnabled()
    }

    /**
     * A acessibilidade está ligada?
     *
     * Três fontes, porque cada uma falha de um jeito no MIUI/HyperOS:
     * o serviço conectado (prova viva), a configuração
     * `enabled_accessibility_services` (é o que o sistema grava quando o
     * usuário liga na tela de acessibilidade) e a lista do
     * `AccessibilityManager`. Com a checagem só pela lista, o app dizia
     * "desligada" com o serviço rodando.
     */
    private fun isAccessibilityEnabled(context: Context): Boolean {
        if (OfferReaderService.connected) return true

        val expected = "${context.packageName}/${OfferReaderService::class.java.name}"

        val fromSetting = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ).orEmpty()
        if (fromSetting.split(':').any { it.trim().equals(expected, ignoreCase = true) }) {
            return true
        }

        val manager = context.getSystemService(Context.ACCESSIBILITY_SERVICE) as? AccessibilityManager
            ?: return false
        return manager
            .getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_ALL_MASK)
            .any { info ->
                val service = info.resolveInfo?.serviceInfo
                service != null && "${service.packageName}/${service.name}" == expected
            }
    }

    fun labelOf(context: Context, pkg: String): String {
        return try {
            val pm = context.packageManager
            val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                pm.getApplicationInfo(pkg, PackageManager.ApplicationInfoFlags.of(0))
            } else {
                @Suppress("DEPRECATION")
                pm.getApplicationInfo(pkg, 0)
            }
            pm.getApplicationLabel(info).toString()
        } catch (_: Exception) {
            pkg
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val context = appContext
        if (context == null) {
            result.error("no_context", "Ponte não inicializada", null)
            return
        }

        when (call.method) {
            "status" -> result.success(statusMap(context))

            "lastDump" -> result.success(synchronized(dumps) { dumps.values.lastOrNull() })

            "openAccessibilitySettings" -> {
                try {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(intent)
                    result.success(null)
                } catch (error: Exception) {
                    result.error("no_settings", error.message, null)
                }
            }

            "setCaptureAll" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                prefs(context).edit().putBoolean(KEY_CAPTURE_ALL, enabled).apply()
                result.success(statusMap(context))
                emitStatus()
            }

            "setReadingEnabled" -> {
                val enabled = call.argument<Boolean>("enabled") ?: true
                setReadingEnabled(context, enabled)
                result.success(statusMap(context))
            }

            "setBubbleEnabled" -> {
                val enabled = call.argument<Boolean>("enabled") ?: true
                setBubbleEnabled(context, enabled)
                result.success(statusMap(context))
            }

            "setCardFields" -> {
                val fields = call.argument<List<String>>("fields").orEmpty()
                setCardFields(context, fields)
                result.success(statusMap(context))
                emitStatus()
            }

            "setAppVisible" -> {
                val visible = call.argument<Boolean>("visible") ?: false
                OfferReaderService.instance?.setAppInForeground(visible)
                result.success(null)
            }

            "openOverlaySettings" -> {
                try {
                    val intent = Intent(
                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        android.net.Uri.parse("package:${context.packageName}"),
                    )
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(intent)
                    result.success(null)
                } catch (error: Exception) {
                    result.error("no_settings", error.message, null)
                }
            }

            "openBatterySettings" -> {
                // Sem pedir REQUEST_IGNORE_BATTERY_OPTIMIZATIONS: a tela da
                // lista resolve igual e não entra em política de loja.
                try {
                    context.startActivity(
                        Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                    )
                    result.success(null)
                } catch (error: Exception) {
                    try {
                        context.startActivity(
                            Intent(
                                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.parse("package:${context.packageName}"),
                            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                        )
                        result.success(null)
                    } catch (fallback: Exception) {
                        result.error("no_settings", fallback.message, null)
                    }
                }
            }

            "openNotificationSettings" -> {
                try {
                    val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                            .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                    } else {
                        Intent(
                            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            Uri.parse("package:${context.packageName}"),
                        )
                    }
                    context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    result.success(null)
                } catch (error: Exception) {
                    result.error("no_settings", error.message, null)
                }
            }

            "openAutoStart" -> {
                // Autostart é tela do MIUI, sem API pública: tenta a conhecida
                // e cai nos detalhes do app quando a MIUI muda o caminho.
                val known = "com.miui.securitycenter/com.miui.permcenter.autostart.AutoStartManagementActivity"
                var opened = false
                try {
                    context.startActivity(
                        Intent().setClassName(
                            known.substringBefore('/'),
                            known.substringAfter('/'),
                        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                    )
                    opened = true
                } catch (_: Exception) {
                    opened = false
                }
                if (!opened) {
                    try {
                        context.startActivity(
                            Intent(
                                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.parse("package:${context.packageName}"),
                            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                        )
                    } catch (_: Exception) {
                        // Aparelho sem tela de detalhes: nada a fazer.
                    }
                }
                result.success(opened)
            }

            "setTargets" -> {
                val list = call.argument<List<String>>("packages").orEmpty()
                prefs(context).edit()
                    .putStringSet(KEY_TARGETS, list.filter { it.isNotBlank() }.toSet())
                    .apply()
                result.success(statusMap(context))
                emitStatus()
            }

            "clear" -> {
                synchronized(dumps) { dumps.clear() }
                prefs(context).edit().remove(KEY_LAST_DUMP).apply()
                clearDumpLog(context)
                result.success(statusMap(context))
            }

            "setGoals" -> {
                setGoals(
                    context,
                    minPerKm = call.argument<Double>("minPerKm"),
                    goodPerKm = call.argument<Double>("goodPerKm"),
                    minPerHour = call.argument<Double>("minPerHour"),
                    goodPerHour = call.argument<Double>("goodPerHour"),
                    costPerKm = call.argument<Double>("costPerKm"),
                    minRating = call.argument<Double>("minRating"),
                    goodRating = call.argument<Double>("goodRating"),
                )
                result.success(statusMap(context))
            }

            /**
             * Testa o parser com linhas de texto soltas, sem precisar de uma
             * oferta real na tela. Serve para validar contra um dump antigo.
             */
            "parseText" -> {
                val lines = call.argument<List<String>>("lines").orEmpty()
                val pkg = call.argument<String>("package") ?: "com.ubercab.driver"
                val nodes = lines.map { mapOf("text" to it, "id" to "", "cls" to "") }
                val offer = OfferParser.parse(pkg, nodes)
                if (offer == null) {
                    result.success(mapOf("offer" to null))
                } else {
                    val verdict = EarningsEngine.evaluate(offer, goals(context))
                    result.success(
                        mapOf(
                            "offer" to mapOf(
                                "appId" to offer.appId,
                                "value" to offer.value,
                                "totalKm" to offer.totalKm,
                                "totalMin" to offer.totalMin,
                                "pickupKm" to offer.pickupKm,
                                "pickupMin" to offer.pickupMin,
                                "tripKm" to offer.tripKm,
                                "tripMin" to offer.tripMin,
                                "uberPerKm" to offer.uberPerKm,
                                "rating" to offer.rating,
                            ),
                            "verdict" to mapOf(
                                "perKm" to verdict.perKm,
                                "perHour" to verdict.perHour,
                                "profit" to verdict.profit,
                                "overall" to verdict.overall.name,
                            ),
                        ),
                    )
                }
            }

            /** Desenha o card com números sintéticos, para conferir o layout. */
            "devOffer" -> {
                val value = call.argument<Double>("value") ?: 7.15
                val km = call.argument<Double>("km") ?: 2.1
                val minutes = call.argument<Int>("minutes") ?: 9
                val service = OfferReaderService.instance
                if (service == null) {
                    result.error("no_service", "Serviço de acessibilidade desligado", null)
                } else {
                    service.devShowOffer(value, km, minutes)
                    result.success(null)
                }
            }

            /** Lê a tela por imagem agora e devolve as linhas reconhecidas. */
            "ocrNow" -> {
                val service = OfferReaderService.instance
                if (service == null) {
                    result.error("no_service", "Serviço de acessibilidade desligado", null)
                } else {
                    service.debugOcr { lines ->
                        result.success(
                            mapOf(
                                "count" to lines.size,
                                "lines" to lines.take(40),
                            ),
                        )
                    }
                }
            }

            /** Registra uma oferta sintética no histórico (teste sem oferta real). */
            "devRecordOffer" -> {
                val value = call.argument<Double>("value") ?: 7.15
                val km = call.argument<Double>("km") ?: 2.1
                val minutes = call.argument<Int>("minutes") ?: 9
                val offer = ParsedOffer(
                    appId = "uber",
                    value = value,
                    totalKm = km,
                    totalMin = minutes,
                    pickupKm = km * 0.4,
                    pickupMin = minutes / 3,
                    tripKm = km * 0.6,
                    tripMin = minutes - minutes / 3,
                    uberPerKm = if (km > 0) value / km else null,
                    rating = 4.95,
                )
                result.success(OfferHistory.record(context, offer))
            }

            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        val context = appContext ?: return
        events?.success(mapOf("kind" to "status", "status" to statusMap(context)))
        val last = synchronized(dumps) { dumps.values.lastOrNull() }
        if (last != null) {
            events?.success(mapOf("kind" to "dump", "dump" to last))
        }
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }
}

