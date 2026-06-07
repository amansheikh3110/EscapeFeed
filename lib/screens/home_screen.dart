import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/timer_manager.dart';
import '../models/app_limit.dart';
import '../utils/constants.dart';
import '../services/usage_tracker.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Home screen
// ─────────────────────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  late final AnimationController _auroraCtrl;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseScale;
  late final Animation<double> _pulseOpacity;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _auroraCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _pulseOpacity = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _auroraCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final tm = Provider.of<TimerManager>(context, listen: false);
      tm.checkPermissions();
      tm.loadUsageStats();
      tm.checkServiceStatus();
    }
  }

  // ── helpers ────────────────────────────────────────────────────────────────
  String _fmt(int millis) {
    final d = Duration(milliseconds: millis);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  // ── build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final tm = Provider.of<TimerManager>(context);
    final apps = tm.blockedApps;
    final isReady = tm.hasUsagePermission &&
        tm.hasAccessibilityPermission &&
        tm.hasNotificationPermission;
    final isActive = tm.isTrackingActive;

    return Scaffold(
      backgroundColor: NexusColors.void_,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          // ── Layer 1 : animated aurora ───────────────────────────────────
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _auroraCtrl,
              builder: (_, __) => CustomPaint(
                painter: _AuroraPainter(_auroraCtrl.value),
              ),
            ),
          ),

          // ── Layer 2 : scrollable content ──────────────────────────────
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),

                  if (!isReady) ...[
                    _buildPermissionCard(tm),
                    const SizedBox(height: 16),
                  ],

                  _buildStatusCard(tm, isActive, isReady),
                  const SizedBox(height: 28),

                  _buildSectionHeader('ACTIVE LIMITS', apps.length),
                  const SizedBox(height: 12),

                  if (apps.isEmpty)
                    _buildEmptyState()
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: apps.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) =>
                          _buildAppCard(apps[i], tm),
                    ),

                  const SizedBox(height: 110),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
          child: const SizedBox.expand(),
        ),
      ),
      title: Row(
        children: [
          _GlowDot(color: NexusColors.neonCyan, size: 8),
          const SizedBox(width: 10),
          Text(
            'NEXUS',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: NexusColors.textBright,
              letterSpacing: 5,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'CONTROL',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: NexusColors.textDim,
              letterSpacing: 3,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined, size: 22),
          color: NexusColors.textSecondary,
          onPressed: () => Navigator.pushNamed(context, '/settings'),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ── Status / control card ─────────────────────────────────────────────────
  Widget _buildStatusCard(TimerManager tm, bool isActive, bool isReady) {
    return _GlassCard(
      borderColor:
          isActive ? NexusColors.neonCyan.withOpacity(0.35) : NexusColors.glassBorder,
      glowColor: isActive ? NexusColors.neonCyan.withOpacity(0.06) : null,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Row(
              children: [
                // ── Pulsing orb ──────────────────────────────────────────
                AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (_, __) {
                    return SizedBox(
                      width: 80,
                      height: 80,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (isActive) ...[
                            _OrbRing(
                              size: 80 * _pulseScale.value,
                              opacity: _pulseOpacity.value * 0.12,
                              color: NexusColors.neonCyan,
                              width: 1,
                            ),
                            _OrbRing(
                              size: 68 * _pulseScale.value,
                              opacity: _pulseOpacity.value * 0.25,
                              color: NexusColors.neonCyan,
                              width: 1.5,
                            ),
                          ],
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: isActive
                                  ? RadialGradient(colors: [
                                      NexusColors.neonCyan.withOpacity(0.22),
                                      NexusColors.neonBlue.withOpacity(0.08),
                                      Colors.transparent,
                                    ])
                                  : null,
                              color: isActive ? null : NexusColors.elevated,
                              border: Border.all(
                                color: isActive
                                    ? NexusColors.neonCyan.withOpacity(_pulseOpacity.value)
                                    : NexusColors.textDim,
                                width: 2,
                              ),
                              boxShadow: isActive
                                  ? [
                                      BoxShadow(
                                        color: NexusColors.neonCyan.withOpacity(
                                            _pulseOpacity.value * 0.45),
                                        blurRadius: 22,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Icon(
                              Icons.shield_rounded,
                              size: 26,
                              color: isActive
                                  ? NexusColors.neonCyan
                                  : NexusColors.textDim,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(width: 18),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isActive ? 'SHIELD ACTIVE' : 'SHIELD OFFLINE',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: isActive ? NexusColors.neonCyan : NexusColors.textDim,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        isActive
                            ? 'Monitoring ${tm.blockedApps.length} app${tm.blockedApps.length != 1 ? 's' : ''} · limits enforced'
                            : 'Apps will not be blocked',
                        style: TextStyle(
                          fontSize: 12,
                          color: NexusColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Mini status chips
                      Row(
                        children: [
                          _StatusChip(
                            label: 'USAGE',
                            active: tm.hasUsagePermission,
                          ),
                          const SizedBox(width: 6),
                          _StatusChip(
                            label: 'A11Y',
                            active: tm.hasAccessibilityPermission,
                          ),
                          const SizedBox(width: 6),
                          _StatusChip(
                            label: 'NOTIFY',
                            active: tm.hasNotificationPermission,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Power button ──────────────────────────────────────────────
            _PowerButton(
              isActive: isActive,
              onTap: () {
                if (!isReady) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Grant all required permissions first'),
                      backgroundColor: NexusColors.warning.withOpacity(0.9),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                  return;
                }
                tm.toggleTrackingService(!isActive);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Section header ─────────────────────────────────────────────────────────
  Widget _buildSectionHeader(String title, int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              title,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: NexusColors.textDim,
                letterSpacing: 2.5,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: NexusColors.neonCyan.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: NexusColors.neonCyan,
                  ),
                ),
              ),
            ],
          ],
        ),
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/selector'),
          child: Row(
            children: [
              Text(
                'MANAGE',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: NexusColors.neonCyan,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(width: 3),
              const Icon(Icons.arrow_forward_ios,
                  size: 9, color: NexusColors.neonCyan),
            ],
          ),
        ),
      ],
    );
  }

  // ── App card ───────────────────────────────────────────────────────────────
  Widget _buildAppCard(AppLimit app, TimerManager tm) {
    final inCooldown = app.isInCooldown;
    final ratio = inCooldown ? app.cooldownRatio : app.usageRatio;

    final Color ringColor;
    final LinearGradient? badgeGradient;
    if (inCooldown) {
      ringColor = NexusColors.danger;
      badgeGradient = NexusColors.dangerGradient;
    } else if (ratio > 0.8) {
      ringColor = NexusColors.warning;
      badgeGradient = NexusColors.warningGradient;
    } else {
      ringColor = NexusColors.neonCyan;
      badgeGradient = null;
    }

    return _GlassCard(
      borderColor: inCooldown
          ? NexusColors.danger.withOpacity(0.3)
          : (ratio > 0.8
              ? NexusColors.warning.withOpacity(0.25)
              : NexusColors.glassBorder),
      glowColor: inCooldown ? NexusColors.danger.withOpacity(0.07) : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // ── Circular progress ring + letter avatar ──────────────────
            SizedBox(
              width: 62,
              height: 62,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(62, 62),
                    painter: _ArcPainter(
                      progress: ratio,
                      color: ringColor,
                      bgColor: NexusColors.overlay,
                      strokeWidth: 5,
                    ),
                  ),
                  Text(
                    app.appName.isNotEmpty ? app.appName[0].toUpperCase() : '?',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: ringColor,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 14),

            // ── App info ────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          app.appName,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: NexusColors.textBright,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _BadgeChip(
                        label: inCooldown
                            ? 'LOCKED'
                            : (ratio > 0.8 ? 'WARNING' : 'ACTIVE'),
                        color: ringColor,
                        gradient: badgeGradient,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (inCooldown)
                    Row(
                      children: [
                        Icon(Icons.lock_clock_rounded,
                            size: 12, color: NexusColors.danger),
                        const SizedBox(width: 5),
                        Text(
                          'Resets in ${_fmt(app.remainingCooldownMillis)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: NexusColors.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _fmt(app.usedMillis),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: NexusColors.textSecondary,
                          ),
                        ),
                        Text(
                          '/ ${app.limitMinutes}m limit',
                          style: TextStyle(
                              fontSize: 11, color: NexusColors.textDim),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  // Thin progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 3,
                      backgroundColor: NexusColors.overlay,
                      valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // ── Unlock button ────────────────────────────────────────────
            _IconBtn(
              icon: Icons.lock_open_rounded,
              onTap: () => _showResetDialog(app, tm),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          children: [
            Icon(Icons.sensors_off_rounded,
                size: 56, color: NexusColors.textDim),
            const SizedBox(height: 16),
            Text(
              'NO LIMITS CONFIGURED',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: NexusColors.textSecondary,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add apps like YouTube and social media to start\ncontrolling your digital habits.',
              style: TextStyle(
                  fontSize: 13, color: NexusColors.textDim, height: 1.6),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Permission card ────────────────────────────────────────────────────────
  Widget _buildPermissionCard(TimerManager tm) {
    return _GlassCard(
      borderColor: NexusColors.warning.withOpacity(0.4),
      glowColor: NexusColors.warning.withOpacity(0.04),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: NexusColors.warning, size: 20),
                const SizedBox(width: 8),
                Text(
                  'PERMISSIONS REQUIRED',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: NexusColors.warning,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (!tm.hasUsagePermission)
              _PermRow(
                title: 'Usage Stats Access',
                sub: 'Track foreground app time',
                onTap: UsageTracker.requestUsageStatsPermission,
              ),
            if (!tm.hasAccessibilityPermission) ...[
              if (!tm.hasUsagePermission) const SizedBox(height: 8),
              _PermRow(
                title: 'Accessibility Service',
                sub: 'Close apps when limit reached',
                onTap: UsageTracker.openAccessibilitySettings,
              ),
            ],
            if (!tm.hasNotificationPermission) ...[
              const SizedBox(height: 8),
              _PermRow(
                title: 'Notification Access',
                sub: 'Keep background service running',
                onTap: tm.requestNotificationPermission,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── FAB ────────────────────────────────────────────────────────────────────
  Widget _buildFAB() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: NexusColors.cyberGradient,
        boxShadow: [
          BoxShadow(
            color: NexusColors.neonCyan.withOpacity(0.45),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.pushNamed(context, '/selector'),
          borderRadius: BorderRadius.circular(32),
          splashColor: Colors.white.withOpacity(0.12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 15),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, color: NexusColors.void_, size: 20),
                const SizedBox(width: 8),
                Text(
                  'ADD LIMIT',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: NexusColors.void_,
                    letterSpacing: 1.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Reset dialog ───────────────────────────────────────────────────────────
  void _showResetDialog(AppLimit app, TimerManager tm) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: NexusColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: NexusColors.glassBorder, width: 1.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Danger icon
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: NexusColors.danger.withOpacity(0.12),
                      border: Border.all(
                          color: NexusColors.danger.withOpacity(0.4)),
                    ),
                    child: const Icon(Icons.lock_open_rounded,
                        color: NexusColors.danger, size: 24),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'RESET ${app.appName.toUpperCase()}?',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: NexusColors.textBright,
                      letterSpacing: 1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Usage tracking will be cleared and any active cooldown lock lifted immediately.',
                    style: TextStyle(
                        fontSize: 13,
                        color: NexusColors.textSecondary,
                        height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: _OutlineBtn(
                          label: 'CANCEL',
                          onTap: () => Navigator.pop(ctx),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _GradientBtn(
                          label: 'RESET',
                          gradient: NexusColors.cyberGradient,
                          glowColor: NexusColors.neonCyan,
                          onTap: () async {
                            await tm.resetAppUsage(app.packageName);
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Reusable design primitives
// ─────────────────────────────────────────────────────────────────────────────

/// Glassmorphism card wrapper
class _GlassCard extends StatelessWidget {
  final Widget child;
  final Color? borderColor;
  final Color? glowColor;
  const _GlassCard({required this.child, this.borderColor, this.glowColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: glowColor != null
            ? [
                BoxShadow(
                  color: glowColor!,
                  blurRadius: 40,
                  spreadRadius: -8,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: NexusColors.glassBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: borderColor ?? NexusColors.glassBorder,
                width: 1.5,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Pulsing orb ring (concentric)
class _OrbRing extends StatelessWidget {
  final double size;
  final double opacity;
  final Color color;
  final double width;
  const _OrbRing({required this.size, required this.opacity, required this.color, required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(opacity), width: width),
      ),
    );
  }
}

/// Tiny glowing dot (used in AppBar)
class _GlowDot extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowDot({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color.withOpacity(0.8), blurRadius: 8)],
      ),
    );
  }
}

/// Small permission status chip
class _StatusChip extends StatelessWidget {
  final String label;
  final bool active;
  const _StatusChip({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: active
            ? NexusColors.success.withOpacity(0.12)
            : NexusColors.overlay,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: active
              ? NexusColors.success.withOpacity(0.5)
              : NexusColors.textDim.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w800,
          color: active ? NexusColors.success : NexusColors.textDim,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Status badge on app cards
class _BadgeChip extends StatelessWidget {
  final String label;
  final Color color;
  final LinearGradient? gradient;
  const _BadgeChip({required this.label, required this.color, this.gradient});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: gradient == null ? color.withOpacity(0.14) : null,
        gradient: gradient != null
            ? LinearGradient(
                colors: [
                  gradient!.colors.first.withOpacity(0.2),
                  gradient!.colors.last.withOpacity(0.2),
                ],
              )
            : null,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

/// Square icon button
class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: NexusColors.overlay,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: NexusColors.glassBorder, width: 1),
        ),
        child: Icon(icon, size: 16, color: NexusColors.textSecondary),
      ),
    );
  }
}

/// Animated power toggle button
class _PowerButton extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;
  const _PowerButton({required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          gradient: isActive
              ? null
              : NexusColors.cyberGradient,
          color: isActive ? NexusColors.danger.withOpacity(0.13) : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? NexusColors.danger.withOpacity(0.5)
                : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: isActive
              ? null
              : [
                  BoxShadow(
                    color: NexusColors.neonCyan.withOpacity(0.32),
                    blurRadius: 22,
                    offset: const Offset(0, 5),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.power_settings_new_rounded,
              size: 18,
              color: isActive ? NexusColors.danger : NexusColors.void_,
            ),
            const SizedBox(width: 8),
            Text(
              isActive ? 'DEACTIVATE SHIELD' : 'ACTIVATE SHIELD',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.8,
                color: isActive ? NexusColors.danger : NexusColors.void_,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Permission row inside alert card
class _PermRow extends StatelessWidget {
  final String title;
  final String sub;
  final VoidCallback onTap;
  const _PermRow({required this.title, required this.sub, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: NexusColors.void_.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: NexusColors.glassBorder, width: 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: NexusColors.textBright)),
                  Text(sub,
                      style: const TextStyle(
                          fontSize: 11, color: NexusColors.textDim)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 11, color: NexusColors.textDim),
          ],
        ),
      ),
    );
  }
}

/// Outline button (dialogs)
class _OutlineBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _OutlineBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: NexusColors.overlay,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: NexusColors.glassBorder),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: NexusColors.textSecondary,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }
}

/// Gradient filled button (dialogs / actions)
class _GradientBtn extends StatelessWidget {
  final String label;
  final LinearGradient gradient;
  final Color glowColor;
  final VoidCallback onTap;
  const _GradientBtn({
    required this.label,
    required this.gradient,
    required this.glowColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: glowColor.withOpacity(0.35),
              blurRadius: 14,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: NexusColors.void_,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Custom painters
// ─────────────────────────────────────────────────────────────────────────────

/// Circular arc progress ring (with soft glow)
class _ArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color bgColor;
  final double strokeWidth;

  const _ArcPainter({
    required this.progress,
    required this.color,
    required this.bgColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = bgColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke,
    );

    if (progress <= 0) return;

    // Glow layer
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = color.withOpacity(0.35)
        ..strokeWidth = strokeWidth + 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Crisp arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
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
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress || old.color != color;
}

/// Slow-drifting aurora background
class _AuroraPainter extends CustomPainter {
  final double t; // 0.0 → 1.0 looping

  const _AuroraPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _orb(canvas, size,
        dx: 0.15 + 0.18 * math.sin(t * 2 * math.pi),
        dy: 0.18 + 0.12 * math.cos(t * 2 * math.pi * 0.6),
        r: size.width * 0.65,
        color: const Color(0xFF0D47A1),
        opacity: 0.16);

    _orb(canvas, size,
        dx: 0.80 + 0.14 * math.cos(t * 2 * math.pi * 0.75),
        dy: 0.12 + 0.10 * math.sin(t * 2 * math.pi * 0.5),
        r: size.width * 0.55,
        color: const Color(0xFF4A148C),
        opacity: 0.13);

    _orb(canvas, size,
        dx: 0.50 + 0.10 * math.sin(t * 2 * math.pi * 0.4),
        dy: 0.75 + 0.12 * math.cos(t * 2 * math.pi * 0.3),
        r: size.width * 0.60,
        color: const Color(0xFF006064),
        opacity: 0.10);
  }

  void _orb(Canvas canvas, Size size,
      {required double dx,
      required double dy,
      required double r,
      required Color color,
      required double opacity}) {
    final center = Offset(size.width * dx, size.height * dy);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withOpacity(opacity), Colors.transparent],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );
  }

  @override
  bool shouldRepaint(_AuroraPainter old) => old.t != t;
}
