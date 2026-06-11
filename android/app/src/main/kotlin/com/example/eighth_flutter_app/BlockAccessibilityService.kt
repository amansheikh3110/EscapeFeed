package com.example.eighth_flutter_app

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.Toast
import android.view.accessibility.AccessibilityEvent

class BlockAccessibilityService : AccessibilityService() {

    private lateinit var prefs: SharedPreferences

    override fun onServiceConnected() {
        super.onServiceConnected()
        prefs = getSharedPreferences("app_limits", Context.MODE_PRIVATE)
    }

    /**
     * Event-driven enforcement: whenever a window comes to the foreground, check
     * if it belongs to a blocked app that is over-limit or in cooldown.  If so,
     * immediately navigate to the home screen.
     *
     * This is the primary blocking mechanism and fires even if the
     * UsageTrackingService hasn't called blockApp() yet (e.g. user re-opens
     * the app from the Recents tray during a cooldown period).
     */
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val pkg = event.packageName?.toString() ?: return

        // Skip our own app and launcher
        if (pkg == packageName) return

        val blockedApps = prefs.getStringSet("blocked_apps", emptySet()) ?: emptySet()
        if (!blockedApps.contains(pkg)) return

        val used        = prefs.getLong("used_$pkg", 0L)
        val limit       = prefs.getLong("limit_$pkg", 30 * 60 * 1000L)
        val lastBlocked = prefs.getLong("last_blocked_$pkg", 0L)
        val cooldown    = prefs.getLong("cooldown_$pkg", 4 * 60 * 60 * 1000L)
        val now         = System.currentTimeMillis()
        val inCooldown  = lastBlocked > 0L && (now - lastBlocked) < cooldown

        if (inCooldown || used >= limit) {
            performGlobalAction(GLOBAL_ACTION_HOME)
            Toast.makeText(this, "Time's up! App blocked.", Toast.LENGTH_SHORT).show()
        }
    }

    override fun onInterrupt() {}

    /**
     * Fallback path: called from [UsageTrackingService] when the polling loop
     * detects the limit has been exceeded.  Using GLOBAL_ACTION_HOME (not BACK)
     * guarantees the user leaves the app regardless of its internal back-stack.
     */
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.getStringExtra("block_package") != null) {
            performGlobalAction(GLOBAL_ACTION_HOME)
            Toast.makeText(this, "Time's up! App blocked.", Toast.LENGTH_SHORT).show()
        }
        return START_NOT_STICKY
    }
}
