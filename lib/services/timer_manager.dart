import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/app_limit.dart';
import 'usage_tracker.dart';

class TimerManager extends ChangeNotifier {
  List<Map<dynamic, dynamic>> _installedApps = [];
  List<AppLimit> _blockedApps = [];
  bool _isLoadingApps = false;
  bool _isTrackingActive = false;
  
  bool _hasUsagePermission = false;
  bool _hasAccessibilityPermission = false;
  bool _hasNotificationPermission = false;
  
  Timer? _pollingTimer;

  List<Map<dynamic, dynamic>> get installedApps => _installedApps;
  List<AppLimit> get blockedApps => _blockedApps;
  bool get isLoadingApps => _isLoadingApps;
  bool get isTrackingActive => _isTrackingActive;
  
  bool get hasUsagePermission => _hasUsagePermission;
  bool get hasAccessibilityPermission => _hasAccessibilityPermission;
  bool get hasNotificationPermission => _hasNotificationPermission;

  TimerManager() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      init();
    });
  }

  Future<void> init() async {
    await checkPermissions();
    await loadInstalledApps();
    await loadUsageStats();
    await checkServiceStatus();
    
    // Start periodic polling for usage stats updates
    startPolling();
  }

  void startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      loadUsageStats();
      checkServiceStatus();
    });
  }

  void stopPolling() {
    _pollingTimer?.cancel();
  }

  Future<void> checkServiceStatus() async {
    final running = await UsageTracker.isServiceRunning();
    if (_isTrackingActive != running) {
      _isTrackingActive = running;
      notifyListeners();
    }
  }

  Future<void> checkPermissions() async {
    _hasUsagePermission = await UsageTracker.checkUsageStatsPermission();
    _hasAccessibilityPermission = await UsageTracker.isAccessibilityServiceEnabled();
    
    final status = await Permission.notification.status;
    _hasNotificationPermission = status.isGranted;
    
    notifyListeners();
  }

  Future<void> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    _hasNotificationPermission = status.isGranted;
    notifyListeners();
  }

  Future<void> loadInstalledApps() async {
    _isLoadingApps = true;
    notifyListeners();
    
    _installedApps = await UsageTracker.getInstalledApps();
    
    _isLoadingApps = false;
    notifyListeners();
  }

  Future<void> loadUsageStats() async {
    final stats = await UsageTracker.getUsageStats();
    final List<AppLimit> updatedList = [];
    
    stats.forEach((pkgKey, data) {
      final pkg = pkgKey as String;
      final details = data as Map<dynamic, dynamic>;
      
      final limitMillis = details['limit'] as int? ?? (30 * 60 * 1000);
      final usedMillis = details['used'] as int? ?? 0;
      final lastBlockedMillis = details['lastBlocked'] as int? ?? 0;
      final cooldownMillis = details['cooldown'] as int? ?? (4 * 60 * 60 * 1000);
      
      final appName = _installedApps.firstWhere(
        (a) => a['packageName'] == pkg,
        orElse: () => {'name': pkg.split('.').last},
      )['name'] as String;

      updatedList.add(AppLimit(
        packageName: pkg,
        appName: appName,
        limitMinutes: limitMillis ~/ (60 * 1000),
        cooldownMinutes: cooldownMillis ~/ (60 * 1000),
        usedMillis: usedMillis,
        lastBlockedMillis: lastBlockedMillis,
      ));
    });
    
    _blockedApps = updatedList;
    notifyListeners();
  }

  Future<void> saveSettings() async {
    final packages = _blockedApps.map((a) => a.packageName).toList();
    final Map<String, int> limits = {
      for (var app in _blockedApps) app.packageName: app.limitMinutes
    };
    final Map<String, int> cooldowns = {
      for (var app in _blockedApps) app.packageName: app.cooldownMinutes
    };
    
    await UsageTracker.saveBlockedApps(
      packages: packages,
      limits: limits,
      cooldowns: cooldowns,
    );
    await loadUsageStats();
  }

  Future<void> toggleAppBlock(Map<dynamic, dynamic> app, bool enable) async {
    final pkg = app['packageName'] as String;
    final name = app['name'] as String;
    
    if (enable) {
      // Add default limit (30 mins, 240 mins cooldown)
      _blockedApps.add(AppLimit(
        packageName: pkg,
        appName: name,
        limitMinutes: 30,
        cooldownMinutes: 240,
      ));
    } else {
      _blockedApps.removeWhere((a) => a.packageName == pkg);
    }
    
    await saveSettings();
  }

  Future<void> updateAppLimit(String packageName, int limitMinutes, int cooldownMinutes) async {
    final index = _blockedApps.indexWhere((a) => a.packageName == packageName);
    if (index != -1) {
      _blockedApps[index] = _blockedApps[index].copyWith(
        limitMinutes: limitMinutes,
        cooldownMinutes: cooldownMinutes,
      );
      await saveSettings();
    }
  }

  Future<void> toggleTrackingService(bool start) async {
    if (start) {
      await UsageTracker.startTracking();
      _isTrackingActive = true;
    } else {
      await UsageTracker.stopTracking();
      _isTrackingActive = false;
    }
    notifyListeners();
  }

  Future<void> resetAppUsage(String packageName) async {
    await UsageTracker.resetUsageForApp(packageName);
    await loadUsageStats();
  }

  Future<void> forceResetAll() async {
    await UsageTracker.clearAllStats();
    await loadUsageStats();
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
