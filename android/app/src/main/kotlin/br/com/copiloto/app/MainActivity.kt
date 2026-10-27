package br.com.copiloto.app

import br.com.copiloto.app.reader.ReaderBridge
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
