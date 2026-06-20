package com.example.eighth_flutter_app

import android.app.ActivityManager
import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.content.pm.ResolveInfo
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.habit/tracker"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkUsageStatsPermission" -> {
                    val granted = checkUsageStatsPermission()
                    result.success(granted)
                }
                "requestUsageStatsPermission" -> {
                    startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                    result.success(null)
                }
                "isAccessibilityServiceEnabled" -> {
                    val enabled = isAccessibilityServiceEnabled()
                    result.success(enabled)
                }
                "openAccessibilitySettings" -> {
                    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    result.success(null)
                }
                "startTracking" -> {
                    getSharedPreferences("app_limits", Context.MODE_PRIVATE)
                        .edit().putBoolean("shield_enabled", true).apply()
                    val intent = Intent(this, UsageTrackingService::class.java)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(null)
                }
                "stopTracking" -> {
                    stopService(Intent(this, UsageTrackingService::class.java))
                    getSharedPreferences("app_limits", Context.MODE_PRIVATE)
                        .edit().putBoolean("shield_enabled", false).apply()
                    result.success(null)
                }
                "isServiceRunning" -> {
                    val running = isServiceRunning(UsageTrackingService::class.java)
                    result.success(running)
                }
                "getInstalledApps" -> {
                    val apps = getInstalledApps()
                    result.success(apps)
                }
                "saveBlockedApps" -> {
                    val packages = call.argument<List<String>>("packages")!!
                    val limits = call.argument<Map<String, Int>>("limits")!!
                    val cooldowns = call.argument<Map<String, Int>>("cooldowns") ?: emptyMap()
                    saveAppLimits(packages, limits, cooldowns)
                    result.success(null)
                }
                "getUsageStats" -> {
                    val prefs = getSharedPreferences("app_limits", Context.MODE_PRIVATE)
                    val blockedApps = prefs.getStringSet("blocked_apps", emptySet()) ?: emptySet()
                    val stats = mutableMapOf<String, Map<String, Any>>()

                    for (pkg in blockedApps) {
                        val baseLimit   = prefs.getLong("limit_$pkg", 30 * 60 * 1000L)
                        val earnedTime  = prefs.getLong("earned_time_$pkg", 0L)
                        val limit       = baseLimit + earnedTime
                        val used        = prefs.getLong("used_$pkg", 0L)
                        val lastBlocked = prefs.getLong("last_blocked_$pkg", 0L)
                        val cooldown    = prefs.getLong("cooldown_$pkg", 4 * 60 * 60 * 1000L)

                        stats[pkg] = mapOf(
                            "limit" to limit,
                            "used" to used,
                            "lastBlocked" to lastBlocked,
                            "cooldown" to cooldown
                        )
                    }
                    result.success(stats)
                }
                "resetUsageForApp" -> {
                    val pkg = call.argument<String>("packageName")!!
                    val prefs = getSharedPreferences("app_limits", Context.MODE_PRIVATE)
                    prefs.edit().apply {
                        putLong("used_$pkg", 0L)
                        putLong("last_blocked_$pkg", 0L)
                        putLong("earned_time_$pkg", 0L)
                    }.apply()
                    result.success(null)
                }
                "clearAllStats" -> {
                    val prefs = getSharedPreferences("app_limits", Context.MODE_PRIVATE)
                    val blockedApps = prefs.getStringSet("blocked_apps", emptySet()) ?: emptySet()
                    val editor = prefs.edit()
                    for (pkg in blockedApps) {
                        editor.putLong("used_$pkg", 0L)
                        editor.putLong("last_blocked_$pkg", 0L)
                        editor.putLong("earned_time_$pkg", 0L)
                    }
                    editor.apply()
                    result.success(null)
                }
                "saveEarnedTime" -> {
                    val pkg = call.argument<String>("packageName")!!
                    val ms  = call.argument<Int>("milliseconds")!!
                    val prefs = getSharedPreferences("app_limits", Context.MODE_PRIVATE)
                    val current = prefs.getLong("earned_time_$pkg", 0L)
                    prefs.edit().putLong("earned_time_$pkg", current + ms.toLong()).apply()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun checkUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), packageName)
        } else {
            AppOpsManager.MODE_ALLOWED // fallback
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val serviceName = "$packageName/${BlockAccessibilityService::class.java.canonicalName}"
        val enabledServices = Settings.Secure.getString(contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES)
        return enabledServices?.contains(serviceName) == true
    }

    private fun getInstalledApps(): List<Map<String, Any>> {
        val pm = packageManager
        val mainIntent = Intent(Intent.ACTION_MAIN, null).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        val resolveInfos: List<ResolveInfo> = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.queryIntentActivities(mainIntent, PackageManager.ResolveInfoFlags.of(PackageManager.MATCH_ALL.toLong()))
        } else {
            @Suppress("DEPRECATION")
            pm.queryIntentActivities(mainIntent, PackageManager.MATCH_ALL)
        }
        val appList = mutableListOf<Map<String, Any>>()
        
        for (resolveInfo in resolveInfos) {
            val appInfo = resolveInfo.activityInfo.applicationInfo
            val packageName = appInfo.packageName
            val appName = resolveInfo.loadLabel(pm).toString()
            val isSystem = (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0
            
            val map = mapOf(
                "name" to appName,
                "packageName" to packageName,
                "isSystem" to isSystem
            )
            appList.add(map)
        }
        return appList.sortedBy { (it["name"] as String).lowercase() }
    }

    private fun saveAppLimits(packages: List<String>, limits: Map<String, Int>, cooldowns: Map<String, Int>) {
        val prefs = getSharedPreferences("app_limits", Context.MODE_PRIVATE)
        val editor = prefs.edit()
        
        // Save set of blocked packages
        editor.putStringSet("blocked_apps", packages.toSet())
        
        // Save limits and cooldowns for each app
        limits.forEach { (pkg, minutes) ->
            editor.putLong("limit_$pkg", minutes * 60 * 1000L)
            // Initialize used time if not present
            if (!prefs.contains("used_$pkg")) {
                editor.putLong("used_$pkg", 0L)
            }
        }
        
        cooldowns.forEach { (pkg, minutes) ->
            editor.putLong("cooldown_$pkg", minutes * 60 * 1000L)
        }
        
        editor.apply()
    }

    private fun isServiceRunning(serviceClass: Class<*>): Boolean {
        val manager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        @Suppress("DEPRECATION")
        for (service in manager.getRunningServices(Integer.MAX_VALUE)) {
            if (serviceClass.name == service.service.className) {
                return true
            }
        }
        return false
    }
}