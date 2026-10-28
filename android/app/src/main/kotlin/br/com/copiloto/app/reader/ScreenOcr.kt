package br.com.copiloto.app.reader

import android.accessibilityservice.AccessibilityService
import android.graphics.Bitmap
import android.os.Build
import android.view.Display
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Lê o texto da tela por imagem, quando a árvore de acessibilidade não entrega.
 *
 * O Uber marca o card de oferta como "não importante para acessibilidade" (ou
 * desenha num container escondido): os nós existem, mas o texto da oferta não
 * aparece no dump — só o mapa. A captura de tela não passa por esse filtro,
 * então o caminho é: `takeScreenshot()` (API 30+, sem pedir permissão) → OCR
 * on-device (ML Kit, funciona offline) → mesmas regras do [OfferParser].
 */
class ScreenOcr(private val service: AccessibilityService) {

    private val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private val busy = AtomicBoolean(false)

    private var lastRunAt = 0L
    private var lastResult: List<String> = emptyList()

    val isSupported: Boolean = Build.VERSION.SDK_INT >= Build.VERSION_CODES.R

    /**
     * Tenta ler a tela agora.
     *
     * @param force ignora o intervalo mínimo (usado no teste manual).
     * @return `false` se a leitura não foi disparada (ocupado ou cedo demais).
     */
    fun read(force: Boolean = false, onLines: (List<String>) -> Unit): Boolean {
        if (!isSupported) return false
        val now = System.currentTimeMillis()
        if (!force && now - lastRunAt < MIN_INTERVAL_MS) return false
        if (!busy.compareAndSet(false, true)) return false

        lastRunAt = now

        try {
            service.takeScreenshot(
                Display.DEFAULT_DISPLAY,
                executor,
                object : AccessibilityService.TakeScreenshotCallback {
                    override fun onSuccess(result: AccessibilityService.ScreenshotResult) {
                        val bitmap = toSoftwareBitmap(result)
                        if (bitmap == null) {
                            finish(onLines, emptyList())
                            return
                        }
                        val image = InputImage.fromBitmap(bitmap, 0)
                        recognizer.process(image)
                            .addOnSuccessListener { text ->
                                val lines = text.textBlocks
                                    .flatMap { block -> block.lines }
                                    .map { line -> line.text.trim() }
                                    .filter { line -> line.isNotEmpty() }
                                finish(onLines, lines)
                            }
                            .addOnFailureListener { finish(onLines, emptyList()) }
                            .addOnCompleteListener { bitmap.recycle() }
                    }

                    override fun onFailure(errorCode: Int) {
                        Diag.log(service, "ocr: falhou codigo=$errorCode")
                        finish(onLines, emptyList())
                    }
                },
            )
        } catch (error: Throwable) {
            Diag.log(service, "ocr: erro ${error.javaClass.simpleName}: ${error.message}")
            busy.set(false)
            return false
        }
        return true
    }

    fun release() {
        recognizer.close()
        executor.shutdown()
    }

    private fun toSoftwareBitmap(result: AccessibilityService.ScreenshotResult): Bitmap? {
        return try {
            val hardware = Bitmap.wrapHardwareBuffer(result.hardwareBuffer, result.colorSpace)
            result.hardwareBuffer.close()
            val software = hardware?.copy(Bitmap.Config.ARGB_8888, false)
            hardware?.recycle()
            software
        } catch (error: Throwable) {
            null
        }
    }

    private fun finish(onLines: (List<String>) -> Unit, lines: List<String>) {
        busy.set(false)
        lastResult = lines
        service.mainExecutor.execute { onLines(lines) }
    }

    companion object {
        /**
         * Intervalo mínimo entre leituras. OCR consome CPU e bateria; a 2,5 s
         * ainda pega qualquer oferta (o card do Uber fica ~10 s na tela).
         */
        private const val MIN_INTERVAL_MS = 2_500L
    }
}
