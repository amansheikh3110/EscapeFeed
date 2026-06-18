import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/achievement.dart';
import '../models/app_limit.dart';

class GamificationService extends ChangeNotifier {
  int _streak = 0;
  double _focusScore = 0.0;
  Set<AchievementId> _unlocked = {};
  List<Achievement> _achievements = Achievement.catalog;
  AchievementId? _newUnlock;

  int get streak => _streak;
  double get focusScore => _focusScore;
  List<Achievement> get achievements => _achievements;
  AchievementId? get newUnlock => _newUnlock;

  // Called from HomeScreen whenever the app list refreshes.
  Future<void> refresh(List<AppLimit> apps) async {
    final prefs = await SharedPreferences.getInstance();

    _streak  = prefs.getInt('g_streak') ?? 0;
    _unlocked = (prefs.getStringList('g_achievements') ?? [])
        .map((s) => AchievementId.values.firstWhere(
              (e) => e.name == s,
              orElse: () => AchievementId.firstStep,
            ))
        .toSet();

    await _evaluateStreak(apps, prefs);
    _computeFocusScore(apps);
    _evaluateAchievements();

    notifyListeners();
  }

  // Evaluate streak once per calendar day.
  Future<void> _evaluateStreak(
      List<AppLimit> apps, SharedPreferences prefs) async {
    final today    = _dayStr(DateTime.now());
    final lastDate = prefs.getString('g_last_date') ?? '';
    if (lastDate == today) return;

    final yesterday = _dayStr(DateTime.now().subtract(const Duration(days: 1)));
    final allGood   = apps.isEmpty ||
        apps.every((a) => !a.isInCooldown && a.usageRatio < 1.0);

    _streak = allGood ? ((lastDate == yesterday) ? _streak + 1 : 1) : 0;

    await prefs.setInt('g_streak', _streak);
    await prefs.setString('g_last_date', today);
  }

  void _computeFocusScore(List<AppLimit> apps) {
    if (apps.isEmpty) { _focusScore = 100; return; }
    final avg = apps
        .map((a) => (1.0 - a.usageRatio).clamp(0.0, 1.0))
        .reduce((a, b) => a + b) /
        apps.length;
    _focusScore = (avg * 100).clamp(0, 100);
  }

  void _evaluateAchievements() {
    final before = Set<AchievementId>.from(_unlocked);

    if (_streak >= 1)  _unlocked.add(AchievementId.firstStep);
    if (_streak >= 7)  _unlocked.add(AchievementId.ironWill);
    if (_streak >= 30) _unlocked.add(AchievementId.digitalMonk);
    if (_streak >= 1 && DateTime.now().hour < 12) {
      _unlocked.add(AchievementId.earlyBird);
    }

    final fresh = _unlocked.difference(before);
    _newUnlock = fresh.isEmpty ? null : fresh.first;
    if (fresh.isNotEmpty) _persist();

    _achievements = Achievement.catalog
        .map((a) => a.copyWith(unlocked: _unlocked.contains(a.id)))
        .toList();
  }

  // Called after a successful earn-time exercise.
  Future<void> unlockProblemSolver() async {
    if (_unlocked.contains(AchievementId.problemSolver)) return;
    _unlocked.add(AchievementId.problemSolver);
    _newUnlock = AchievementId.problemSolver;
    _achievements = Achievement.catalog
        .map((a) => a.copyWith(unlocked: _unlocked.contains(a.id)))
        .toList();
    await _persist();
    notifyListeners();
  }

  void clearNewUnlock() => _newUnlock = null;

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        'g_achievements', _unlocked.map((e) => e.name).toList());
  }

  String _dayStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
