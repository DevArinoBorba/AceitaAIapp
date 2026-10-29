package br.com.aceitaai.app

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import br.com.aceitaai.app.reader.ReaderBridge
import br.com.aceitaai.app.reader.ReaderNotifier
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ReaderBridge.attach(flutterEngine.dartExecutor.binaryMessenger, applicationContext)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ReaderNotifier.ensureChannels(applicationContext)
        requestNotificationPermission()
    }

    /**
     * O painel do turno depende desta permissão no Android 13+.
     *
     * Pedida na primeira abertura, e só ela: é a que permite avisar que a
     * leitura parou no meio do turno. Negada, o app continua funcionando — só
     * perde o aviso.
     */
    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        val granted = checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        if (!granted) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 91)
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        ReaderBridge.detach()
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
