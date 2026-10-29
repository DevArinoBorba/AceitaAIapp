package br.com.aceitaai.app.reader

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Ação "Pausar / Retomar" da notificação do turno.
 *
 * Roda mesmo com o app fechado — é o caso comum: o motorista está no app de
 * corrida e só toca no botão da notificação.
 */
class ReaderActionReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ReaderNotifier.ACTION_TOGGLE) return

        val app = context.applicationContext
        ReaderBridge.ensureContext(app)

        val next = !ReaderBridge.readingEnabled(app)
        ReaderBridge.setReadingEnabled(app, next)

        // Se o serviço está vivo ele redesenha o balão; se não, a notificação
        // já reflete a escolha e a próxima conexão aplica o resto.
        OfferReaderService.instance?.refreshBubble()

        ReaderNotifier.update(
            app,
            if (next) ReaderNotifier.State.READING else ReaderNotifier.State.PAUSED,
        )
        ReaderBridge.onServiceStateChanged()
    }
}
