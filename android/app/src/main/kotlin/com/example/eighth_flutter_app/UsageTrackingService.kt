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

    // Foreground app state — persisted between ticks so usage tracks continuously
    private var lastKnownForeground: String? = null
    private var isInitialized = false
    private var lastFullRefreshTime = 0L

    // Debounce block attempts so we don't spam the accessibility service
    private var lastBlockAttemptTime = 0L

    companion object {
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "usage_tracking_channel"
        private const val BLOCK_DEBOUNCE_MS = 2000L
        private const val FULL_REFRESH_INTERVAL_MS = 30_000L
        private const val LOOKBACK_INIT_MS = 30 * 60 * 1000L // 30 min for init
        private const val LOOKBACK_TICK_MS = 3000L           // 3 s for normal ticks
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
            ).apply { description = "Keeps the app blocker running" }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
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
                    val limit       = getAppLimit(currentApp)
                    val cooldown    = getAppCooldown(currentApp)
                    val lastBlocked = getLastBlockedTime(currentApp)
                    val now         = System.currentTimeMillis()
                    val inCooldown  = lastBlocked > 0L && (now - lastBlocked) < cooldown

                    if (inCooldown) {
                        // Still in cooldown — keep blocking
                        if (now - lastBlockAttemptTime > BLOCK_DEBOUNCE_MS) {
                            lastBlockAttemptTime = now
                            blockApp(currentApp)
                        }
                    } else {
                        if (lastBlocked > 0L) {
                            // Cooldown expired — reset for a fresh session
                            resetUsage(currentApp)
                        }
                        val usedNow = getUsedTimeToday(currentApp)
                        if (usedNow >= limit) {
                            markBlockedStart(currentApp)
                            if (now - lastBlockAttemptTime > BLOCK_DEBOUNCE_MS) {
                                lastBlockAttemptTime = now
                                blockApp(currentApp)
                            }
                        } else {
                            incrementUsage(currentApp)
                        }
                    }
                }
                delay(1000)
            }
        }
    }

    /**
     * Returns the package currently in the foreground, or null if the user is on
     * the home screen / launcher.
     *
     * Strategy:
     *  - On first call (or every 30 s): replay the last 30 min of RESUME/PAUSE events
     *    to establish the true current foreground app.
     *  - On subsequent calls: only inspect the last 3 s for state changes.
     *  - Maintains [lastKnownForeground] between ticks so an app that is quietly
     *    running in the foreground continues to accumulate usage (fixes the original
     *    10-second window bug that caused YouTube usage to stop tracking).
     */
    private fun getForegroundPackage(): String? {
        val usm     = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val endTime = System.currentTimeMillis()
        val doFull  = !isInitialized || (endTime - lastFullRefreshTime) > FULL_REFRESH_INTERVAL_MS
        val begin   = endTime - if (doFull) LOOKBACK_INIT_MS else LOOKBACK_TICK_MS

        val events = usm.queryEvents(begin, endTime)
        val ev     = UsageEvents.Event()

        if (doFull) {
            // Replay full window to find the most-recent foreground app
            var latestTs = 0L
            while (events.hasNextEvent()) {
                events.getNextEvent(ev)
                when (ev.eventType) {
                    UsageEvents.Event.ACTIVITY_RESUMED -> {
                        if (ev.timeStamp >= latestTs) {
                            latestTs = ev.timeStamp
                            lastKnownForeground = ev.packageName
                        }
                    }
                    UsageEvents.Event.ACTIVITY_PAUSED -> {
                        if (ev.packageName == lastKnownForeground && ev.timeStamp >= latestTs) {
                            latestTs = ev.timeStamp
                            lastKnownForeground = null
                        }
                    }
                }
            }
            isInitialized        = true
            lastFullRefreshTime  = endTime
        } else {
            // Incremental: only apply changes from the last 3 seconds
            while (events.hasNextEvent()) {
                events.getNextEvent(ev)
                when (ev.eventType) {
                    UsageEvents.Event.ACTIVITY_RESUMED -> lastKnownForeground = ev.packageName
                    UsageEvents.Event.ACTIVITY_PAUSED  -> {
                        if (ev.packageName == lastKnownForeground) lastKnownForeground = null
                    }
                }
            }
        }

        return lastKnownForeground
    }

    private fun isBlockedApp(pkg: String): Boolean =
        (sharedPrefs.getStringSet("blocked_apps", emptySet()) ?: emptySet()).contains(pkg)

    private fun getAppLimit(pkg: String): Long =
        sharedPrefs.getLong("limit_$pkg", 30 * 60 * 1000L)

    private fun getAppCooldown(pkg: String): Long =
        sharedPrefs.getLong("cooldown_$pkg", 4 * 60 * 60 * 1000L)

    private fun getUsedTimeToday(pkg: String): Long =
        sharedPrefs.getLong("used_$pkg", 0L)

    private fun getLastBlockedTime(pkg: String): Long =
        sharedPrefs.getLong("last_blocked_$pkg", 0L)

    private fun incrementUsage(pkg: String) {
        val current = sharedPrefs.getLong("used_$pkg", 0L)
        sharedPrefs.edit().putLong("used_$pkg", current + 1000L).apply()
    }

    private fun resetUsage(pkg: String) {
        sharedPrefs.edit()
            .putLong("used_$pkg", 0L)
            .putLong("last_blocked_$pkg", 0L)
            .apply()
    }

    private fun markBlockedStart(pkg: String) {
        sharedPrefs.edit().putLong("last_blocked_$pkg", System.currentTimeMillis()).apply()
    }

    private fun blockApp(pkg: String) {
        startService(Intent(this, BlockAccessibilityService::class.java)
            .putExtra("block_package", pkg))
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        isRunning = false
        serviceScope.cancel()
        super.onDestroy()
    }
}
