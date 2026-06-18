import 'package:flutter/services.dart';

class UsageTracker {
  static const MethodChannel _channel = MethodChannel('com.example.habit/tracker');

  static Future<bool> checkUsageStatsPermission() async {
    try {
      final bool granted = await _channel.invokeMethod('checkUsageStatsPermission');
      return granted;
    } on PlatformException catch (_) {
      return false;
    }
  }

  static Future<void> requestUsageStatsPermission() async {
    try {
      await _channel.invokeMethod('requestUsageStatsPermission');
    } on PlatformException catch (_) {
      // Handle error or ignore if intent fails
    }
  }

  static Future<bool> isAccessibilityServiceEnabled() async {
    try {
      final bool enabled = await _channel.invokeMethod('isAccessibilityServiceEnabled');
      return enabled;
    } on PlatformException catch (_) {
      return false;
    }
  }

  static Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } on PlatformException catch (_) {
      // Handle error or ignore if intent fails
    }
  }

  static Future<void> startTracking() async {
    try {
      await _channel.invokeMethod('startTracking');
    } on PlatformException catch (_) {
      // Handle error
    }
  }

  static Future<void> stopTracking() async {
    try {
      await _channel.invokeMethod('stopTracking');
    } on PlatformException catch (_) {
      // Handle error
    }
  }

  static Future<bool> isServiceRunning() async {
    try {
      final bool running = await _channel.invokeMethod('isServiceRunning');
      return running;
    } on PlatformException catch (_) {
      return false;
    }
  }

  static Future<List<Map<dynamic, dynamic>>> getInstalledApps() async {
    try {
      final List<dynamic> apps = await _channel.invokeMethod('getInstalledApps');
      return apps.cast<Map<dynamic, dynamic>>();
    } on PlatformException catch (_) {
      return [];
    }
  }

  static Future<void> saveBlockedApps({
    required List<String> packages,
    required Map<String, int> limits,
    required Map<String, int> cooldowns,
  }) async {
    try {
      await _channel.invokeMethod('saveBlockedApps', {
        'packages': packages,
        'limits': limits,
        'cooldowns': cooldowns,
      });
    } on PlatformException catch (_) {
      // Handle error
    }
  }

  static Future<Map<dynamic, dynamic>> getUsageStats() async {
    try {
      final Map<dynamic, dynamic> stats = await _channel.invokeMethod('getUsageStats');
      return stats;
    } on PlatformException catch (_) {
      return {};
    }
  }

  static Future<void> resetUsageForApp(String packageName) async {
    try {
      await _channel.invokeMethod('resetUsageForApp', {'packageName': packageName});
    } on PlatformException catch (_) {
      // Handle error
    }
  }

  static Future<void> clearAllStats() async {
    try {
      await _channel.invokeMethod('clearAllStats');
    } on PlatformException catch (_) {
      // Handle error
    }
  }

  // Adds earned minutes to a package's daily allowance (persisted natively so
  // both UsageTrackingService and BlockAccessibilityService see the new limit).
  static Future<void> saveEarnedTime({
    required String packageName,
    required int minutes,
  }) async {
    try {
      await _channel.invokeMethod('saveEarnedTime', {
        'packageName': packageName,
        'milliseconds': minutes * 60 * 1000,
      });
    } on PlatformException catch (_) {
      // ignore
    }
  }
}