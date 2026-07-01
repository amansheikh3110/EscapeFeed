package com.example.eighth_flutter_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.RectF
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.core.app.NotificationCompat
import java.util.Calendar

class BlockAccessibilityService : AccessibilityService() {

    private lateinit var prefs: SharedPreferences
    private lateinit var notifManager: NotificationManager
    private lateinit var windowManager: WindowManager
    private val handler = Handler(Looper.getMainLooper())

    // Updated by onAccessibilityEvent; null = home screen / no known app
    private var currentForegroundPkg: String? = null

    // Which app's session notification is currently showing (null = none)
    private var notifActivePkg: String? = null

    // Friction overlay state
    private var frictionView: View? = null
    private var frictionSecondsLeft = 0
    private var frictionRunnable: Runnable? = null
    private val lastFrictionTimeByPkg = mutableMapOf<String, Long>()

    companion object {
        private const val SESSION_CHANNEL_ID   = "ctrl_session"
        private const val SESSION_NOTIF_ID     = 2001
        private const val FRICTION_DURATION_S  = 5
        private const val FRICTION_COOLDOWN_MS = 60_000L
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
                    dismissSessionNotification()
                    showSessionNotification(pkg)
                    notifActivePkg = pkg
                } else {
                    refreshSessionNotification(pkg)
                }
            } else {
                if (notifActivePkg != null) dismissSessionNotification()
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
            .setWhen(System.currentTimeMillis() + remaining)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            builder.setChronometerCountDown(true)
        }

        return builder.build()
    }

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

    // ── Open count ───────────────────────────────────────────────────────────────

    private fun todayStr(): String {
        val cal = Calendar.getInstance()
        val y = cal.get(Calendar.YEAR)
        val m = cal.get(Calendar.MONTH) + 1
        val d = cal.get(Calendar.DAY_OF_MONTH)
        return "$y-${m.toString().padStart(2, '0')}-${d.toString().padStart(2, '0')}"
    }

    private fun incrementOpenCount(pkg: String) {
        val key = "open_count_${pkg}_${todayStr()}"
        prefs.edit().putInt(key, prefs.getInt(key, 0) + 1).apply()
    }

    private fun getTodayOpenCount(pkg: String): Int =
        prefs.getInt("open_count_${pkg}_${todayStr()}", 0)

    // ── Friction overlay ─────────────────────────────────────────────────────────

    private fun maybeShowFriction(pkg: String) {
        val now = System.currentTimeMillis()
        if (now - (lastFrictionTimeByPkg[pkg] ?: 0L) < FRICTION_COOLDOWN_MS) return
        lastFrictionTimeByPkg[pkg] = now
        showFriction(
            appName   = getAppLabel(pkg),
            openCount = getTodayOpenCount(pkg),
            usedMs    = prefs.getLong("used_$pkg", 0L)
        )
    }

    private fun showFriction(appName: String, openCount: Int, usedMs: Long) {
        dismissFriction()
        val view = createFrictionView(appName, openCount, usedMs)
        frictionView = view
        frictionSecondsLeft = FRICTION_DURATION_S

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        )

        try {
            windowManager.addView(view, params)
            scheduleFrictionTick(view)
        } catch (_: Exception) {
            frictionView = null
        }
    }

    private fun scheduleFrictionTick(view: View) {
        val r = Runnable {
            if (frictionView !== view) return@Runnable
            frictionSecondsLeft--
            if (frictionSecondsLeft <= 0) {
                dismissFriction()
                return@Runnable
            }
            (view.findViewWithTag("ring") as? FrictionRingView)?.let { ring ->
                ring.setCountdown(frictionSecondsLeft, FRICTION_DURATION_S)
                ring.invalidate()
            }
            scheduleFrictionTick(view)
        }
        frictionRunnable = r
        handler.postDelayed(r, 1000)
    }

    private fun dismissFriction() {
        frictionRunnable?.let { handler.removeCallbacks(it) }
        frictionRunnable = null
        val v = frictionView ?: return
        frictionView = null
        try { windowManager.removeView(v) } catch (_: Exception) {}
    }

    private fun createFrictionView(appName: String, openCount: Int, usedMs: Long): View {
        val dp = resources.displayMetrics.density
        fun Int.px() = (this * dp).toInt()

        val root = FrameLayout(this).apply {
            setBackgroundColor(0xE6000000.toInt())
            isClickable = true
        }

        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            background = GradientDrawable().apply {
                setColor(0xFF1C1C1E.toInt())
                cornerRadius = 24 * dp
            }
            setPadding(28.px(), 32.px(), 28.px(), 28.px())
            gravity = Gravity.CENTER_HORIZONTAL
        }

        card.addView(TextView(this).apply {
            text = appName
            textSize = 22f
            setTextColor(0xFFF2F2F7.toInt())
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
        })

        card.addView(spaceView(10.px()))

        card.addView(TextView(this).apply {
            text = "opened $openCount times today"
            textSize = 15f
            setTextColor(0xFFA78BFA.toInt())
            gravity = Gravity.CENTER
        })

        card.addView(spaceView(5.px()))

        card.addView(TextView(this).apply {
            text = "${formatTime(usedMs)} used today"
            textSize = 13f
            setTextColor(0xFF8E8E93.toInt())
            gravity = Gravity.CENTER
        })

        card.addView(spaceView(26.px()))

        val ring = FrictionRingView(this).apply {
            tag = "ring"
            setCountdown(FRICTION_DURATION_S, FRICTION_DURATION_S)
        }
        card.addView(ring, LinearLayout.LayoutParams(72.px(), 72.px()).also {
            it.gravity = Gravity.CENTER_HORIZONTAL
        })

        card.addView(spaceView(14.px()))

        card.addView(TextView(this).apply {
            text = "pause before you scroll"
            textSize = 11f
            setTextColor(0xFF636366.toInt())
            gravity = Gravity.CENTER
            letterSpacing = 0.04f
        })

        root.addView(
            card,
            FrameLayout.LayoutParams(300.px(), FrameLayout.LayoutParams.WRAP_CONTENT, Gravity.CENTER)
        )

        return root
    }

    private fun spaceView(heightPx: Int): View = View(this).apply {
        layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, heightPx)
    }

    // ── Countdown ring view ──────────────────────────────────────────────────────

    inner class FrictionRingView(ctx: Context) : View(ctx) {
        private var secondsLeft = 0
        private var total = 1

        private val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = 0x33FFFFFF
            style = Paint.Style.STROKE
            strokeWidth = 7f
        }
        private val fgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = 0xFFA78BFA.toInt()
            style = Paint.Style.STROKE
            strokeWidth = 7f
            strokeCap = Paint.Cap.ROUND
        }
        private val numPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = 0xFFF2F2F7.toInt()
            textAlign = Paint.Align.CENTER
            typeface = Typeface.DEFAULT_BOLD
        }

        fun setCountdown(left: Int, totalSecs: Int) {
            secondsLeft = left
            total = totalSecs.coerceAtLeast(1)
        }

        override fun onDraw(canvas: Canvas) {
            val cx = width / 2f
            val cy = height / 2f
            val r = minOf(cx, cy) - bgPaint.strokeWidth / 2

            canvas.drawCircle(cx, cy, r, bgPaint)

            val progress = secondsLeft.toFloat() / total
            if (progress > 0f) {
                val oval = RectF(cx - r, cy - r, cx + r, cy + r)
                canvas.drawArc(oval, -90f, 360f * progress, false, fgPaint)
            }

            numPaint.textSize = r * 0.65f
            canvas.drawText(secondsLeft.toString(), cx, cy + numPaint.textSize * 0.38f, numPaint)
        }
    }

    // ── Accessibility lifecycle ──────────────────────────────────────────────────

    override fun onServiceConnected() {
        super.onServiceConnected()
        prefs         = getSharedPreferences("app_limits", Context.MODE_PRIVATE)
        notifManager  = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        createSessionChannel()
        handler.post(blockChecker)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val pkg = event.packageName?.toString() ?: return
        val prev = currentForegroundPkg
        when {
            pkg in systemPackages -> { /* ignore */ }
            pkg in launcherPackages -> {
                dismissFriction()
                currentForegroundPkg = null
            }
            else -> {
                if (pkg != prev) {
                    dismissFriction()
                    if (isTrackedApp(pkg)) {
                        incrementOpenCount(pkg)
                        val shieldOn = prefs.getBoolean("shield_enabled", true)
                        if (shieldOn && !shouldBlock(pkg)) {
                            maybeShowFriction(pkg)
                        }
                    }
                }
                currentForegroundPkg = pkg
            }
        }
    }

    override fun onInterrupt() {}

    override fun onUnbind(intent: Intent?): Boolean {
        handler.removeCallbacks(blockChecker)
        dismissFriction()
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
