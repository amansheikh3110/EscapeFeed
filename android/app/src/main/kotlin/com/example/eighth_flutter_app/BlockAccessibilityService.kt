package com.example.eighth_flutter_app

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Handler
import android.os.Looper
import android.widget.Toast
import android.view.accessibility.AccessibilityEvent

class BlockAccessibilityService : AccessibilityService() {

    private lateinit var prefs: SharedPreferences
    private val handler = Handler(Looper.getMainLooper())

    // Current foreground package, updated via onAccessibilityEvent.
    // Null means we haven't seen any foreground window yet or the last known
    // app went to background.
    private var currentForegroundPkg: String? = null

    // Packages whose window-state-changed events don't represent a real app
    // coming to the foreground (status bar, notification shade, launchers, etc.)
    private val ignoredPackages = setOf(
        "com.android.systemui",
        "android",
        "com.android.launcher",
        "com.android.launcher2",
        "com.android.launcher3",
        "com.google.android.apps.nexuslauncher",
        "com.miui.home",
        "com.sec.android.app.launcher",
        "com.huawei.android.launcher",
        "com.oneplus.launcher"
    )

    /**
     * Runs every second on the main thread.  If the currently-visible app is
     * blocked and over its limit (or inside a cooldown), send the user home.
     */
    private val blockChecker = object : Runnable {
        override fun run() {
            val pkg = currentForegroundPkg
            if (pkg != null && pkg != packageName && shouldBlock(pkg)) {
                performGlobalAction(GLOBAL_ACTION_HOME)
                Toast.makeText(
                    this@BlockAccessibilityService,
                    "Time's up! $pkg blocked.",
                    Toast.LENGTH_SHORT
                ).show()
            }
            handler.postDelayed(this, 1000)
        }
    }

    private fun shouldBlock(pkg: String): Boolean {
        val blockedApps = prefs.getStringSet("blocked_apps", emptySet()) ?: emptySet()
        if (!blockedApps.contains(pkg)) return false

        val used        = prefs.getLong("used_$pkg", 0L)
        val limit       = prefs.getLong("limit_$pkg", 30 * 60 * 1000L)
        val lastBlocked = prefs.getLong("last_blocked_$pkg", 0L)
        val cooldown    = prefs.getLong("cooldown_$pkg", 4 * 60 * 60 * 1000L)
        val now         = System.currentTimeMillis()
        val inCooldown  = lastBlocked > 0L && (now - lastBlocked) < cooldown

        return inCooldown || used >= limit
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        prefs = getSharedPreferences("app_limits", Context.MODE_PRIVATE)
        // Start the active polling loop
        handler.post(blockChecker)
    }

    /**
     * Track which app is currently in the foreground.  We update on every
     * TYPE_WINDOW_STATE_CHANGED event that isn't from a system/launcher package.
     */
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val pkg = event.packageName?.toString() ?: return
        if (pkg !in ignoredPackages) {
            currentForegroundPkg = pkg
        }
    }

    override fun onInterrupt() {}

    override fun onUnbind(intent: Intent?): Boolean {
        handler.removeCallbacks(blockChecker)
        return super.onUnbind(intent)
    }
}
