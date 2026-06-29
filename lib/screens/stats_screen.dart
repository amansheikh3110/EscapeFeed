import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/gamification_service.dart';
import '../services/timer_manager.dart';
import '../services/weekly_stats_service.dart';
import '../models/achievement.dart';
import '../utils/constants.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tm  = Provider.of<TimerManager>(context, listen: false);
      final wss = Provider.of<WeeklyStatsService>(context, listen: false);
      wss.refresh(tm.blockedApps);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c   = CtrlColors.of(context);
    final gs  = Provider.of<GamificationService>(context);
    final wss = Provider.of<WeeklyStatsService>(context);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, c),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StreakCard(streak: gs.streak, c: c),
                    const SizedBox(height: 16),
                    _FocusScoreCard(score: gs.focusScore, c: c),
                    const SizedBox(height: 24),
                    _sectionLabel('ACHIEVEMENTS', c),
                    const SizedBox(height: 10),
                    _AchievementsGrid(achievements: gs.achievements, c: c),
                    const SizedBox(height: 28),
                    _sectionLabel('WEEKLY USAGE', c),
                    const SizedBox(height: 10),
                    _WeeklySection(wss: wss, c: c),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, CtrlColors c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 10, 16, 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: c.textSub),
            onPressed: () => Navigator.pop(context),
          ),
          Text(
            'Stats',
            style: GoogleFonts.inter(
                fontSize: 20, fontWeight: FontWeight.w700, color: c.text),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, CtrlColors c) => Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: c.textMuted,
          letterSpacing: 1.2,
        ),
      );
}

// ── Weekly section ─────────────────────────────────────────────────────────────

class _WeeklySection extends StatelessWidget {
  final WeeklyStatsService wss;
  final CtrlColors c;
  const _WeeklySection({required this.wss, required this.c});

  @override
  Widget build(BuildContext context) {
    if (!wss.loaded) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.border),
        ),
        child: Center(
          child: CircularProgressIndicator(
              strokeWidth: 2, color: c.accent),
        ),
      );
    }

    if (wss.stats.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.border),
        ),
        child: Column(
          children: [
            Icon(Icons.bar_chart_rounded, size: 36, color: c.textMuted),
            const SizedBox(height: 12),
            Text(
              'No apps tracked yet',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: c.text),
            ),
            const SizedBox(height: 6),
            Text(
              'Add apps from the home screen to see your 7-day usage history.',
              style: TextStyle(fontSize: 13, color: c.textSub, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: wss.stats
          .map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _AppUsageChart(stats: s, c: c),
              ))
          .toList(),
    );
  }
}

// ── Animated bar chart ────────────────────────────────────────────────────────

class _AppUsageChart extends StatefulWidget {
  final AppWeeklyStats stats;
  final CtrlColors c;
  const _AppUsageChart({required this.stats, required this.c});

  @override
  State<_AppUsageChart> createState() => _AppUsageChartState();
}

