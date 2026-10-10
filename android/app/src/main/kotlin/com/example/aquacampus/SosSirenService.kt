package com.example.aquacampus

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.IBinder
import java.util.concurrent.CopyOnWriteArraySet

/// Local foreground alarm with Android's alarm tone on a loop.
/// Dismissing a normal notification does not acknowledge an incident.
class SosSirenService : Service() {
    companion object {
        const val START = "aquacampus.START_SOS"
        const val SILENCE = "aquacampus.SILENCE_SOS"
        const val CHANNEL_ID = "aquacampus_sos_siren"
        private const val NOTIFICATION_ID = 94011
    }
    private val activeIds = CopyOnWriteArraySet<String>()
    private var userId = ""
    private var player: MediaPlayer? = null

    private val prefs get() = getSharedPreferences("aqua_siren_private", Context.MODE_PRIVATE)

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            SILENCE -> {
                val requestUid = intent.getStringExtra("uid")
                // The action comes from the private on-device notification,
                // and is allowed only for the active siren identity.
                if (requestUid != null && requestUid != userId) return START_STICKY
                for (id in activeIds) prefs.edit().putBoolean("muted:${userId}:$id", true).apply()
                activeIds.clear()
                prefs.edit().remove("pendingUid").remove("pendingIds").apply()
                stopTone()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }
            START -> {
                val nextUid = intent.getStringExtra("uid").orEmpty()
                val id = intent.getStringExtra("sosId").orEmpty()
                if (nextUid.isEmpty() || id.isEmpty() ||
                    prefs.getBoolean("muted:$nextUid:$id", false)) {
                    if (activeIds.isEmpty()) stopSelf()
                    return START_NOT_STICKY
                }
                if (userId.isNotEmpty() && userId != nextUid) {
                    activeIds.clear()
                    stopTone()
                }
                userId = nextUid
                activeIds.add(id)
            }
            else -> {
                // After process recovery, resume pending alarms unless a
                // worker explicitly silenced them on this phone.
                userId = prefs.getString("pendingUid", "").orEmpty()
                activeIds.addAll(prefs.getStringSet("pendingIds", emptySet()).orEmpty())
                if (userId.isEmpty() || activeIds.isEmpty()) {
                    stopSelf()
                    return START_NOT_STICKY
                }
            }
        }
        prefs.edit().putString("pendingUid", userId)
            .putStringSet("pendingIds", activeIds.toSet()).apply()
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "Water worker emergency siren",
                NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Audible SOS alarm: water worker must silence it"
                setSound(null, null)
            }
        )
        val stopIntent = Intent(this, SosSirenService::class.java)
            .setAction(SILENCE).putExtra("uid", userId)
        val stopPending = PendingIntent.getService(this, 42, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val openPending = PendingIntent.getActivity(this, 43,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26)
            Notification.Builder(this, CHANNEL_ID) else Notification.Builder(this)
        val note = builder.setContentTitle("WATER EMERGENCY · SOS")
            .setContentText("Worker siren is active. Silence only after acknowledging.")
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentIntent(openPending)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setOngoing(true)
            .setCategory(Notification.CATEGORY_ALARM)
            .addAction(Notification.Action.Builder(
                android.R.drawable.ic_media_pause, "Silence siren", stopPending).build())
            .build()
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(NOTIFICATION_ID, note,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        } else {
            startForeground(NOTIFICATION_ID, note)
        }
        if (player == null) startTone()
        return START_STICKY
    }

    private fun startTone() {
        try {
            val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            val mediaPlayer = MediaPlayer.create(this, uri)
            if (mediaPlayer != null) {
                mediaPlayer.isLooping = true
                mediaPlayer.start()
                player = mediaPlayer
            }
        } catch (_: Exception) { /* Visual SOS remains when audio unavailable. */ }
    }

    private fun stopTone() {
        try { player?.stop() } catch (_: Exception) {}
        player?.release()
        player = null
    }

    override fun onDestroy() {
        stopTone()
        super.onDestroy()
    }
}
