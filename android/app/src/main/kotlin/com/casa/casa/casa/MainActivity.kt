package com.casa.casa.casa

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.media.AudioAttributes
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity

/**
 * Même base que le projet de référence (FlutterActivity simple).
 * FlutterFragmentActivity + enableEdgeToEdge() côté natif a été relié à des fermetures
 * immédiates sur certains appareils ; le bord à bord reste géré dans [lib/main.dart]
 * via SystemChrome.setEnabledSystemUIMode(edgeToEdge).
 */
class MainActivity : FlutterActivity() {

  companion object {
    /// Utiliser cet ID dans OneSignal (Android Notification Category / android_channel_id).
    const val CASANAYO_DEFAULT_CHANNEL_ID = "casanayo_default"
  }

  override fun onCreate(savedInstanceState: android.os.Bundle?) {
    super.onCreate(savedInstanceState)
    createCasaNayoNotificationChannel()
  }

  private fun createCasaNayoNotificationChannel() {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

    val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    val existing = nm.getNotificationChannel(CASANAYO_DEFAULT_CHANNEL_ID)
    if (existing != null) return

    val channel = NotificationChannel(
      CASANAYO_DEFAULT_CHANNEL_ID,
      "CasaNayo",
      NotificationManager.IMPORTANCE_HIGH
    ).apply {
      description = "Notifications CasaNayo (réservations, messages, alertes)"
      enableVibration(true)
      setShowBadge(true)

      val attrs = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_NOTIFICATION)
        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
        .build()
      setSound(Settings.System.DEFAULT_NOTIFICATION_URI, attrs)
    }

    nm.createNotificationChannel(channel)
  }
}
