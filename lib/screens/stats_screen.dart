import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/gamification_service.dart';
import '../models/achievement.dart';
import '../utils/constants.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c  = CtrlColors.of(context);
    final gs = Provider.of<GamificationService>(context);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, c),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
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
            ? [
                BoxShadow(
                    color: const Color(0xFFFF9500).withValues(alpha: 0.15),
                    blurRadius: 20)
              ]
            : null,
      ),
      child: Row(
        children: [
          // Flame + count
          Text(
            hasStreak ? '🔥' : '💤',
            style: const TextStyle(fontSize: 44),
          ),
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
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _subtitle(streak),
                  style: TextStyle(fontSize: 13, color: c.textSub, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _subtitle(int s) {
    if (s == 0)  return 'Stay within your limits today to start a streak.';
    if (s < 3)   return 'Great start! Keep it going.';
    if (s < 7)   return 'You\'re building momentum. Don\'t break it!';
    if (s < 14)  return '7 days of discipline. Iron Will unlocked!';
    if (s < 30)  return 'Two weeks strong. You\'re in the zone.';
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
          // Radial ring
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
                        color: color,
                      ),
                    ),
                    Text(
                      'out of 100',
                      style: TextStyle(fontSize: 11, color: c.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            _label(score),
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _sub(score),
            style: TextStyle(fontSize: 12, color: c.textSub),
            textAlign: TextAlign.center,
          ),
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
          ..color = bgColor
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke);

    if (progress <= 0) return;

    canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = color.withValues(alpha: 0.25)
          ..strokeWidth = strokeWidth + 4
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));

    canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round);
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
      children: achievements.map((a) => _AchievementCard(a: a, c: c)).toList(),
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
        color: unlocked
            ? c.accent.withValues(alpha: 0.07)
            : c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: unlocked
            ? [
                BoxShadow(
                    color: c.accent.withValues(alpha: 0.12),
                    blurRadius: 14)
              ]
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
              color: unlocked ? c.text : c.textMuted,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            a.description,
            style: TextStyle(
                fontSize: 10, color: c.textMuted, height: 1.4),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
