package br.com.copiloto.app.reader

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.view.accessibility.AccessibilityWindowInfo
import android.widget.Toast

/**
 * Lê o conteúdo da tela dos apps de corrida.
 *
 * Não interpreta nada: coleta os nós (texto + viewId + classe) e publica o dump.
 * A interpretação fica no parser, que é dado puro e pode ser corrigido sem
 * reinstalar o app.
 *
 * Lê **todas as janelas** do app, não só a janela ativa: o card de oferta do
 * Uber (radar e solicitação) é uma janela separada por cima do mapa, e ler só
 * `rootInActiveWindow` devolvia o mapa e perdia a oferta.
 */
class OfferReaderService : AccessibilityService() {

    private val handler = Handler(Looper.getMainLooper())
    private var pending: Runnable? = null

    private var lastSignature: String? = null
    private var lastSignatureAt = 0L
    private var lastPackage: String? = null
    private var lastEventPackage: String? = null

    private var bubble: ReaderBubble? = null

    companion object {
        private const val TAG = "CopilotoReader"
        private const val DEBOUNCE_MS = 350L
        private const val DEDUPE_WINDOW_MS = 2_500L
        private const val MAX_NODES = 700
        private const val MAX_DEPTH = 40

        /** Ligado enquanto o serviço estiver conectado (o usuário pode desligar nas configurações). */
        @Volatile
        var connected = false

        /**
         * Instância viva, para a ponte conseguir atualizar o balão quando o
         * usuário mexe nas opções dentro do app.
         */
        @Volatile
        var instance: OfferReaderService? = null

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
        instance = this
        serviceInfo = serviceInfo?.apply {
            flags = flags or
                AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS or
                AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
            notificationTimeout = 150
        }
        setupBubble()
        ReaderBridge.onServiceStateChanged()
    }

    // ---------------------------------------------------------------- balão

    private fun setupBubble() {
        if (bubble != null) return
        val context = applicationContext ?: return

        Log.d(
            TAG,
            "balão: criando (enabled=${ReaderBridge.bubbleEnabled(context)}, " +
                "reading=${ReaderBridge.readingEnabled(context)}, " +
                "overlay=${Settings.canDrawOverlays(context)})",
        )

        val created = ReaderBubble(
            context = this,
            onTap = { toggleReading() },
            onMoved = { x, y -> ReaderBridge.saveBubblePosition(context, x, y) },
        )
        created.setReading(ReaderBridge.readingEnabled(context))
        created.setEnabled(ReaderBridge.bubbleEnabled(context))
        created.show(
            ReaderBridge.bubbleX(context),
            ReaderBridge.bubbleY(context),
        )
        bubble = created
    }

    private fun toggleReading() {
        val context = applicationContext ?: return
        val next = !ReaderBridge.readingEnabled(context)
        Diag.log(context, "balao: toque -> leitura=$next")
        ReaderBridge.setReadingEnabled(context, next)
        Toast.makeText(
            this,
            if (next) "Leitura ligada" else "Leitura desligada",
            Toast.LENGTH_SHORT,
        ).show()
    }

    /** Chamado pela ponte quando a opção muda dentro do app. */
    fun refreshBubble() {
        val context = applicationContext ?: return
        bubble?.setReading(ReaderBridge.readingEnabled(context))
        bubble?.setEnabled(ReaderBridge.bubbleEnabled(context))
    }

    /**
     * O Flutter avisa quando o Copiloto entra/sai da frente.
     *
     * Antes isso era deduzido dos eventos de acessibilidade, mas o próprio
     * balão gera eventos do nosso pacote — o serviço achava que o app estava
     * aberto e escondia o balão em laço.
     */
    fun setAppInForeground(foreground: Boolean) {
        bubble?.setHiddenForOwnApp(foreground)
    }

    // ---------------------------------------------------------------- leitura

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        val pkg = event.packageName?.toString().orEmpty()
        if (pkg.isEmpty()) return
        if (pkg == packageName) return
        if (pkg in IGNORED_PACKAGES) return

        val context = applicationContext ?: return
        if (!ReaderBridge.readingEnabled(context)) return

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

    private data class WindowCapture(
        val packageName: String,
        val type: Int,
        val focused: Boolean,
        val nodes: List<Map<String, String>>,
    )

    /**
     * Todos os nós de todas as janelas visíveis.
     *
     * Precisa de FLAG_RETRIEVE_INTERACTIVE_WINDOWS, que é ligado em
     * [onServiceConnected].
     */
    private fun readWindows(): List<WindowCapture> {
        val captures = ArrayList<WindowCapture>(4)

        val sources = try {
            windows
        } catch (_: Exception) {
            null
        }

        if (sources.isNullOrEmpty()) {
            // Reserva: alguns aparelhos não entregam a lista de janelas.
            val root = rootInActiveWindow ?: return captures
            val nodes = ArrayList<Map<String, String>>(96)
            collect(root, nodes, 0)
            val pkg = root.packageName?.toString().orEmpty()
            root.recycle()
            if (pkg.isNotEmpty() && nodes.isNotEmpty()) {
                captures.add(
                    WindowCapture(pkg, AccessibilityWindowInfo.TYPE_APPLICATION, true, nodes),
                )
            }
            return captures
        }

        for (window in sources) {
            val root = try {
                window.root
            } catch (_: Exception) {
                null
            } ?: continue

            val pkg = root.packageName?.toString().orEmpty()
            val nodes = ArrayList<Map<String, String>>(96)
            collect(root, nodes, 0)
            root.recycle()

            if (pkg.isEmpty() || nodes.isEmpty()) continue
            captures.add(WindowCapture(pkg, window.type, window.isFocused, nodes))
        }
        return captures
    }

    private fun capture(eventPackage: String) {
        val windowsNow = readWindows()
        if (windowsNow.isEmpty()) {
            Log.d(TAG, "captura sem janela para $eventPackage")
            return
        }

        val candidates = windowsNow.filter {
            it.packageName != packageName && it.packageName !in IGNORED_PACKAGES
        }
        if (candidates.isEmpty()) return

        // Uma captura = um app. Se houver várias janelas do mesmo app (mapa +
        // card da oferta), junta todas: o card é justamente a que interessa.
        val primary = candidates.firstOrNull { it.focused }?.packageName
            ?: candidates.maxByOrNull { it.nodes.size }?.packageName
            ?: return

        val nodes = ArrayList<Map<String, String>>(160)
        for (window in candidates) {
            if (window.packageName != primary) continue
            nodes.addAll(window.nodes)
            if (nodes.size >= MAX_NODES) break
        }

        Log.d(
            TAG,
            "captura $primary -> ${nodes.size} nós em ${candidates.size} janela(s) " +
                "(${candidates.joinToString { "${it.type}:${it.nodes.size}" }}) " +
                "evento=$eventPackage",
        )

        Diag.log(
            applicationContext,
            "captura $primary nos=${nodes.size} janelas=" +
                candidates.joinToString { "${it.type}:${it.nodes.size}" },
        )

        if (nodes.isEmpty()) return

        val signature = nodes.joinToString(separator = "|") { it["text"].orEmpty() }
        val now = System.currentTimeMillis()
        val repeated = signature == lastSignature &&
            lastPackage == primary &&
            now - lastSignatureAt < DEDUPE_WINDOW_MS

        lastSignature = signature
        lastSignatureAt = now
        lastPackage = primary

        if (repeated) return

        ReaderBridge.publish(
            pkg = primary,
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
        bubble?.hide()
        bubble = null
        instance = null
        connected = false
        ReaderBridge.onServiceStateChanged()
        super.onDestroy()
    }
}
