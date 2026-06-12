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

    // ── Foreground-app state ────────────────────────────────────────────────────
    // We keep the last-known foreground package as mutable state so that an app
    // which is quietly running in the foreground (no new RESUMED events) continues
    // to accumulate usage time every second.
    private var lastKnownForeground: String? = null
    private var isInitialized       = false
    private var lastFullRefreshTime = 0L

    companion object {
        private const val NOTIFICATION_ID          = 1001
        private const val CHANNEL_ID               = "usage_tracking_channel"
        private const val FULL_REFRESH_INTERVAL_MS = 30_000L  // re-scan every 30 s
        private const val LOOKBACK_INIT_MS         = 30 * 60 * 1000L
        private const val LOOKBACK_TICK_MS         = 3_000L
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
            val ch = NotificationChannel(
                CHANNEL_ID, "Usage Tracking", NotificationManager.IMPORTANCE_LOW
            ).apply { description = "Keeps the app blocker running" }
            getSystemService(NotificationManager::class.java).createNotificationChannel(ch)
        }
    }

    private fun buildNotification(): Notification =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("ctrl. Active")
            .setContentText("Monitoring app usage")
            .setSmallIcon(android.R.drawable.ic_menu_info_details)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

    // ── Main tracking loop ──────────────────────────────────────────────────────
    private fun startTracking() {
        serviceScope.launch {
            while (isRunning) {
                tick()
                delay(1000)
            }
        }
    }

    private fun tick() {
        val pkg = getForegroundPackage() ?: return
        if (!isBlockedApp(pkg)) return

        val limit       = sharedPrefs.getLong("limit_$pkg",        30 * 60 * 1000L)
        val cooldown    = sharedPrefs.getLong("cooldown_$pkg",      4 * 60 * 60 * 1000L)
        val lastBlocked = sharedPrefs.getLong("last_blocked_$pkg",  0L)
        val now         = System.currentTimeMillis()
        val inCooldown  = lastBlocked > 0L && (now - lastBlocked) < cooldown

        if (inCooldown) {
            // Already blocked — nothing more to do; BlockAccessibilityService
            // will keep sending the user home via its own handler loop.
            return
        }

        if (lastBlocked > 0L) {
            // Cooldown just expired — reset for a fresh session
            resetUsage(pkg)
        }

        val used = sharedPrefs.getLong("used_$pkg", 0L)
        if (used >= limit) {
            // Hit the limit right now — stamp the block start time so that
            // BlockAccessibilityService.shouldBlock() returns true from this
            // point on and navigates the user home.
            sharedPrefs.edit()
                .putLong("last_blocked_$pkg", now)
                .apply()
        } else {
            sharedPrefs.edit()
                .putLong("used_$pkg", used + 1000L)
                .apply()
        }
    }

    // ── Foreground-package detection ────────────────────────────────────────────
    /**
     * Returns the package name of the app currently in the foreground, or null
     * if the launcher / home screen is visible.
     *
     * Algorithm:
     *  • On the first call and every 30 s, replay the last 30 minutes of
     *    ACTIVITY_RESUMED / ACTIVITY_PAUSED events to re-establish ground truth.
     *  • On every other call, inspect only the last 3 seconds for changes and
     *    update [lastKnownForeground] accordingly.
     *  • Keeping the state between calls means an app that has been running
     *    without any new events continues to be detected and tracked.
     */
    private fun getForegroundPackage(): String? {
        val usm     = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val endTime = System.currentTimeMillis()
        val doFull  = !isInitialized || (endTime - lastFullRefreshTime) > FULL_REFRESH_INTERVAL_MS
        val begin   = endTime - if (doFull) LOOKBACK_INIT_MS else LOOKBACK_TICK_MS

        val events = usm.queryEvents(begin, endTime)
        val ev     = UsageEvents.Event()

        if (doFull) {
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
            isInitialized       = true
            lastFullRefreshTime = endTime
        } else {
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

    private fun resetUsage(pkg: String) {
        sharedPrefs.edit()
            .putLong("used_$pkg",          0L)
            .putLong("last_blocked_$pkg",  0L)
            .apply()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        isRunning = false
        serviceScope.cancel()
        super.onDestroy()
    }
}
