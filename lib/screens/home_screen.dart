import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/timer_manager.dart';
import '../services/theme_notifier.dart';
import '../services/gamification_service.dart';
import '../models/app_limit.dart';
import '../utils/constants.dart';
import '../services/usage_tracker.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late AnimationController _dotCtrl;
  late Animation<double> _dotOpacity;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _dotOpacity = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _dotCtrl, curve: Curves.easeInOut),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshGamification());
  }

  void _refreshGamification() {
    final tm = Provider.of<TimerManager>(context, listen: false);
    final gs = Provider.of<GamificationService>(context, listen: false);
    gs.refresh(tm.blockedApps);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dotCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final tm = Provider.of<TimerManager>(context, listen: false);
      tm.checkPermissions();
      tm.loadUsageStats();
      tm.checkServiceStatus();
      _refreshGamification();
    }
  }

  String _fmt(int ms) {
    final d = Duration(milliseconds: ms);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final c = CtrlColors.of(context);
    final tm = Provider.of<TimerManager>(context);
    final tn = Provider.of<ThemeNotifier>(context);
    final gs = Provider.of<GamificationService>(context);
    final apps = tm.blockedApps;
    // Notification permission is desirable but not required for tracking to work.
    // Only the two essential permissions gate the shield toggle.
    final isReady = tm.hasUsagePermission && tm.hasAccessibilityPermission;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(c, tn),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isReady) ...[
                      _buildPermissionBanner(c, tm),
                      const SizedBox(height: 16),
                    ],
                    _buildShieldCard(c, tm, isReady),
                    const SizedBox(height: 12),
                    _buildGamificationStrip(c, gs),
                    const SizedBox(height: 20),
                    _buildSectionHeader(c, 'YOUR APPS', apps.length),
                    const SizedBox(height: 10),
                    if (apps.isEmpty)
                      _buildEmptyState(c)
                    else
                      Column(
                        children: apps
                            .map((a) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _buildAppCard(c, a, tm),
                                ))
                            .toList(),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(c),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader(CtrlColors c, ThemeNotifier tn) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
      child: Row(
        children: [
          // App name
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'ctrl',
                  style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: c.text,
                    letterSpacing: -1.2,
                  ),
                ),
                TextSpan(
                  text: '.',
                  style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: c.accent,
                    letterSpacing: -1.2,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Theme toggle
          _HeaderBtn(
            icon: tn.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            color: c.textSub,
            bgColor: c.card,
            onTap: tn.toggle,
          ),
          const SizedBox(width: 8),
          _HeaderBtn(
            icon: Icons.bar_chart_rounded,
            color: c.textSub,
            bgColor: c.card,
            onTap: () => Navigator.pushNamed(context, '/stats'),
          ),
          const SizedBox(width: 8),
          _HeaderBtn(
            icon: Icons.settings_outlined,
            color: c.textSub,
            bgColor: c.card,
            onTap: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
    );
  }

  // ── Shield / status card ────────────────────────────────────────────────────
  Widget _buildShieldCard(CtrlColors c, TimerManager tm, bool isReady) {
    final active = tm.isTrackingActive;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
            color: active
                ? c.accent.withValues(alpha: 0.12)
                : c.shadow,
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Status icon + label
          Expanded(
            child: Row(
              children: [
                // Pulsing dot
                AnimatedBuilder(
                  animation: _dotCtrl,
                  builder: (_, __) => Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active
                          ? kColorSuccess.withValues(alpha: _dotOpacity.value)
                          : c.textMuted,
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: kColorSuccess.withValues(alpha: _dotOpacity.value * 0.6),
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                            ]
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        active ? 'Shield Active' : 'Shield Off',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: c.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        active
                            ? '${tm.blockedApps.length} app${tm.blockedApps.length != 1 ? 's' : ''} protected'
                            : 'Tap to start monitoring',
                        style: TextStyle(fontSize: 12, color: c.textSub),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Toggle
          _CtrlSwitch(
            value: active,
            accent: c.accent,
            onTap: () {
              if (!isReady) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Grant all required permissions first'),
                    backgroundColor: kColorWarning,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                );
                return;
              }
              tm.toggleTrackingService(!active);
            },
          ),
        ],
      ),
    );
  }

  // ── Gamification strip ──────────────────────────────────────────────────────
  Widget _buildGamificationStrip(CtrlColors c, GamificationService gs) {
    final streak = gs.streak;
    final score  = gs.focusScore;
    final scoreColor = score >= 75
        ? kColorSuccess
        : score >= 40
            ? kColorWarning
            : kColorDanger;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/stats'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            // Streak
            Text(streak > 0 ? '🔥' : '💤',
                style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$streak day streak',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: streak > 0 ? kColorWarning : c.textSub),
                ),
                Text('Streak',
                    style: TextStyle(fontSize: 10, color: c.textMuted)),
              ],
            ),
            const Spacer(),
            Container(width: 1, height: 30, color: c.border),
            const Spacer(),
            // Focus score
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${score.round()} / 100',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: scoreColor),
                ),
                Text('Focus Score',
                    style: TextStyle(fontSize: 10, color: c.textMuted)),
              ],
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 12, color: c.textMuted),
          ],
        ),
      ),
    );
  }

  // ── Section header ──────────────────────────────────────────────────────────
  Widget _buildSectionHeader(CtrlColors c, String title, int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: c.textMuted,
                letterSpacing: 1.2,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: c.accentSurface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: c.accent,
                  ),
                ),
              ),
            ],
          ],
        ),
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/selector'),
          child: Text(
            'Manage',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: c.accent,
            ),
          ),
        ),
      ],
    );
  }

  // ── App card ────────────────────────────────────────────────────────────────
  Widget _buildAppCard(CtrlColors c, AppLimit app, TimerManager tm) {
    final inCooldown = app.isInCooldown;
    final ratio = inCooldown ? app.cooldownRatio : app.usageRatio;

    final Color progressColor;
    if (inCooldown) {
      progressColor = kColorDanger;
    } else if (ratio > 0.75) {
      progressColor = kColorWarning;
    } else {
      progressColor = c.accent;
    }

    final String statusLabel;
    final Color statusColor;
    if (inCooldown) {
      statusLabel = 'Locked';
      statusColor = kColorDanger;
    } else if (ratio > 0.75) {
      statusLabel = 'Warning';
      statusColor = kColorWarning;
    } else {
      statusLabel = 'Active';
      statusColor = kColorSuccess;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: inCooldown
              ? kColorDanger.withValues(alpha: 0.25)
              : c.border,
        ),
        boxShadow: [
          BoxShadow(color: c.shadow, blurRadius: 12, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          _AppAvatar(name: app.appName, color: progressColor),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        app.appName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: c.text,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _StatusPill(label: statusLabel, color: statusColor),
                  ],
                ),
                const SizedBox(height: 5),
                if (inCooldown)
                  Row(
                    children: [
                      Icon(Icons.lock_outline_rounded,
                          size: 12, color: kColorDanger),
                      const SizedBox(width: 4),
                      Text(
                        'Resets in ${_fmt(app.remainingCooldownMillis)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: kColorDanger,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    '${_fmt(app.usedMillis)} used  ·  ${_fmt(app.remainingUsageMillis)} left',
                    style: TextStyle(fontSize: 12, color: c.textSub),
                  ),
                const SizedBox(height: 8),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 4,
                    backgroundColor: c.border,
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // Circular ring + unlock
          Column(
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(56, 56),
                      painter: _RingPainter(
                        progress: ratio,
                        color: progressColor,
                        bgColor: c.border,
                        strokeWidth: 5,
                      ),
                    ),
                    Text(
                      '${(ratio * 100).round()}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: progressColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => _showResetDialog(c, app, tm),
                child: Icon(Icons.lock_open_rounded,
                    size: 16, color: c.textMuted),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => Navigator.pushNamed(
                  context,
                  '/earn-time',
                  arguments: app,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: c.accent.withValues(alpha: 0.3), width: 1),
                  ),
                  child: Text(
                    '⚡ Earn',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: c.accent),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Empty state ──────────────────────────────────────────────────────────────
  Widget _buildEmptyState(CtrlColors c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.accentSurface,
            ),
            child: Icon(Icons.add_circle_outline_rounded,
                size: 30, color: c.accent),
          ),
          const SizedBox(height: 16),
          Text(
            'No apps added yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: c.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add YouTube, Instagram or any app\nyou want to control.',
            style: TextStyle(fontSize: 13, color: c.textSub, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Permission banner ───────────────────────────────────────────────────────
  Widget _buildPermissionBanner(CtrlColors c, TimerManager tm) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kColorWarning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kColorWarning.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: kColorWarning, size: 18),
              const SizedBox(width: 8),
              Text(
                'Permissions needed',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: kColorWarning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (!tm.hasUsagePermission)
            _PermTile(
              label: 'Usage Stats Access',
              onTap: UsageTracker.requestUsageStatsPermission,
            ),
          if (!tm.hasAccessibilityPermission) ...[
            if (!tm.hasUsagePermission) const SizedBox(height: 6),
            _PermTile(
              label: 'Accessibility Service',
              onTap: UsageTracker.openAccessibilitySettings,
            ),
          ],
          if (!tm.hasNotificationPermission) ...[
            const SizedBox(height: 6),
            _PermTile(
              label: 'Notification Access',
              onTap: tm.requestNotificationPermission,
            ),
          ],
        ],
      ),
    );
  }

  // ── FAB ──────────────────────────────────────────────────────────────────────
  Widget _buildFAB(CtrlColors c) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/selector'),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [c.accent, Color.lerp(c.accent, Colors.black, 0.15)!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: c.accent.withValues(alpha: 0.38),
              blurRadius: 20,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              'Add App',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Reset dialog ──────────────────────────────────────────────────────────
  void _showResetDialog(CtrlColors c, AppLimit app, TimerManager tm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: c.border),
        ),
        title: Text(
          'Reset ${app.appName}?',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: c.text,
          ),
        ),
        content: Text(
          'Usage will be reset to zero and any cooldown cleared immediately.',
          style: TextStyle(fontSize: 14, color: c.textSub, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: c.textSub, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () async {
              final nav = Navigator.of(ctx);
              await tm.resetAppUsage(app.packageName);
              if (ctx.mounted) nav.pop();
            },
            child: Text('Reset',
                style: TextStyle(
                    color: c.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ── Reusable primitives ────────────────────────────────────────────────────────

class _HeaderBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;
  const _HeaderBtn({required this.icon, required this.color, required this.bgColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

class _CtrlSwitch extends StatelessWidget {
  final bool value;
  final Color accent;
  final VoidCallback onTap;
  const _CtrlSwitch({required this.value, required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
        width: 52,
        height: 30,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: value ? accent : const Color(0xFF3A3A3C),
          boxShadow: value
              ? [BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 10)]
              : null,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 1))
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppAvatar extends StatelessWidget {
  final String name;
  final Color color;
  const _AppAvatar({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1.5),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _PermTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PermTile({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = CtrlColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: c.card.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.text)),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 12, color: c.textMuted),
          ],
        ),
      ),
    );
  }
}

// ── Custom arc painter ─────────────────────────────────────────────────────────
class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color bgColor;
  final double strokeWidth;

  const _RingPainter({
    required this.progress,
    required this.color,
    required this.bgColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = (size.width - strokeWidth) / 2;

    // Track
    canvas.drawCircle(
      c, r,
      Paint()
        ..color = bgColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke,
    );

    if (progress <= 0) return;

    // Glow
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = color.withValues(alpha: 0.3)
        ..strokeWidth = strokeWidth + 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Arc
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}
