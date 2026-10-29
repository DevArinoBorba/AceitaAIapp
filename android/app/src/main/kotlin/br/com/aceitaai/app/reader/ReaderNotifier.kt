package br.com.aceitaai.app.reader

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import br.com.aceitaai.app.MainActivity
import br.com.aceitaai.app.R

/**
 * O painel do turno.
 *
 * O card só aparece quando chega oferta; entre uma e outra o motorista não tem
 * nenhum sinal de que a leitura está de pé. E quando o Android ou o MIUI
 * derruba a acessibilidade, nada avisa — ele descobre no fim do dia que rodou
 * o turno inteiro sem veredito.
 *
 * Daí duas notificações com papéis diferentes:
 *
 * - **estado** (canal silencioso, fixa): "Lendo ofertas" ou "Leitura pausada",
 *   com um toque para pausar/retomar. É o sinal de vida.
 * - **aviso** (canal normal, pode ser dispensada): "Leitura parou", com um
 *   toque que cai direto na tela de acessibilidade.
 *
 * A fixa é `setOngoing`: não dá para dispensar sem querer e some quando o
 * serviço realmente acaba.
 */
object ReaderNotifier {

    private const val CHANNEL_STATE = "leitura_estado"
    private const val CHANNEL_ALERT = "leitura_alerta"

    private const val ID_STATE = 4211
    private const val ID_ALERT = 4212

    const val ACTION_TOGGLE = "br.com.aceitaai.app.reader.TOGGLE"

    enum class State { READING, PAUSED, DISCONNECTED }

    /** Estado atual do serviço, como a notificação deve mostrar. */
    fun stateOf(context: Context, connected: Boolean): State = when {
        !connected -> State.DISCONNECTED
        ReaderBridge.readingEnabled(context) -> State.READING
        else -> State.PAUSED
    }

    fun update(context: Context, state: State) {
        val manager = manager(context) ?: return
        ensureChannels(context)
        when (state) {
            State.DISCONNECTED -> {
                manager.cancel(ID_STATE)
                manager.notify(ID_ALERT, alert(context))
            }
            State.READING, State.PAUSED -> {
                manager.cancel(ID_ALERT)
                manager.notify(ID_STATE, stateNotification(context, state == State.READING))
            }
        }
    }

    /** Some com o painel quando o serviço termina (o aviso, se houver, fica). */
    fun clearState(context: Context) {
        manager(context)?.cancel(ID_STATE)
    }

    /**
     * O painel está na tela agora?
     *
     * Serve para atualizar a notificação quando o serviço está fora do ar: se
     * ela já existe, ela é do turno em andamento e não pode ficar dizendo
     * "Lendo ofertas" com a leitura pausada. Se nunca foi criada, não criamos
     * aqui — um painel sem serviço por trás seria mentira.
     */
    fun hasState(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return false
        val manager = manager(context) ?: return false
        return manager.activeNotifications.any { it.id == ID_STATE }
    }

    fun clearAll(context: Context) {
        val manager = manager(context) ?: return
        manager.cancel(ID_STATE)
        manager.cancel(ID_ALERT)
    }

    fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = manager(context) ?: return

        if (manager.getNotificationChannel(CHANNEL_STATE) == null) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_STATE,
                    "Turno",
                    NotificationManager.IMPORTANCE_LOW,
                ).apply {
                    description = "Estado da leitura de ofertas"
                    setShowBadge(false)
                },
            )
        }
        if (manager.getNotificationChannel(CHANNEL_ALERT) == null) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ALERT,
                    "Avisos da leitura",
                    NotificationManager.IMPORTANCE_DEFAULT,
                ).apply {
                    description = "Quando o Android desliga a leitura"
                },
            )
        }
    }

    private fun stateNotification(context: Context, reading: Boolean): Notification {
        val builder = builder(context, CHANNEL_STATE, Notification.PRIORITY_LOW)
            .setSmallIcon(R.drawable.ic_notify)
            .setContentTitle(if (reading) "Lendo ofertas" else "Leitura pausada")
            .setContentText(
                if (reading) {
                    "O card aparece quando chegar oferta."
                } else {
                    "Toque em Retomar para voltar a ler as ofertas."
                },
            )
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setContentIntent(openApp(context))
        builder.addAction(
            0,
            if (reading) "Pausar" else "Retomar",
            toggle(context),
        )
        return builder.build()
    }

    private fun alert(context: Context): Notification =
        builder(context, CHANNEL_ALERT, Notification.PRIORITY_DEFAULT)
            .setSmallIcon(R.drawable.ic_notify)
            .setContentTitle("Leitura parou")
            .setContentText(
                "O Android desligou a acessibilidade. Toque para religar e " +
                    "voltar a ver as ofertas.",
            )
            .setAutoCancel(true)
            .setContentIntent(accessibilitySettings(context))
            .addAction(0, "Religar", accessibilitySettings(context))
            .build()

    private fun builder(
        context: Context,
        channel: String,
        priority: Int,
    ): Notification.Builder {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            return Notification.Builder(context, channel)
        }
        @Suppress("DEPRECATION")
        return Notification.Builder(context).setPriority(priority)
    }

    private fun openApp(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        return PendingIntent.getActivity(context, 2, intent, flags())
    }

    private fun accessibilitySettings(context: Context): PendingIntent {
        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return PendingIntent.getActivity(context, 3, intent, flags())
    }

    private fun toggle(context: Context): PendingIntent {
        val intent = Intent(context, ReaderActionReceiver::class.java)
            .setAction(ACTION_TOGGLE)
        return PendingIntent.getBroadcast(context, 4, intent, flags())
    }

    private fun flags(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

    private fun manager(context: Context): NotificationManager? =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
}
