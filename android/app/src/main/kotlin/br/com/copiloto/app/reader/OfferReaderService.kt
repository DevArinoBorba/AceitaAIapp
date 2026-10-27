package br.com.copiloto.app.reader

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

/**
 * Lê o conteúdo da tela dos apps de corrida.
 *
 * Não interpreta nada: coleta os nós (texto + viewId + classe) e publica o dump.
 * A interpretação fica no parser, que é dado puro e pode ser corrigido sem
 * reinstalar o app.
 */
class OfferReaderService : AccessibilityService() {

    private val handler = Handler(Looper.getMainLooper())
    private var pending: Runnable? = null

    private var lastSignature: String? = null
    private var lastSignatureAt = 0L
    private var lastPackage: String? = null
    private var lastEventPackage: String? = null

    companion object {
        private const val TAG = "CopilotoReader"
        private const val DEBOUNCE_MS = 350L
        private const val DEDUPE_WINDOW_MS = 2_500L
        private const val MAX_NODES = 500
        private const val MAX_DEPTH = 40

        /** Ligado enquanto o serviço estiver conectado (o usuário pode desligar nas configurações). */
        @Volatile
        var connected = false

        /**
         * Pacotes que nunca interessam: barra de status, launcher, ajustes.
         * Sem isso o serviço captura dezenas de telas inúteis por minuto.
         */
        private val IGNORED_PACKAGES = setOf(
            "com.android.systemui",
            "com.miui.home",
            "com.miui.securitycenter",
            "com.android.settings",
            "com.google.android.permissioncontroller",
        )
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        // Independente do app estar aberto: o serviço precisa do próprio Context.
        ReaderBridge.ensureContext(applicationContext)
        connected = true
        serviceInfo = serviceInfo?.apply {
            flags = flags or
                AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS or
                AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
            notificationTimeout = 150
        }
        ReaderBridge.onServiceStateChanged()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        val pkg = event.packageName?.toString().orEmpty()
        if (pkg.isEmpty() || pkg == packageName || pkg in IGNORED_PACKAGES) return

        if (pkg != lastEventPackage) {
            Log.d(TAG, "eventos de $pkg (tipo=${event.eventType})")
            lastEventPackage = pkg
        }

        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED &&
            event.eventType != AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
        ) {
            return
        }

        // Cada mudança de tela gera dezenas de eventos. Um debounce curto
        // mantém a leitura em ~3 dumps por segundo no pior caso.
        pending?.let { handler.removeCallbacks(it) }
        val task = Runnable { capture(pkg) }
        pending = task
        handler.postDelayed(task, DEBOUNCE_MS)
    }

    private fun capture(eventPackage: String) {
        val root = rootInActiveWindow
        if (root == null) {
            Log.d(TAG, "captura sem root para $eventPackage")
            return
        }

        // A janela ativa manda: durante a transição o evento pode vir de um
        // pacote e a árvore já ser de outro.
        val pkg = root.packageName?.toString().orEmpty()
        val nodes = ArrayList<Map<String, String>>(96)
        collect(root, nodes, 0)
        Log.d(TAG, "captura $pkg -> ${nodes.size} nós (evento=$eventPackage)")

        if (nodes.isEmpty() || pkg.isBlank() || pkg == packageName) {
            root.recycle()
            return
        }

        val signature = nodes.joinToString(separator = "|") { it["text"].orEmpty() }
        val now = System.currentTimeMillis()
        val repeated = signature == lastSignature &&
            lastPackage == pkg &&
            now - lastSignatureAt < DEDUPE_WINDOW_MS

        lastSignature = signature
        lastSignatureAt = now
        lastPackage = pkg
        root.recycle()

        if (repeated) return

        ReaderBridge.publish(
            pkg = pkg,
            reason = "content_changed",
            nodes = nodes,
            signature = signature.hashCode().toString(),
        )
    }

    private fun collect(
        node: AccessibilityNodeInfo?,
        out: MutableList<Map<String, String>>,
        depth: Int,
    ) {
        if (node == null || out.size >= MAX_NODES || depth > MAX_DEPTH) return

        val text = node.text?.toString()?.trim().orEmpty()
        val description = node.contentDescription?.toString()?.trim().orEmpty()
        val hint = node.hintText?.toString()?.trim().orEmpty()

        val label = buildList {
            if (text.isNotEmpty()) add(text)
            if (description.isNotEmpty() && description != text) add(description)
            if (hint.isNotEmpty() && hint != text && hint != description) add(hint)
        }.joinToString(" · ")

        if (label.isNotEmpty()) {
            out.add(
                mapOf(
                    "text" to label,
                    "id" to (node.viewIdResourceName ?: ""),
                    "cls" to (node.className?.toString() ?: ""),
                ),
            )
        }

        for (index in 0 until node.childCount) {
            collect(node.getChild(index), out, depth + 1)
            if (out.size >= MAX_NODES) break
        }
    }

    override fun onInterrupt() {
        // Sem trabalho assíncrono para interromper no momento.
    }

    override fun onDestroy() {
        pending?.let { handler.removeCallbacks(it) }
        connected = false
        ReaderBridge.onServiceStateChanged()
        super.onDestroy()
    }
}
