package br.com.copiloto.app.reader

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.PixelFormat
import android.os.SystemClock
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageView
import br.com.copiloto.app.R
import kotlin.math.abs

/**
 * Balão flutuante sobre os outros apps: liga/desliga a leitura com um toque.
 *
 * Vive dentro do [OfferReaderService] e usa `TYPE_ACCESSIBILITY_OVERLAY`. Esse
 * tipo de janela **não** exige a permissão "desenhar sobre outros apps"
 * (`SYSTEM_ALERT_WINDOW`) — que seria mais uma tela de ajustes para o motorista
 * achar no HyperOS. O preço é que o balão só existe enquanto o serviço de
 * acessibilidade estiver ligado, o que é justo: sem o serviço ele não serve
 * para nada.
 *
 * Toque = liga/desliga. Arrastar = reposiciona (gruda na borda mais próxima).
 */
class ReaderBubble(
    private val context: Context,
    private val onTap: () -> Unit,
    private val onMoved: (Int, Int) -> Unit,
) {
    private val windowManager =
        context.getSystemService(Context.WINDOW_SERVICE) as WindowManager

    private var view: FrameLayout? = null
    private var icon: ImageView? = null
    private var params: WindowManager.LayoutParams? = null

    /** Preferência do usuário: mostrar o balão. */
    private var enabled = true

    /** O Copiloto está na frente — sobre ele o balão atrapalha. */
    private var hiddenForOwnApp = false

    private var reading = true

    private var lastX = -1
    private var lastY = -1

    private val sizePx = dp(BUBBLE_DP)
    private val edgePx = dp(8)

    init {
        Diag.log(context, "balao: criado")
    }

    fun setReading(value: Boolean) {
        reading = value
        paint()
    }

    fun setEnabled(value: Boolean) {
        if (enabled == value) return
        enabled = value
        sync()
    }

    fun setHiddenForOwnApp(hidden: Boolean) {
        if (hiddenForOwnApp == hidden) return
        hiddenForOwnApp = hidden
        sync()
    }

    fun show(startX: Int, startY: Int) {
        lastX = startX
        lastY = startY
        sync()
    }

    fun hide() {
        detach()
    }

    private fun sync() {
        if (enabled && !hiddenForOwnApp) attach() else detach()
    }

    private fun attach() {
        if (view != null) return

        val metrics = context.resources.displayMetrics
        val maxX = (metrics.widthPixels - sizePx).coerceAtLeast(0)
        val maxY = (metrics.heightPixels - sizePx - dp(8)).coerceAtLeast(0)

        val x = if (lastX < 0) maxX - edgePx else lastX.coerceIn(0, maxX)
        val y = if (lastY < 0) {
            // Acima do meio: é onde o card da oferta não passa.
            (metrics.heightPixels * 0.38f).toInt().coerceIn(0, maxY)
        } else {
            lastY.coerceIn(0, maxY)
        }

        val root = FrameLayout(context)
        val image = ImageView(context).apply {
            layoutParams = FrameLayout.LayoutParams(dp(26), dp(26), Gravity.CENTER)
            // O nó de acessibilidade é o balão; o ícone é decoração.
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
        }
        root.addView(image)
        root.isClickable = true

        attachTouch(root, maxX, maxY)

        val added = addWindow(root, x, y)
        if (!added) {
            Log.w(TAG, "balão: nenhuma janela aceita (acessibilidade e overlay)")
            return
        }

        Log.d(TAG, "balão: na tela em ($x,$y) tipo=${params?.type}")

        view = root
        icon = image
        paint()
    }

    /**
     * Tenta os tipos de janela em ordem de preferência.
     *
     * `TYPE_ACCESSIBILITY_OVERLAY` não pede permissão nenhuma, mas o MIUI
     * costuma recusar — nesse caso cai para `TYPE_APPLICATION_OVERLAY`, que
     * exige "exibir sobre outros apps" (concedido pelo usuário).
     */
    private fun addWindow(root: View, x: Int, y: Int): Boolean {
        // Preferir TYPE_APPLICATION_OVERLAY quando a permissão existe: no MIUI é
        // a única que comprovadamente recebe toque. A de acessibilidade fica
        // como reserva, porque não exige permissão nenhuma.
        val candidates = buildList {
            if (Settings.canDrawOverlays(context)) {
                add(WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY)
            }
            add(WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY)
        }

        for (type in candidates) {
            val windowParams = WindowManager.LayoutParams(
                sizePx,
                sizePx,
                type,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                PixelFormat.TRANSLUCENT,
            ).apply {
                gravity = Gravity.TOP or Gravity.START
                this.x = x
                this.y = y
            }

            try {
                windowManager.addView(root, windowParams)
                params = windowParams
                Diag.log(context, "balao: janela ok tipo=$type em ($x,$y)")
                return true
            } catch (error: Throwable) {
                Diag.log(
                    context,
                    "balao: tipo $type recusado (${error.javaClass.simpleName}: ${error.message})",
                )
            }
        }
        return false
    }

    private fun paint() {
        val image = icon ?: return
        val root = view ?: return
        image.setImageResource(
            if (reading) R.drawable.ic_bubble_on else R.drawable.ic_bubble_off,
        )
        root.setBackgroundResource(
            if (reading) R.drawable.bubble_on else R.drawable.bubble_off,
        )
        root.contentDescription = if (reading) {
            "Leitura ligada. Toque para desligar."
        } else {
            "Leitura desligada. Toque para ligar."
        }
    }

    private fun detach() {
        val root = view ?: return
        Diag.log(context, "balao: saindo da tela")
        try {
            windowManager.removeView(root)
        } catch (_: Exception) {
            // Já saiu (serviço desligado pelo sistema).
        }
        view = null
        icon = null
        params = null
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun attachTouch(root: View, maxX: Int, maxY: Int) {
        val slop = ViewConfiguration.get(context).scaledTouchSlop
        var downRawX = 0f
        var downRawY = 0f
        var downX = 0
        var downY = 0
        var downAt = 0L
        var dragging = false

        root.setOnTouchListener { _, event ->
            Diag.log(context, "balao: toque acao=${event.actionMasked}")
            val windowParams = params ?: return@setOnTouchListener false

            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    downRawX = event.rawX
                    downRawY = event.rawY
                    downX = windowParams.x
                    downY = windowParams.y
                    downAt = SystemClock.uptimeMillis()
                    dragging = false
                    true
                }

                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - downRawX
                    val dy = event.rawY - downRawY

                    if (!dragging && (abs(dx) > slop || abs(dy) > slop)) {
                        dragging = true
                        root.alpha = 0.9f
                    }

                    if (dragging) {
                        windowParams.x = (downX + dx).toInt().coerceIn(0, maxX)
                        windowParams.y = (downY + dy).toInt().coerceIn(0, maxY)
                        try {
                            windowManager.updateViewLayout(root, windowParams)
                        } catch (_: Exception) {
                            // janela já removida
                        }
                    }
                    true
                }

                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    root.alpha = 1f

                    // Toque de verdade: parado e rápido. Qualquer outra coisa
                    // é arrasto — o motorista encosta no balão sem querer
                    // quando o celular está no suporte.
                    val isTap = !dragging &&
                        SystemClock.uptimeMillis() - downAt < TAP_TIMEOUT_MS

                    if (isTap) {
                        onTap()
                    } else {
                        // Gruda na borda mais próxima, que é o canto onde ele
                        // não cobre o card da oferta.
                        val middle = maxX / 2
                        windowParams.x = if (windowParams.x < middle) edgePx else maxX - edgePx
                        try {
                            windowManager.updateViewLayout(root, windowParams)
                        } catch (_: Exception) {
                            // idem
                        }
                        lastX = windowParams.x
                        lastY = windowParams.y
                        onMoved(windowParams.x, windowParams.y)
                    }
                    true
                }

                else -> false
            }
        }
    }

    private fun dp(value: Int): Int =
        (value * context.resources.displayMetrics.density).toInt()

    companion object {
        private const val TAG = "CopilotoReader"
        private const val BUBBLE_DP = 56
        private const val TAP_TIMEOUT_MS = 400L
    }
}
