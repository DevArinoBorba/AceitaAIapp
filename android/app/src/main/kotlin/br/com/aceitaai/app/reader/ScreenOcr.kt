package br.com.aceitaai.app.reader

import android.accessibilityservice.AccessibilityService
import android.graphics.Bitmap
import android.os.Build
import android.view.Display
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
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
                        saveSnapshot(bitmap)
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

    /**
     * Guarda a imagem exata que o OCR recebeu, quando o modo de descoberta
     * está ligado (`Capturar qualquer app`).
     *
     * É a única forma de responder "a oferta estava na foto?": o log diz o
     * que o OCR leu, mas não o que ele deixou de ver. Fica com as 8 últimas.
     */
    private fun saveSnapshot(bitmap: Bitmap) {
        try {
            if (!ReaderBridge.captureAll(service)) return

            val dir = File(service.getExternalFilesDir(null), SNAPSHOT_DIR)
            if (!dir.exists()) dir.mkdirs()

            dir.listFiles()
                ?.sortedBy { it.lastModified() }
                ?.dropLast(MAX_SNAPSHOTS - 1)
                ?.forEach { it.delete() }

            val stamp = SimpleDateFormat("HHmmss", Locale.US).format(Date())
            val file = File(dir, "tela_$stamp.jpg")
            FileOutputStream(file).use { out ->
                bitmap.compress(Bitmap.CompressFormat.JPEG, 85, out)
            }
            Diag.log(service, "ocr: foto guardada ${file.name}")
        } catch (_: Throwable) {
            // diagnóstico não pode derrubar a leitura
        }
    }

    companion object {
        /**
         * Intervalo mínimo entre leituras. A 900 ms responde rápido quando o
         * motorista rejeita uma oferta e já recebe a seguinte, sem sobrecarregar CPU.
         */
        private const val MIN_INTERVAL_MS = 900L

        private const val SNAPSHOT_DIR = "shots"
        private const val MAX_SNAPSHOTS = 8
    }
}
