package br.com.copiloto.app.reader

import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
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

    private const val METHOD_CHANNEL = "br.com.copiloto.app/reader"
    private const val EVENT_CHANNEL = "br.com.copiloto.app/reader_events"

    private const val PREFS = "copiloto_reader"
    private const val KEY_CAPTURE_ALL = "capture_all"
    private const val KEY_TARGETS = "targets"
    private const val KEY_LAST_DUMP = "last_dump"
    private const val LOG_FILE = "dumps.jsonl"
    private const val MAX_LOG_LINES = 400
    private const val TAG = "CopilotoReader"

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

    private fun captureAll(context: Context): Boolean =
        prefs(context).getBoolean(KEY_CAPTURE_ALL, false)

    private fun targets(context: Context): List<String> {
        val stored = prefs(context).getStringSet(KEY_TARGETS, null)
        return if (stored.isNullOrEmpty()) defaultTargets else stored.sorted()
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
            "targets" to targets(context),
            "lastPackage" to last?.get("package"),
            "lastAt" to last?.get("at"),
            "dumpCount" to synchronized(dumps) { dumps.size },
        )
    }

    private fun isAccessibilityEnabled(context: Context): Boolean {
        val manager = context.getSystemService(Context.ACCESSIBILITY_SERVICE) as? AccessibilityManager
            ?: return false
        val expected = "${context.packageName}/${OfferReaderService::class.java.name}"
        return manager
            .getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_ALL_MASK)
            .any { info ->
                val service = info.resolveInfo?.serviceInfo
                service != null && "${service.packageName}/${service.name}" == expected
            }
    }

    private fun labelOf(context: Context, pkg: String): String {
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
