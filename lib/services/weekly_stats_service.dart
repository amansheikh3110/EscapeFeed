import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_limit.dart';

class DayUsage {
  final DateTime date;
  final int ms;
  const DayUsage({required this.date, required this.ms});

  static const _labels = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
  String get dayLabel => _labels[date.weekday - 1];

  bool get isToday {
    final n = DateTime.now();
    return date.year == n.year && date.month == n.month && date.day == n.day;
  }
}

class AppWeeklyStats {
  final String packageName;
  final String appName;
  final int limitMs;
  final List<DayUsage> days; // 7 entries, index 0 = 6 days ago, index 6 = today

  const AppWeeklyStats({
    required this.packageName,
    required this.appName,
    required this.limitMs,
    required this.days,
  });

  int get totalMs => days.fold(0, (s, d) => s + d.ms);
  int get maxDayMs =>
      days.isEmpty ? 0 : days.map((d) => d.ms).reduce((a, b) => a > b ? a : b);
  double get avgMs => totalMs / 7;

  // Positive = improving (less usage recently), negative = regressing.
  // Compares avg of last 3 days vs avg of days 1–3 (skips oldest).
  double get trend {
    if (days.length < 7) return 0;
    final recent = (days[4].ms + days[5].ms + days[6].ms) / 3.0;
    final older  = (days[1].ms + days[2].ms + days[3].ms) / 3.0;
    if (older <= 0) return 0;
    return (older - recent) / older;
  }

  int get daysOverLimit =>
      limitMs > 0 ? days.where((d) => d.ms > limitMs).length : 0;
}

class WeeklyStatsService extends ChangeNotifier {
  static const _channel = MethodChannel('com.example.habit/tracker');

  List<AppWeeklyStats> _stats = [];
  bool _loaded = false;

  List<AppWeeklyStats> get stats => _stats;
  bool get loaded => _loaded;

  Future<void> refresh(List<AppLimit> apps) async {
    if (apps.isEmpty) {
      _stats = [];
      _loaded = true;
      notifyListeners();
      return;
    }

    try {
      final packages = apps.map((a) => a.packageName).toList();
      final Map<dynamic, dynamic> raw = await _channel.invokeMethod(
        'getWeeklyUsage',
        {'packages': packages},
      );

      final today = DateTime.now();
      final dates = List.generate(
        7,
        (i) => DateTime(today.year, today.month, today.day)
            .subtract(Duration(days: 6 - i)),
      );

      _stats = apps.map((app) {
        final rawList = raw[app.packageName];
        final dayMs = <int>[];
        if (rawList is List) {
          for (final v in rawList) { dayMs.add(_toInt(v)); }
        }
        while (dayMs.length < 7) { dayMs.add(0); }

        return AppWeeklyStats(
          packageName: app.packageName,
          appName:     app.appName,
          limitMs:     app.limitMillis,
          days: List.generate(
            7, (i) => DayUsage(date: dates[i], ms: dayMs[i]),
          ),
        );
      }).toList();
    } catch (_) {
      // UsageStats not available — leave existing data
    }

    _loaded = true;
    notifyListeners();
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }
}
