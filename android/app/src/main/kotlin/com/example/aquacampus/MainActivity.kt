package com.example.aquacampus

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.Build
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "aquacampus/alerts"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(
                NotificationChannel("campus_updates", "Private campus updates",
                    NotificationManager.IMPORTANCE_HIGH)
            )
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "startSiren" -> {
                            val uid = call.argument<String>("uid").orEmpty()
                            val id = call.argument<String>("sosId").orEmpty()
                            if (uid.isEmpty() || id.isEmpty()) {
                                result.error("INVALID_SOS", "Missing alarm identity", null)
                            } else {
                                val intent = Intent(this, SosSirenService::class.java)
                                    .setAction(SosSirenService.START)
                                    .putExtra("uid", uid)
                                    .putExtra("sosId", id)
                                ContextCompat.startForegroundService(this, intent)
                                result.success(null)
                            }
                        }
                        "silenceSiren" -> {
                            val uid = call.argument<String>("uid").orEmpty()
                            val intent = Intent(this, SosSirenService::class.java)
                                .setAction(SosSirenService.SILENCE)
                                .putExtra("uid", uid)
                            startService(intent)
                            result.success(null)
                        }
                        "showUpdate" -> {
                            val title = call.argument<String>("title") ?: "Campus update"
                            val description = call.argument<String>("description")
                                ?: "A new update is available."
                            val id = call.argument<Int>("notificationId") ?: 42
                            showUpdate(title, description, id)
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("NOTIFICATION_UNAVAILABLE", error.message, null)
                }
            }
    }

    private fun showUpdate(title: String, message: String, id: Int) {
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            return
        }
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channelId = "campus_updates"
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(
                NotificationChannel(channelId, "Private campus updates",
                    NotificationManager.IMPORTANCE_DEFAULT)
            )
        }
        val builder = if (Build.VERSION.SDK_INT >= 26)
            Notification.Builder(this, channelId) else Notification.Builder(this)
        val notification = builder
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(message)
            .setStyle(Notification.BigTextStyle().bigText(message))
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setAutoCancel(true).build()
        manager.notify(id, notification)
    }
}
