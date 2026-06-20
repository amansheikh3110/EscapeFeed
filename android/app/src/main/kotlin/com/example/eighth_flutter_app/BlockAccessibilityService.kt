package com.example.eighth_flutter_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.widget.Toast
import android.view.accessibility.AccessibilityEvent
import androidx.core.app.NotificationCompat

class BlockAccessibilityService : AccessibilityService() {

    private lateinit var prefs: SharedPreferences
    private lateinit var notifManager: NotificationManager
    private val handler = Handler(Looper.getMainLooper())

    // Updated by onAccessibilityEvent; null = home screen / no known app
    private var currentForegroundPkg: String? = null

    // Which app's session notification is currently showing (null = none)
    private var notifActivePkg: String? = null

    companion object {
        private const val SESSION_CHANNEL_ID = "ctrl_session"
        private const val SESSION_NOTIF_ID   = 2001
    }

    // Going to one of these means the user is on the home screen → clear foreground
    private val launcherPackages = setOf(
        "com.android.launcher",
        "com.android.launcher2",
        "com.android.launcher3",
        "com.google.android.apps.nexuslauncher",
        "com.miui.home",
        "com.sec.android.app.launcher",
        "com.huawei.android.launcher",
        "com.oneplus.launcher",
        "com.oppo.launcher",
        "com.vivo.launcher"
    )

    // Pure system chrome – ignore completely (don't update currentForegroundPkg)
    private val systemPackages = setOf("com.android.systemui", "android")

    // ── Main loop (every 1 s) ────────────────────────────────────────────────────
    private val blockChecker = object : Runnable {
        override fun run() {
            // Shield off → lift all enforcement and hide any active notification
            if (!prefs.getBoolean("shield_enabled", true)) {
                if (notifActivePkg != null) dismissSessionNotification()
                handler.postDelayed(this, 1000)
                return
            }

            val pkg = currentForegroundPkg

            // 1. Blocking enforcement
            if (pkg != null && pkg != packageName && shouldBlock(pkg)) {
                performGlobalAction(GLOBAL_ACTION_HOME)
                dismissSessionNotification()
                Toast.makeText(
                    this@BlockAccessibilityService,
                    "Time's up! ${getAppLabel(pkg)} blocked.",
                    Toast.LENGTH_SHORT
                ).show()
                handler.postDelayed(this, 1000)
                return
            }

            // 2. Session countdown notification
            val isTracked = pkg != null && pkg != packageName && isTrackedApp(pkg)
            if (isTracked && pkg != null) {
                if (notifActivePkg != pkg) {
                    // New app came to foreground: cancel previous notification (if any),
                    // show a fresh countdown for the new app.
                    dismissSessionNotification()
                    showSessionNotification(pkg)
                    notifActivePkg = pkg
                }
                // If same app is still in foreground, chronometer updates itself;
                // refresh the body text every tick so "Xm Xs remaining" stays accurate.
                else {
                    refreshSessionNotification(pkg)
                }
            } else {
                // No tracked app in foreground → hide notification
                if (notifActivePkg != null) {
                    dismissSessionNotification()
                }
            }

            handler.postDelayed(this, 1000)
        }
    }

    // ── Blocking helpers ─────────────────────────────────────────────────────────

    private fun shouldBlock(pkg: String): Boolean {
        val blocked = prefs.getStringSet("blocked_apps", emptySet()) ?: emptySet()
        if (!blocked.contains(pkg)) return false
        val used        = prefs.getLong("used_$pkg",          0L)
        val baseLimit   = prefs.getLong("limit_$pkg",         30 * 60 * 1000L)
        val earnedTime  = prefs.getLong("earned_time_$pkg",   0L)
        val limit       = baseLimit + earnedTime
        val lastBlocked = prefs.getLong("last_blocked_$pkg",  0L)
        val cooldown    = prefs.getLong("cooldown_$pkg",      4 * 60 * 60 * 1000L)
        val inCooldown  = lastBlocked > 0L && (System.currentTimeMillis() - lastBlocked) < cooldown
        return inCooldown || used >= limit
    }