class _AppUsageChartState extends State<_AppUsageChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<Animation<double>> _barAnims;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    _barAnims = List.generate(7, (i) {
      final start = i * 0.055;
      final end   = (start + 0.55).clamp(0.0, 1.0);
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: Interval(start, end, curve: Curves.easeOut),
        ),
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _ctrl.forward());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s   = widget.stats;
    final c   = widget.c;
    // effectiveMax: if all days are under limit, give 15 % headroom above limit.
    final effectiveMax = math.max(
      s.maxDayMs,
      s.limitMs > 0 ? (s.limitMs * 1.15).round() : 1,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(color: c.shadow, blurRadius: 12, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          _ChartHeader(stats: s, c: c),
          const SizedBox(height: 18),

          // ── Bars + limit line ─────────────────────────────────────────────
          SizedBox(
            height: 130,
            child: Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: List.generate(
                    7,
                    (i) => _Bar(
                      day:          s.days[i],
                      effectiveMax: effectiveMax,
                      limitMs:      s.limitMs,
                      accent:       c.accent,
                      anim:         _barAnims[i],
                    ),
                  ),
                ),
                if (s.limitMs > 0 && effectiveMax > 0)
                  _LimitLine(
                    limitMs:      s.limitMs,
                    effectiveMax: effectiveMax,
                  ),
              ],
            ),
          ),

          // ── Day labels ────────────────────────────────────────────────────
          const SizedBox(height: 5),
          Row(
            children: s.days.map((d) {
              return Expanded(
                child: Center(
                  child: Text(
                    d.dayLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight:
                          d.isToday ? FontWeight.w800 : FontWeight.w500,
                      color: d.isToday ? c.accent : c.textMuted,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          // ── Footer chips ──────────────────────────────────────────────────
          if (s.daysOverLimit > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _Chip(
                  label: '${s.daysOverLimit}x over limit',
                  color: kColorDanger,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Chart header ──────────────────────────────────────────────────────────────

class _ChartHeader extends StatelessWidget {
  final AppWeeklyStats stats;
  final CtrlColors c;
  const _ChartHeader({required this.stats, required this.c});

  @override
  Widget build(BuildContext context) {
    final trend      = stats.trend;
    final improving  = trend > 0.05;
    final regressing = trend < -0.05;
    final trendColor = improving
        ? kColorSuccess
        : regressing
            ? kColorDanger
            : c.textMuted;
    final trendIcon  = improving ? '↓' : regressing ? '↑' : '→';
    final trendPct   = '${(trend.abs() * 100).round()}%';

    return Row(
      children: [
        // Avatar
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: c.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: c.accent.withValues(alpha: 0.25)),
          ),
          child: Center(
            child: Text(
              stats.appName.isNotEmpty
                  ? stats.appName[0].toUpperCase()
                  : '?',
              style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: c.accent),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stats.appName,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: c.text),
              ),
              const SizedBox(height: 2),
              Text(
                '${_fmt(stats.totalMs)} total  ·  ${_fmt(stats.avgMs.round())} avg/day',
                style: TextStyle(fontSize: 11, color: c.textSub),
              ),
            ],
          ),
        ),
        if (improving || regressing)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: trendColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: trendColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  trendIcon,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: trendColor),
                ),
                const SizedBox(width: 3),
                Text(
                  trendPct,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: trendColor),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static String _fmt(int ms) {
    final s = ms ~/ 1000;
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    if (m > 0) return '${m}m';
    if (s > 0) return '${s}s';
    return '0m';
  }
}

// ── Single animated bar ───────────────────────────────────────────────────────

class _Bar extends StatelessWidget {
  final DayUsage day;
  final int effectiveMax;
  final int limitMs;
  final Color accent;
  final Animation<double> anim;

  const _Bar({
    required this.day,
    required this.effectiveMax,
    required this.limitMs,
    required this.accent,
    required this.anim,
  });

  @override
  Widget build(BuildContext context) {
    final overLimit = limitMs > 0 && day.ms > limitMs;
    final barColor  = overLimit ? kColorDanger : accent;
    final ratio     = effectiveMax > 0
        ? (day.ms / effectiveMax).clamp(0.0, 1.0)
        : 0.0;
    // Minimum visible sliver for days with any usage
    final minRatio  = day.ms > 0 ? 0.03 : 0.0;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(
          children: [
            // Usage label (today only, above bar)
            SizedBox(
              height: 18,
              child: day.isToday && day.ms > 0
                  ? Center(
                      child: Text(
                        _fmt(day.ms),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: barColor,
                        ),
                      ),
                    )
                  : null,
            ),
            // Bar area
            Expanded(
              child: AnimatedBuilder(
                animation: anim,
                builder: (_, __) {
                  final h =
                      math.max(minRatio, ratio * anim.value);
                  return Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor: h,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              barColor.withValues(
                                  alpha: day.isToday ? 1.0 : 0.45),
                              barColor.withValues(
                                  alpha: day.isToday ? 0.65 : 0.25),
                            ],
                          ),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(5)),
                          boxShadow: day.isToday
                              ? [
                                  BoxShadow(
                                    color: barColor.withValues(alpha: 0.4),
                                    blurRadius: 10,
                                    offset: const Offset(0, -2),
                                  )
                                ]
                              : null,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(int ms) {
    final s = ms ~/ 1000;
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    if (h > 0 && m > 0) return '${h}h${m}m';
    if (h > 0) return '${h}h';
    if (m > 0) return '${m}m';
    return '<1m';
  }
}

// ── Dashed limit line ─────────────────────────────────────────────────────────

class _LimitLine extends StatelessWidget {
  final int limitMs;
  final int effectiveMax;
  const _LimitLine({required this.limitMs, required this.effectiveMax});

  @override
  Widget build(BuildContext context) {
    // Chart total = 130. Label area = 18. Bar area = 112.
    // limitRatio = fraction of bar height the limit occupies.
    final limitRatio = (limitMs / effectiveMax).clamp(0.0, 1.0);
    final topOffset  = 18.0 + 112.0 * (1.0 - limitRatio);

    return Positioned(
      top: topOffset,
      left: 0,
      right: 0,
      child: Row(
        children: [
          Expanded(
            child: CustomPaint(
              painter: _DashPainter(
                  kColorWarning.withValues(alpha: 0.65)),
              size: const Size(double.infinity, 1.5),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'Limit',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: kColorWarning,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  final Color color;
  const _DashPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color      = color
      ..strokeWidth = 1.5
      ..style      = PaintingStyle.stroke;
    var x = 0.0;
    const dw = 5.0;
    const gw = 4.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, 0),
        Offset((x + dw).clamp(0.0, size.width), 0),
        paint,
      );
      x += dw + gw;
    }
  }

  @override
  bool shouldRepaint(_DashPainter o) => o.color != color;
}

// ── Small chip ────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

// ── Streak card ───────────────────────────────────────────────────────────────

class _StreakCard extends StatelessWidget {
  final int streak;
  final CtrlColors c;
  const _StreakCard({required this.streak, required this.c});

  @override
  Widget build(BuildContext context) {
    final hasStreak = streak > 0;
    final color     = hasStreak ? const Color(0xFFFF9500) : c.textMuted;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasStreak
              ? const Color(0xFFFF9500).withValues(alpha: 0.35)
              : c.border,
        ),
        boxShadow: hasStreak
            ? [BoxShadow(
                color: const Color(0xFFFF9500).withValues(alpha: 0.15),
                blurRadius: 20)]
            : null,
      ),
      child: Row(
        children: [
          Text(hasStreak ? '🔥' : '💤',
              style: const TextStyle(fontSize: 44)),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  streak == 1 ? '1 day streak' : '$streak day streak',
                  style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: color),
                ),
                const SizedBox(height: 4),
                Text(_subtitle(streak),
                    style: TextStyle(
                        fontSize: 13, color: c.textSub, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _subtitle(int s) {
    if (s == 0) return 'Stay within your limits today to start a streak.';
    if (s < 3)  return 'Great start! Keep it going.';
    if (s < 7)  return 'You\'re building momentum. Don\'t break it!';
    if (s < 14) return '7 days of discipline. Iron Will unlocked!';
    if (s < 30) return 'Two weeks strong. You\'re in the zone.';
    return 'Digital Monk status. Truly legendary.';
  }
}

// ── Focus Score card ──────────────────────────────────────────────────────────

class _FocusScoreCard extends StatelessWidget {
  final double score;
  final CtrlColors c;
  const _FocusScoreCard({required this.score, required this.c});

  @override
  Widget build(BuildContext context) {
    final color = score >= 75
        ? kColorSuccess
        : score >= 40
            ? kColorWarning
            : kColorDanger;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Text(
            'Focus Score',
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.textSub,
                letterSpacing: 0.5),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(140, 140),
                  painter: _ScoreRingPainter(
                    progress: score / 100,
                    color: color,
                    bgColor: c.border,
                    strokeWidth: 10,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${score.round()}',
                      style: GoogleFonts.inter(
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          color: color),
                    ),
                    Text('out of 100',
                        style:
                            TextStyle(fontSize: 11, color: c.textMuted)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(_label(score),
              style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: color)),
          const SizedBox(height: 6),
          Text(_sub(score),
              style: TextStyle(fontSize: 12, color: c.textSub),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  String _label(double s) {
    if (s >= 90) return 'Excellent!';
    if (s >= 75) return 'Great job!';
    if (s >= 50) return 'Doing okay';
    if (s >= 25) return 'Needs work';
    return 'Off track';
  }

  String _sub(double s) {
    if (s >= 90) return 'You\'re crushing your screen time goals today.';
    if (s >= 75) return 'Most of your limits are well within range.';
    if (s >= 50) return 'Some apps are close to their limits.';
    if (s >= 25) return 'You\'ve used a lot of your allowances today.';
    return 'You\'ve hit or exceeded limits. Time to recharge.';
  }
}

class _ScoreRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color bgColor;
  final double strokeWidth;
  const _ScoreRingPainter(
      {required this.progress,
      required this.color,
      required this.bgColor,
      required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color      = bgColor
          ..strokeWidth = strokeWidth
          ..style      = PaintingStyle.stroke);

    if (progress <= 0) return;

    canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color      = color.withValues(alpha: 0.25)
          ..strokeWidth = strokeWidth + 4
          ..style      = PaintingStyle.stroke
          ..strokeCap  = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));

    canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color      = color
          ..strokeWidth = strokeWidth
          ..style      = PaintingStyle.stroke
          ..strokeCap  = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_ScoreRingPainter o) => o.progress != progress;
}

// ── Achievements grid ─────────────────────────────────────────────────────────

class _AchievementsGrid extends StatelessWidget {
  final List<Achievement> achievements;
  final CtrlColors c;
  const _AchievementsGrid({required this.achievements, required this.c});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.15,
      children:
          achievements.map((a) => _AchievementCard(a: a, c: c)).toList(),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final Achievement a;
  final CtrlColors c;
  const _AchievementCard({required this.a, required this.c});

  @override
  Widget build(BuildContext context) {
    final unlocked = a.unlocked;
    final border   = unlocked
        ? c.accent.withValues(alpha: 0.4)
        : c.border;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: unlocked ? c.accent.withValues(alpha: 0.07) : c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: unlocked
            ? [BoxShadow(
                color: c.accent.withValues(alpha: 0.12), blurRadius: 14)]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                a.emoji,
                style: TextStyle(
                    fontSize: 28,
                    color: unlocked ? null : const Color(0x00000000)),
              ),
              if (!unlocked) ...[
                const SizedBox(width: 2),
                Icon(Icons.lock_rounded, size: 22, color: c.textMuted),
              ],
              const Spacer(),
              if (unlocked)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: kColorSuccess.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Unlocked',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: kColorSuccess),
                  ),
                ),
            ],
          ),
          const Spacer(),
          Text(
            a.name,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: unlocked ? c.text : c.textMuted),
          ),
          const SizedBox(height: 3),
          Text(
            a.description,
            style: TextStyle(fontSize: 10, color: c.textMuted, height: 1.4),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
