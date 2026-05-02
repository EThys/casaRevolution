package com.casa.casa.casa

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.media.AudioAttributes
import android.os.Build
import android.provider.Settings
import androidx.activity.enableEdgeToEdge
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity: FlutterFragmentActivity() {

  companion object {
    // Utiliser cet ID dans OneSignal (Android Notification Category / android_channel_id).
    const val CASANAYO_DEFAULT_CHANNEL_ID = "casanayo_default"
  }

  override fun onCreate(savedInstanceState: android.os.Bundle?) {
    // API AndroidX recommandée par Google (Android 15+) pour le bord à bord,
    // à la place des anciens flags View / setSystemUiVisibility.
    enableEdgeToEdge()
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

      // Son par défaut du système. L'utilisateur peut personnaliser ce canal dans les réglages Android.
      val attrs = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_NOTIFICATION)
        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
        .build()
      setSound(Settings.System.DEFAULT_NOTIFICATION_URI, attrs)

      // Pour un son personnalisé CasaNayo:
      // - ajouter un fichier dans android/app/src/main/res/raw/ (ex: casanayo_notify.mp3)
      // - utiliser: Uri.parse("android.resource://" + packageName + "/" + R.raw.casanayo_notify)
      // - puis setSound(customUri, attrs)
    }

    nm.createNotificationChannel(channel)
  }
}