    private fun isTrackedApp(pkg: String): Boolean =
        (prefs.getStringSet("blocked_apps", emptySet()) ?: emptySet()).contains(pkg)

    // ── Session notification ─────────────────────────────────────────────────────

    private fun showSessionNotification(pkg: String) {
        if (!notifManager.areNotificationsEnabled()) return
        notifManager.notify(SESSION_NOTIF_ID, buildSessionNotif(pkg))
        notifActivePkg = pkg
    }

    private fun refreshSessionNotification(pkg: String) {
        if (!notifManager.areNotificationsEnabled()) return
        notifManager.notify(SESSION_NOTIF_ID, buildSessionNotif(pkg))
    }

    private fun dismissSessionNotification() {
        notifManager.cancel(SESSION_NOTIF_ID)
        notifActivePkg = null
    }

    private fun buildSessionNotif(pkg: String): android.app.Notification {
        val used       = prefs.getLong("used_$pkg",         0L)
        val baseLimit  = prefs.getLong("limit_$pkg",        30 * 60 * 1000L)
        val earnedTime = prefs.getLong("earned_time_$pkg",  0L)
        val limit      = baseLimit + earnedTime
        val remaining  = (limit - used).coerceAtLeast(0L)
        val label     = getAppLabel(pkg)

        val builder = NotificationCompat.Builder(this, SESSION_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_recent_history)
            .setContentTitle("$label · timer running")
            .setContentText("${formatTime(remaining)} remaining")
            .setOngoing(true)
            .setShowWhen(true)
            .setUsesChronometer(true)
            // setWhen = future timestamp so the chronometer counts down to zero
            .setWhen(System.currentTimeMillis() + remaining)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            builder.setChronometerCountDown(true)
        }

        return builder.build()
    }

    // ── Notification channel ─────────────────────────────────────────────────────

    private fun createSessionChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(
                SESSION_CHANNEL_ID,
                "Active Session Timer",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Live countdown while a tracked app is in use"
                setShowBadge(false)
            }
            notifManager.createNotificationChannel(ch)
        }
    }

    // ── Accessibility lifecycle ──────────────────────────────────────────────────

    override fun onServiceConnected() {
        super.onServiceConnected()
        prefs        = getSharedPreferences("app_limits", Context.MODE_PRIVATE)
        notifManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        createSessionChannel()
        handler.post(blockChecker)
    }

    /**
     * Track which app is in the foreground:
     *  • launcher packages → user went home, clear foreground
     *  • system packages   → ignore (status bar, shade, etc.)
     *  • anything else     → that's the new foreground app
     */
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val pkg = event.packageName?.toString() ?: return
        when {
            pkg in systemPackages   -> { /* ignore */ }
            pkg in launcherPackages -> currentForegroundPkg = null
            else                    -> currentForegroundPkg = pkg
        }
    }

    override fun onInterrupt() {}

    override fun onUnbind(intent: Intent?): Boolean {
        handler.removeCallbacks(blockChecker)
        dismissSessionNotification()
        return super.onUnbind(intent)
    }

    // ── Utility ──────────────────────────────────────────────────────────────────

    private fun getAppLabel(pkg: String): String =
        try {
            packageManager.getApplicationLabel(
                packageManager.getApplicationInfo(pkg, 0)
            ).toString()
        } catch (_: Exception) {
            pkg.substringAfterLast('.')
        }

    private fun formatTime(ms: Long): String {
        val s = ms / 1000
        val h = s / 3600
        val m = (s % 3600) / 60
        val sec = s % 60
        return when {
            h > 0 -> "${h}h ${m}m"
            m > 0 -> "${m}m ${sec}s"
            else  -> "${sec}s"
        }
    }
}
