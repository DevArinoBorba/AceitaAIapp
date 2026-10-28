package br.com.aceitaai.app

import br.com.aceitaai.app.reader.ReaderBridge
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ReaderBridge.attach(flutterEngine.dartExecutor.binaryMessenger, applicationContext)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        ReaderBridge.detach()
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
