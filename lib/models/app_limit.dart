class AppLimit {
  final String packageName;
  final String appName;
  final int limitMinutes;
  final int cooldownMinutes;
  final int usedMillis;
  final int lastBlockedMillis;
  final int openCount;

  AppLimit({
    required this.packageName,
    required this.appName,
    this.limitMinutes = 30,
    this.cooldownMinutes = 240, // 4 hours
    this.usedMillis = 0,
    this.lastBlockedMillis = 0,
    this.openCount = 0,
  });

  // Convert limit to milliseconds
  int get limitMillis => limitMinutes * 60 * 1000;

  // Convert cooldown to milliseconds
  int get cooldownMillis => cooldownMinutes * 60 * 1000;

  // Check if this app is currently in cooldown
  bool get isInCooldown {
    if (lastBlockedMillis <= 0) return false;
    final elapsed = DateTime.now().millisecondsSinceEpoch - lastBlockedMillis;
    return elapsed < cooldownMillis;
  }

  // Get remaining usage time in milliseconds (clamped to 0)
  int get remainingUsageMillis {
    final remaining = limitMillis - usedMillis;
    return remaining < 0 ? 0 : remaining;
  }

  // Get remaining cooldown time in milliseconds (clamped to 0)
  int get remainingCooldownMillis {
    if (!isInCooldown) return 0;
    final elapsed = DateTime.now().millisecondsSinceEpoch - lastBlockedMillis;
    final remaining = cooldownMillis - elapsed;
    return remaining < 0 ? 0 : remaining;
  }

  // Percentage of usage (0.0 to 1.0)
  double get usageRatio {
    if (limitMillis <= 0) return 0.0;
    final ratio = usedMillis / limitMillis;
    return ratio > 1.0 ? 1.0 : ratio;
  }

  // Percentage of cooldown elapsed (0.0 to 1.0)
  double get cooldownRatio {
    if (!isInCooldown) return 1.0;
    final elapsed = DateTime.now().millisecondsSinceEpoch - lastBlockedMillis;
    final ratio = elapsed / cooldownMillis;
    return ratio > 1.0 ? 1.0 : (ratio < 0.0 ? 0.0 : ratio);
  }

  AppLimit copyWith({
    String? packageName,
    String? appName,
    int? limitMinutes,
    int? cooldownMinutes,
    int? usedMillis,
    int? lastBlockedMillis,
    int? openCount,
  }) {
    return AppLimit(
      packageName: packageName ?? this.packageName,
      appName: appName ?? this.appName,
      limitMinutes: limitMinutes ?? this.limitMinutes,
      cooldownMinutes: cooldownMinutes ?? this.cooldownMinutes,
      usedMillis: usedMillis ?? this.usedMillis,
      lastBlockedMillis: lastBlockedMillis ?? this.lastBlockedMillis,
      openCount: openCount ?? this.openCount,
    );
  }
}
