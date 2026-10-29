package br.com.aceitaai.app.reader

import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import java.util.Locale

/**
 * Card que aparece por cima do app de corrida com a conta da oferta.
 *
 * É a resposta à pergunta que o motorista faz em 3 segundos: "isso paga?".
 * Mostra valor, R$/km, R$/h e o veredito — nada além disso. Some sozinho
 * depois de um tempo (a oferta já foi embora) e também no toque.
 */
class OfferCardView(private val context: Context) {

    /**
     * O contexto do serviço de acessibilidade carrega o token da janela de
     * acessibilidade. Usar `applicationContext` aqui quebra com
     * BadTokenException ("token null is not valid").
     */
    private val appContext = context.applicationContext

    private val windowManager =
        context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val handler = Handler(Looper.getMainLooper())

    private var view: View? = null
    private var hideTask: Runnable? = null

    /** Card de exemplo: não é oferta real, então não pode contaminar a leitura. */
    private var previewOnly = false

    fun show(
        offer: ParsedOffer,
        verdict: Verdict,
        appLabel: String,
        preview: Boolean = false,
    ) {
        hide()
        previewOnly = preview

        val fields = fields()
        val compact = CardLayout.isCompact(fields)
        val card = build(offer, verdict, appLabel, fields, compact)

        val screenWidth = context.resources.displayMetrics.widthPixels
        // O card enxuto ocupa só a largura do texto; o detalhado usa a faixa
        // inteira para alinhar as colunas.
        val width = if (compact) {
            WindowManager.LayoutParams.WRAP_CONTENT
        } else {
            minOf(screenWidth - dp(32), dp(440))
        }

        val layoutParams = WindowManager.LayoutParams(
            width,
            WindowManager.LayoutParams.WRAP_CONTENT,
            windowType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                // O card não pode aparecer na foto do OCR: senão a leitura
                // seguinte interpreta o próprio card como se fosse oferta.
                // A exceção é a prévia dentro do app, que existe justamente
                // para ser vista (e só vive enquanto o Aceita AI está na frente).
                (if (preview) 0 else WindowManager.LayoutParams.FLAG_SECURE),
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            y = dp(64)
        }

        try {
            windowManager.addView(card, layoutParams)
        } catch (error: Throwable) {
            Diag.log(appContext, "card: recusado (${error.javaClass.simpleName}: ${error.message})")
            return
        }

        view = card

        val task = Runnable { hide() }
        hideTask = task
        // O card de oferta do Uber some em ~10s. Ficar mais que isso na tela
        // vira lixo por cima do mapa.
        handler.postDelayed(task, VISIBLE_MS)
    }

    fun hide() {
        hideTask?.let { handler.removeCallbacks(it) }
        hideTask = null
        previewOnly = false
        val current = view ?: return
        view = null
        try {
            windowManager.removeView(current)
        } catch (_: Exception) {
            // já saiu
        }
    }

    /**
     * Some se o que está na tela é só o card de exemplo (o app saiu da
     * frente: a partir daí ele poderia ser lido pelo OCR como oferta real).
     */
    fun hideIfPreview() {
        if (previewOnly) hide()
    }

    // --------------------------------------------------------------- layout

    private fun build(
        offer: ParsedOffer,
        verdict: Verdict,
        appLabel: String,
        fields: Set<CardField>,
        compact: Boolean,
    ): View {
        val root = if (compact) {
            compactCard(offer, verdict, fields)
        } else {
            fullCard(offer, verdict, appLabel, fields)
        }

        root.contentDescription = describe(appLabel, offer, verdict, fields)
        root.setOnClickListener { hide() }

        return root
    }

