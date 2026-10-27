package br.com.copiloto.app.reader

import android.content.Context
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Diário em arquivo.
 *
 * `logcat` não serve para diagnosticar o balão neste aparelho: o MIUI despeja
 * centenas de linhas por segundo e o buffer rotaciona antes de eu conseguir
 * ler. Aqui cada evento é uma linha em
 * `/sdcard/Android/data/br.com.copiloto.app/files/diagnostico.log`.
 */
object Diag {
    private const val FILE = "diagnostico.log"
    private const val MAX_BYTES = 256 * 1024

    private val clock = SimpleDateFormat("HH:mm:ss.SSS", Locale.US)

    fun log(context: Context?, message: String) {
        val app = context?.applicationContext ?: return
        try {
            val dir = app.getExternalFilesDir(null) ?: return
            if (!dir.exists()) dir.mkdirs()
            val file = File(dir, FILE)
            if (file.exists() && file.length() > MAX_BYTES) file.delete()
            file.appendText("${clock.format(Date())} $message\n")
        } catch (_: Exception) {
            // diagnóstico nunca pode derrubar nada
        }
    }
}
