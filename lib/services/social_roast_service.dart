import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppRoast {
  final String package;
  final String name;
  final String emoji;
  final int usageMs;
  final int level; // 0 = no use, 1–5 escalating shame
  final String roast;

  const AppRoast({
    required this.package,
    required this.name,
    required this.emoji,
    required this.usageMs,
    required this.level,
    required this.roast,
  });

  bool get hasUsage => usageMs > 0;

  String get usageLabel {
    final s = usageMs ~/ 1000;
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    if (m > 0) return '${m}m';
    return '<1m';
  }

  // Fraction of 4-hour ceiling, for progress bars
  double get barRatio => (usageMs / (4 * 3600 * 1000)).clamp(0.0, 1.0);
}

class SocialRoastService extends ChangeNotifier {
  static const _channel = MethodChannel('com.example.habit/tracker');

  // (packageName, displayName, emoji)
  static const List<(String, String, String)> _apps = [
    ('com.google.android.youtube',   'YouTube',   '📺'),
    ('com.instagram.android',        'Instagram', '📸'),
    ('com.zhiliaoapp.musically',     'TikTok',    '🎵'),
    ('com.snapchat.android',         'Snapchat',  '👻'),
    ('com.facebook.katana',          'Facebook',  '👤'),
  ];

  // Level thresholds in ms: ms < threshold[i] → level i+1
  static const List<int> _thresholds = [
       15 * 60 * 1000,  // L1 < 15 min
       45 * 60 * 1000,  // L2 < 45 min
    2 * 60 * 60 * 1000, // L3 < 2 h
    4 * 60 * 60 * 1000, // L4 < 4 h
    // L5 ≥ 4 h
  ];

  // Roast messages indexed by [level] (index 0 = unused)
  static const Map<String, List<String>> _messages = {
    'com.google.android.youtube': [
      '',
      'Barely opened YouTube. The algorithm hasn\'t fully locked on to you today.',
      'Half an hour on YouTube. You\'ve watched enough thumbnails to last a normal person a week.',
      'Over an hour on YouTube. You\'ve consumed more content today than you\'ll produce in a lifetime. Touch grass.',
      'Multiple hours deep in YouTube. You ARE the algorithm\'s favourite lab rat — clinically cringe-optimised. Go outside now.',
      'FOUR PLUS HOURS on YouTube. Mr. Beast knows your psychology better than you do. Get off the phone and find a window.',
    ],
    'com.instagram.android': [
      '',
      'A quick Instagram scroll. Your sense of self is still recoverable. Barely.',
      'Thirty minutes on Instagram. You\'ve compared yourself to strangers who are also comparing themselves to strangers.',
      'Over an hour on Instagram. The highlight reel isn\'t real. You know this. Yet here you are, still scrolling.',
      'Three hours of Instagram. Your thumb has trained harder than your entire body has this week.',
      'FOUR+ HOURS on Instagram. Mark Zuckerberg sent a fruit basket to your address. You don\'t even know it. Log off.',
    ],
    'com.zhiliaoapp.musically': [
      '',
      'Light TikTok use. You still have a functioning attention span. Protect it like it\'s rare.',
      'Thirty minutes of TikTok. The algorithm has catalogued your humour, fears, and deepest insecurities.',
      'An hour+ of TikTok. Your brain now craves dopamine in 15-second bursts. This is not how brains are supposed to work.',
      'Three hours of TikTok. You are a fully domesticated content consumer. The ByteDance engineers are proud of what they\'ve done to you.',
      'FOUR+ HOURS of TikTok. You have officially become a data point. A very profitable, very sad data point.',
    ],
    'com.snapchat.android': [
      '',
      'A few snaps sent. Streaks maintained, soul intact. For now.',
      'Thirty minutes on Snapchat. You\'ve watched more Stories than you\'ll remember in an hour.',
      'An hour+ on Snapchat. The streaks will not save you. They will never save you.',
      'Three hours on Snapchat. You are more committed to this app\'s streak counter than to any personal goal you\'ve set this year.',
      'FOUR+ HOURS on Snapchat. This is your longest and most consistent relationship. That\'s the roast. That is the whole roast.',
    ],
    'com.facebook.katana': [
      '',
      'A quick Facebook check. Bold choice. You\'ve seen one conspiracy and a birthday reminder.',
      'Thirty minutes on Facebook. You\'ve argued with someone you haven\'t spoken to in 7 years. Perfectly normal.',
      'An hour+ on Facebook. You are voluntarily consuming content that makes you angry. This is a choice you keep making.',
      'Three hours on Facebook. At some point this stops being doom-scrolling and becomes a lifestyle. You\'re there.',
      'FOUR+ HOURS on Facebook. You have discovered that the human capacity for self-inflicted misery is truly boundless.',
    ],
  };

  List<AppRoast> _data = [];
  bool _loaded = false;

  List<AppRoast> get roasts => _data;

  List<AppRoast> get activeRoasts {
    final list = _data.where((r) => r.hasUsage).toList();
    list.sort((a, b) => b.usageMs.compareTo(a.usageMs));
    return list;
  }

  bool get loaded => _loaded;

  int get maxLevel => _data.isEmpty
      ? 0
      : _data.map((r) => r.level).reduce((a, b) => a > b ? a : b);

  AppRoast? get topOffender {
    final active = activeRoasts;
    return active.isEmpty ? null : active.first;
  }

  Future<void> refresh() async {
    try {
      final packages = _apps.map((a) => a.$1).toList();
      final Map<dynamic, dynamic> raw = await _channel.invokeMethod(
        'getSocialMediaUsage',
        {'packages': packages},
      );

      _data = _apps.map((app) {
        final pkg   = app.$1;
        final name  = app.$2;
        final emoji = app.$3;
        final ms    = _toInt(raw[pkg]);
        final lvl   = _computeLevel(ms);
        final msg   = ms > 0 ? (_messages[pkg]?[lvl] ?? '') : '';
        return AppRoast(
          package: pkg,
          name:    name,
          emoji:   emoji,
          usageMs: ms,
          level:   lvl,
          roast:   msg,
        );
      }).toList();

      _loaded = true;
      notifyListeners();
    } catch (_) {
      // Usage Stats not available or permission not granted — silent fail
    }
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  static int _computeLevel(int ms) {
    if (ms <= 0) return 0;
    for (var i = 0; i < _thresholds.length; i++) {
      if (ms < _thresholds[i]) return i + 1;
    }
    return 5;
  }
}
