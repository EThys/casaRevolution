package com.casa.casa.casa

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ClipData
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.media.AudioAttributes
import android.os.Build
import android.util.Log
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException

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
    const val INVITE_CHANNEL = "casa/invite_image"
  }

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INVITE_CHANNEL)
      .setMethodCallHandler { call, result ->
        val path = call.argument<String>("path")
        if (path.isNullOrBlank()) {
          result.error("bad_args", "Chemin manquant", null)
          return@setMethodCallHandler
        }
        Log.i("CasaInvite", "${call.method} path=$path")
        try {
          when (call.method) {
            "saveToDownloads" -> result.success(savePngToDownloads(path))
            "sharePng" -> {
              sharePng(path)
              result.success(null)
            }
            else -> result.notImplemented()
          }
        } catch (error: Exception) {
          Log.e("CasaInvite", "${call.method} echoue", error)
          result.error("invite_failed", error.message, null)
        }
      }
  }

  private fun sharePng(sourcePath: String) {
    val source = File(sourcePath)
    if (!source.isFile || source.length() < 8) throw IOException("Image introuvable")
    val cached = File(cacheDir, source.name)
    if (source.canonicalPath != cached.canonicalPath) {
      source.copyTo(cached, overwrite = true)
    }
    val uri = FileProvider.getUriForFile(this, "$packageName.invite.fileprovider", cached)
    val send = Intent(Intent.ACTION_SEND).apply {
      type = "image/png"
      putExtra(Intent.EXTRA_STREAM, uri)
      clipData = ClipData.newUri(contentResolver, "Invitation CasaNayo", uri)
      addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }
    val resolved = packageManager.queryIntentActivities(send, PackageManager.MATCH_DEFAULT_ONLY)
    for (info in resolved) {
      grantUriPermission(
        info.activityInfo.packageName,
        uri,
        Intent.FLAG_GRANT_READ_URI_PERMISSION,
      )
    }
    val chooser = Intent.createChooser(send, "Inviter sur CasaNayo").apply {
      addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
      clipData = ClipData.newUri(contentResolver, "Invitation CasaNayo", uri)
    }
    startActivity(chooser)
  }

  private fun savePngToDownloads(sourcePath: String): String {
    val source = File(sourcePath)
    if (!source.isFile || source.length() < 8) throw IOException("Image introuvable")
    val name = "Invitation_CasaNayo_${System.currentTimeMillis()}.png"
    val bytes = source.readBytes()
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      val failures = ArrayList<String>()
      val attempts = listOf(
        Triple(imagesCollection(), Environment.DIRECTORY_PICTURES, "pictures"),
        Triple(imagesCollection(), "${Environment.DIRECTORY_PICTURES}/CasaNayo", "pictures"),
        Triple(downloadsCollection(), Environment.DIRECTORY_DOWNLOADS, "downloads"),
        Triple(downloadsCollection(), "${Environment.DIRECTORY_DOWNLOADS}/CasaNayo", "downloads"),
      )
      for ((collection, relativePath, token) in attempts) {
        for (pending in listOf(true, false)) {
          try {
            insertPng(bytes, name, collection, relativePath, pending)
            return token
          } catch (error: Exception) {
            failures.add(error.message ?: error.javaClass.simpleName)
          }
        }
      }
      throw IOException(failures.joinToString(" | "))
    }
    val dir = File(
      Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES),
      "CasaNayo",
    )
    if (!dir.exists() && !dir.mkdirs()) throw IOException("Dossier inaccessible")
    File(dir, name).writeBytes(bytes)
    return "pictures"
  }

  private fun imagesCollection(): Uri {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
    } else {
      MediaStore.Images.Media.EXTERNAL_CONTENT_URI
    }
  }

  private fun downloadsCollection(): Uri {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
    } else {
      MediaStore.Downloads.EXTERNAL_CONTENT_URI
    }
  }

  private fun insertPng(
    bytes: ByteArray,
    name: String,
    collection: Uri,
    relativePath: String,
    pending: Boolean,
  ) {
    val values = ContentValues().apply {
      put(MediaStore.MediaColumns.DISPLAY_NAME, name)
      put(MediaStore.MediaColumns.MIME_TYPE, "image/png")
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
        put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
        if (pending) put(MediaStore.MediaColumns.IS_PENDING, 1)
      }
    }
    val uri = contentResolver.insert(collection, values) ?: throw IOException("Enregistrement impossible")
    try {
      contentResolver.openOutputStream(uri)?.use { output ->
        output.write(bytes)
        output.flush()
      } ?: throw IOException("Ecriture impossible")
      if (pending && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
        val done = ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) }
        contentResolver.update(uri, done, null, null)
      }
    } catch (error: Exception) {
      runCatching { contentResolver.delete(uri, null, null) }
      throw error
    }
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