    /** O card de três linhas: cabeçalho, manchete e os números soltos. */
    private fun fullCard(
        offer: ParsedOffer,
        verdict: Verdict,
        appLabel: String,
        fields: Set<CardField>,
    ): View {
        val accent = colorOf(verdict.overall)

        val root = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(16), dp(14), dp(16), dp(14))
            background = GradientDrawable().apply {
                cornerRadius = dp(20).toFloat()
                setColor(0xFF11171F.toInt())
                setStroke(dp(1), withAlpha(accent, 0.55f))
            }
            // O card não tem controles: é leitura, não interface.
            isClickable = true
        }

        val header = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        header.addView(
            text(appLabel.uppercase(Locale("pt", "BR")), size = 11f, color = muted(), bold = true),
            weight(1f),
        )
        if (CardField.VERDICT in fields) {
            header.addView(
                text(verdictText(verdict.overall), size = 11f, color = accent, bold = true),
            )
        }
        root.addView(header)

        // Manchete: o número que decide primeiro. Se o valor está desligado,
        // o próximo mais decisivo assume o lugar — o card nunca fica sem um
        // número grande, e ele não se repete na fileira de baixo.
        val headline = headlineField(fields)
        headline?.let { root.addView(headlineView(it, offer, verdict)) }

        val metrics = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(0, dp(6), 0, 0)
        }
        if (CardField.PER_KM in fields && headline != CardField.PER_KM) {
            metrics.addView(
                metric("R$/km", perKm(verdict.perKm), verdict.perKmGrade),
                weight(1f),
            )
        }
        if (CardField.PER_HOUR in fields && headline != CardField.PER_HOUR) {
            metrics.addView(
                metric("R$/h", perHour(verdict.perHour), verdict.perHourGrade),
                weight(1f),
            )
        }
        if (CardField.PROFIT in fields && headline != CardField.PROFIT) {
            metrics.addView(
                metric("lucro", money(verdict.profit), verdict.profitGrade),
                weight(1f),
            )
        }
        if (metrics.childCount > 0) root.addView(metrics)

        val route = routeLine(offer, fields)
        if (route.isNotEmpty()) {
            root.addView(
                text(route, size = 11f, color = muted()).apply {
                    setPadding(0, dp(10), 0, 0)
                },
            )
        }

        return root
    }

    /**
     * Card enxuto: duas linhas, só da largura do texto.
     *
     * O preset Simples não precisa de cabeçalho nem de manchete grande: R$/km e
     * R$/h ficam do mesmo tamanho na primeira linha (com a nota), e o veredito
     * desce para a segunda. Assim o card fica estreito — os dois números que
     * decidem aparecem sem o valor da oferta empurrando a largura.
     * A cor do veredito vai na tarja da esquerda, que se lê de relance.
     */
    private fun compactCard(
        offer: ParsedOffer,
        verdict: Verdict,
        fields: Set<CardField>,
    ): View {
        val accent = colorOf(verdict.overall)
        // Sem o valor da oferta, R$/km e R$/h são a manchete: mesmo tamanho,
        // em negrito. Com o valor, ele manda e os dois voltam a ser miúdos.
        val hasValue = CardField.VALUE in fields
        val rateSize = if (hasValue) 12f else 18f

        val root = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(12), dp(9), dp(14), dp(9))
            background = GradientDrawable().apply {
                cornerRadius = dp(16).toFloat()
                setColor(0xFF11171F.toInt())
                setStroke(dp(1), withAlpha(accent, 0.55f))
            }
            isClickable = true
        }

        // A tarja cobre as duas linhas: ela é a cor do veredito, não um enfeite.
        root.addView(
            View(context).apply {
                background = GradientDrawable().apply {
                    cornerRadius = dp(2).toFloat()
                    setColor(accent)
                }
            },
            LinearLayout.LayoutParams(dp(3), LinearLayout.LayoutParams.MATCH_PARENT)
                .apply { marginEnd = dp(10) },
        )

        val column = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
        }

        val numbers = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        val headline = headlineField(fields)
        if (headline != null) {
            val (value, color) = when (headline) {
                CardField.PER_KM -> perKm(verdict.perKm) to colorOf(verdict.perKmGrade)
                CardField.PER_HOUR ->
                    perHour(verdict.perHour) to colorOf(verdict.perHourGrade)
                CardField.PROFIT -> money(verdict.profit) to colorOf(verdict.profitGrade)
                else -> money(offer.value) to text()
            }
            numbers.addView(
                text(
                    value,
                    size = if (headline == CardField.VALUE) 20f else rateSize,
                    color = color,
                    bold = true,
                ),
            )
        }

        // O que sobrou da manchete fica colado nela, com a unidade no próprio
        // texto — o rótulo em cima do número era o que dobrava a altura.
        if (CardField.PER_KM in fields && headline != CardField.PER_KM) {
            numbers.addView(
                compactMetric(
                    "${perKm(verdict.perKm)}/km",
                    colorOf(verdict.perKmGrade),
                    rateSize,
                ),
            )
        }
        if (CardField.PER_HOUR in fields && headline != CardField.PER_HOUR) {
            numbers.addView(
                compactMetric(
                    "${perHour(verdict.perHour)}/h",
                    colorOf(verdict.perHourGrade),
                    rateSize,
                ),
            )
        }
        if (CardField.PROFIT in fields && headline != CardField.PROFIT) {
            numbers.addView(
                compactMetric(
                    "lucro ${money(verdict.profit)}",
                    colorOf(verdict.profitGrade),
                    12f,
                ),
            )
        }
        if (CardField.RATING in fields) {
            offer.rating?.let {
                numbers.addView(
                    compactMetric(
                        String.format(Locale("pt", "BR"), "★ %.2f", it),
                        muted(),
                        12f,
                    ),
                )
            }
        }
        column.addView(numbers)

        if (CardField.VERDICT in fields) {
            column.addView(
                text(verdictText(verdict.overall), size = 10f, color = accent, bold = true).apply {
                    letterSpacing = 0.06f
                    setPadding(0, dp(2), 0, 0)
                },
            )
        }

        root.addView(column)

        return root
    }

    private fun compactMetric(
        value: String,
        color: Int,
        size: Float,
        bold: Boolean = size >= 16f,
    ): View =
        text(value, size = size, color = color, bold = bold).apply {
            setPadding(dp(8), 0, 0, 0)
        }

    private fun fields(): Set<CardField> = ReaderBridge.cardFields(context)

    /** Qual número ocupa o lugar grande do card. */
    private fun headlineField(fields: Set<CardField>): CardField? = when {
        CardField.VALUE in fields -> CardField.VALUE
        CardField.PER_KM in fields -> CardField.PER_KM
        CardField.PER_HOUR in fields -> CardField.PER_HOUR
        CardField.PROFIT in fields -> CardField.PROFIT
        else -> null
    }

    private fun headlineView(
        field: CardField,
        offer: ParsedOffer,
        verdict: Verdict,
    ): TextView {
        val (value, color) = when (field) {
            CardField.PER_KM -> perKm(verdict.perKm) to colorOf(verdict.perKmGrade)
            CardField.PER_HOUR ->
                perHour(verdict.perHour) to colorOf(verdict.perHourGrade)
            CardField.PROFIT -> money(verdict.profit) to colorOf(verdict.profitGrade)
            else -> money(offer.value) to text()
        }

        return text(
            value,
            size = if (field == CardField.VALUE) 32f else 26f,
            color = color,
            bold = true,
        ).apply {
            setPadding(0, dp(4), 0, dp(2))
        }
    }

    private fun metric(label: String, value: String, grade: Grade): View {
        val column = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
        }
        column.addView(text(label, size = 10f, color = muted(), bold = false))
        column.addView(text(value, size = 17f, color = colorOf(grade), bold = true))
        return column
    }

    private fun routeLine(offer: ParsedOffer, fields: Set<CardField>): String {
        val parts = ArrayList<String>(4)
        if (CardField.DISTANCE in fields) {
            if (offer.pickupKm != null && offer.tripKm != null) {
                parts.add("busca ${km(offer.pickupKm)} km")
                parts.add("viagem ${km(offer.tripKm)} km")
            } else {
                parts.add("${km(offer.totalKm)} km")
            }
        }
        if (CardField.TIME in fields) parts.add("${offer.totalMin} min")
        if (CardField.UBER in fields) {
            offer.uberPerKm?.let { parts.add("Uber: ${perKm(it)}") }
        }
        if (CardField.RATING in fields) {
            offer.rating?.let { parts.add(String.format(Locale("pt", "BR"), "★ %.2f", it)) }
        }
        return parts.joinToString(" · ")
    }

    /**
     * O que o leitor de tela fala. Sem isso, um card montado só com números
     * vira uma sequência solta de valores para quem usa TalkBack.
     */
    private fun describe(
        appLabel: String,
        offer: ParsedOffer,
        verdict: Verdict,
        fields: Set<CardField>,
    ): String {
        val parts = ArrayList<String>(6)
        if (CardField.VERDICT in fields) parts.add(verdictText(verdict.overall))
        if (CardField.VALUE in fields) parts.add(money(offer.value))
        if (CardField.PER_KM in fields) parts.add("${perKm(verdict.perKm)} por km")
        if (CardField.PER_HOUR in fields) parts.add("${perHour(verdict.perHour)} por hora")
        if (CardField.PROFIT in fields) parts.add("lucro ${money(verdict.profit)}")
        return "$appLabel: " + parts.joinToString(", ")
    }

    private fun text(value: String, size: Float, color: Int, bold: Boolean = false): TextView =
        TextView(context).apply {
            this.text = value
            setTextColor(color)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, size)
            if (bold) typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            includeFontPadding = false
        }

    private fun weight(value: Float): LinearLayout.LayoutParams =
        LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, value)

    // --------------------------------------------------------------- apoio

    private fun windowType(): Int = if (Settings.canDrawOverlays(context)) {
        WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
    } else {
        WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY
    }

    private fun money(value: Double): String =
        "R$ " + String.format(Locale("pt", "BR"), "%.2f", value)

    private fun perKm(value: Double): String =
        "R$ " + String.format(Locale("pt", "BR"), "%.2f", value)

    private fun perHour(value: Double): String =
        "R$ " + String.format(Locale("pt", "BR"), "%.0f", value)

    private fun km(value: Double): String =
        String.format(Locale("pt", "BR"), "%.1f", value)

    private fun verdictText(grade: Grade): String = when (grade) {
        Grade.GOOD -> "VALE A PENA"
        Grade.AVERAGE -> "NO LIMITE"
        Grade.BAD -> "RECUSAR"
    }

    private fun colorOf(grade: Grade): Int = when (grade) {
        Grade.GOOD -> 0xFF3DDC97.toInt()
        Grade.AVERAGE -> 0xFFFFB020.toInt()
        Grade.BAD -> 0xFFFF5A5F.toInt()
    }

    private fun text(): Int = 0xFFE9EFF5.toInt()

    private fun muted(): Int = 0xFF8B9AAB.toInt()

    private fun withAlpha(color: Int, alpha: Float): Int =
        Color.argb((alpha * 255).toInt(), Color.red(color), Color.green(color), Color.blue(color))

    private fun dp(value: Int): Int =
        (value * context.resources.displayMetrics.density).toInt()

    companion object {
        private const val VISIBLE_MS = 14_000L
    }
}
