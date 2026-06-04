package com.example.eighth_flutter_app

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.os.IBinder
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.*

class UsageTrackingService : Service() {

    private lateinit var sharedPrefs: SharedPreferences
    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var isRunning = true

    companion object {
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "usage_tracking_channel"
    }

    override fun onCreate() {
        super.onCreate()
        sharedPrefs = getSharedPreferences("app_limits", Context.MODE_PRIVATE)
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
        startTracking()
    }

    private fun createNotificationChannel() {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Usage Tracking",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps the app blocker running"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification = NotificationCompat.Builder(this, CHANNEL_ID)
        .setContentTitle("Habit Control Active")
        .setContentText("Monitoring app usage...")
        .setSmallIcon(android.R.drawable.ic_menu_info_details)
        .setPriority(NotificationCompat.PRIORITY_LOW)
        .build()

    private fun startTracking() {
        serviceScope.launch {
            while (isRunning) {
                val currentApp = getForegroundPackage()
                if (currentApp != null && isBlockedApp(currentApp)) {
                    val usedTime = getUsedTimeToday(currentApp)
                    val limit = getAppLimit(currentApp)
                    val cooldown = getAppCooldown(currentApp)
                    val lastBlocked = getLastBlockedTime(currentApp)
                    val currentTime = System.currentTimeMillis()

                    val inCooldown = lastBlocked > 0L && (currentTime - lastBlocked) < cooldown

                    if (inCooldown) {
                        // In cooldown block period: Block the app immediately!
                        blockApp(currentApp)
                    } else {
                        // Cooldown has expired (or was never blocked)
                        if (lastBlocked > 0L) {
                            // Cooldown expired! Reset stats for a new session
                            resetUsage(currentApp)
                        }

                        // Fetch used time again since it might have been reset
                        val currentUsed = getUsedTimeToday(currentApp)
                        if (currentUsed >= limit) {
                            // Just hit the limit: trigger block and start cooldown
                            markBlockedStart(currentApp)
                            blockApp(currentApp)
                        } else {
                            // Still within limit: increment usage
                            incrementUsage(currentApp)
                        }
                    }
                }
                delay(1000) // check every second
            }
        }
    }

    private fun getForegroundPackage(): String? {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val endTime = System.currentTimeMillis()
        val beginTime = endTime - 10000 // last 10 seconds
        val events = usageStatsManager.queryEvents(beginTime, endTime)
        var lastForegroundPackage: String? = null
        var lastEventTime = 0L
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED) {
                if (event.timeStamp > lastEventTime) {
                    lastEventTime = event.timeStamp
                    lastForegroundPackage = event.packageName
                }
            }
        }
        return lastForegroundPackage
    }

    private fun isBlockedApp(pkg: String): Boolean {
        val blockedSet = sharedPrefs.getStringSet("blocked_apps", emptySet()) ?: emptySet()
        return blockedSet.contains(pkg)
    }

    private fun getAppLimit(pkg: String): Long {
        return sharedPrefs.getLong("limit_$pkg", 30 * 60 * 1000L) // default 30 min
    }

    private fun getAppCooldown(pkg: String): Long {
        return sharedPrefs.getLong("cooldown_$pkg", 4 * 60 * 60 * 1000L) // default 4 hours
    }

    private fun getUsedTimeToday(pkg: String): Long {
        return sharedPrefs.getLong("used_$pkg", 0L)
    }

    private fun getLastBlockedTime(pkg: String): Long {
        return sharedPrefs.getLong("last_blocked_$pkg", 0L)
    }

    private fun incrementUsage(pkg: String) {
        val current = sharedPrefs.getLong("used_$pkg", 0L)
        sharedPrefs.edit().putLong("used_$pkg", current + 1000L).apply()
    }

    private fun resetUsage(pkg: String) {
        sharedPrefs.edit().apply {
            putLong("used_$pkg", 0L)
            putLong("last_blocked_$pkg", 0L)
        }.apply()
    }

    private fun markBlockedStart(pkg: String) {
        sharedPrefs.edit().putLong("last_blocked_$pkg", System.currentTimeMillis()).apply()
    }

    private fun blockApp(pkg: String) {
        val intent = Intent(this, BlockAccessibilityService::class.java)
        intent.putExtra("block_package", pkg)
        startService(intent)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        isRunning = false
        serviceScope.cancel()
        super.onDestroy()
    }
}