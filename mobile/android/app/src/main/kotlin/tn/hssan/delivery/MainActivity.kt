package tn.hssan.delivery

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
    }

    /**
     * The channel Firebase shows pushes on while the app is closed (see
     * default_notification_channel_id in AndroidManifest.xml). High
     * importance makes them pop up on screen with a sound, like other
     * delivery apps' offers, instead of only appearing in the shade.
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Commandes et offres",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Le suivi de vos commandes et les codes promo."
        }
        getSystemService(NotificationManager::class.java)?.createNotificationChannel(channel)
    }

    companion object {
        const val CHANNEL_ID = "delivery_hassen"
    }
}
