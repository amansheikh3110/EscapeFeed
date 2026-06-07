import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/timer_manager.dart';
import '../utils/constants.dart';
import '../services/usage_tracker.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Settings / Guide screen
// ─────────────────────────────────────────────────────────────────────────────
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tm = Provider.of<TimerManager>(context);

    return Scaffold(
      backgroundColor: NexusColors.void_,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(context),
      body: Stack(
        children: [
          // Static aurora bg
          Positioned.fill(child: CustomPaint(painter: _SettingsAurora())),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── System status header ─────────────────────────────
                  _SectionLabel('SYSTEM STATUS'),
                  const SizedBox(height: 10),
                  _buildSystemStatus(tm),
                  const SizedBox(height: 28),

                  // ── Setup guide ──────────────────────────────────────
                  _SectionLabel('SETUP GUIDE'),
                  const SizedBox(height: 10),
                  _buildGuideCard(tm),
                  const SizedBox(height: 28),

                  // ── Developer tools ──────────────────────────────────
                  _SectionLabel('DEVELOPER TOOLS'),
                  const SizedBox(height: 10),
                  _buildDevTools(context, tm),
                  const SizedBox(height: 28),

                  // ── Footer ───────────────────────────────────────────
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        color: NexusColors.textSecondary,
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SETTINGS',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: NexusColors.textBright,
              letterSpacing: 3,
            ),
          ),
          Text(
            'system configuration',
            style: TextStyle(
                fontSize: 11, color: NexusColors.textDim, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  // ── System status panel ─────────────────────────────────────────────────────
  Widget _buildSystemStatus(TimerManager tm) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: NexusColors.glassBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: NexusColors.glassBorder, width: 1.5),
          ),
          child: Column(
            children: [
              _StatusRow(
                icon: Icons.bar_chart_rounded,
                label: 'Usage Stats Access',
                description: 'Track which app is in foreground',
                isOk: tm.hasUsagePermission,
                onFix: UsageTracker.requestUsageStatsPermission,
              ),
              _Divider(),
              _StatusRow(
                icon: Icons.accessibility_new_rounded,
                label: 'Accessibility Service',
                description: 'Close apps when limit reached',
                isOk: tm.hasAccessibilityPermission,
                onFix: UsageTracker.openAccessibilitySettings,
              ),
              _Divider(),
              _StatusRow(
                icon: Icons.notifications_outlined,
                label: 'Notification Access',
                description: 'Keep background service alive',
                isOk: tm.hasNotificationPermission,
                onFix: tm.requestNotificationPermission,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Setup guide ─────────────────────────────────────────────────────────────
  Widget _buildGuideCard(TimerManager tm) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: NexusColors.glassBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: NexusColors.glassBorder, width: 1.5),
          ),
          child: Column(
            children: [
              _GuideStep(
                number: '01',
                title: 'Grant Usage Stats Access',
                body: 'Allows NEXUS to monitor which app is in the foreground '
                    'and count your active usage time accurately.',
                done: tm.hasUsagePermission,
              ),
              _Divider(),
              _GuideStep(
                number: '02',
                title: 'Enable Accessibility Service',
                body: 'Enables the background blocker to press Back and send '
                    'you home once your daily limit is exceeded.',
                done: tm.hasAccessibilityPermission,
              ),
              _Divider(),
              _GuideStep(
                number: '03',
                title: 'Allow Notifications',
                body: 'Android requires a persistent notification so the '
                    'tracking service is never killed by battery saver.',
                done: tm.hasNotificationPermission,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Developer tools ──────────────────────────────────────────────────────────
  Widget _buildDevTools(BuildContext context, TimerManager tm) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: NexusColors.glassBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: NexusColors.glassBorder, width: 1.5),
          ),
          child: Column(
            children: [
              _DevAction(
                icon: Icons.refresh_rounded,
                iconColor: NexusColors.neonBlue,
                label: 'Refresh Installed Apps',
                description: 'Re-query Android package manager',
                onTap: () async {
                  await tm.loadInstalledApps();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      _snack('App list refreshed', NexusColors.success),
                    );
                  }
                },
              ),
              _Divider(),
              _DevAction(
                icon: Icons.restore_rounded,
                iconColor: NexusColors.warning,
                label: 'Force Reset Usage Stats',
                description: 'Zero out usage for all blocked apps',
                onTap: () async {
                  await tm.forceResetAll();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      _snack('All usage stats reset', NexusColors.warning),
                    );
                  }
                },
              ),
              _Divider(),
              _DevAction(
                icon: Icons.delete_forever_rounded,
                iconColor: NexusColors.danger,
                label: 'Clear All Limits & Cooldowns',
                description: 'Remove every configured app limit',
                onTap: () async {
                  for (final app in List.from(tm.blockedApps)) {
                    await tm.toggleAppBlock(
                        {'packageName': app.packageName, 'name': app.appName},
                        false);
                  }
                  await tm.forceResetAll();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      _snack('All limits cleared', NexusColors.danger),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Footer ───────────────────────────────────────────────────────────────────
  Widget _buildFooter() {
    return Center(
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: NexusColors.neonCyan,
                  boxShadow: [
                    BoxShadow(
                        color: NexusColors.neonCyan.withOpacity(0.7),
                        blurRadius: 6),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'NEXUS CONTROL',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: NexusColors.textSecondary,
                  letterSpacing: 3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'v1.0.0  ·  Digital Well-being',
            style: TextStyle(fontSize: 11, color: NexusColors.textDim),
          ),
        ],
      ),
    );
  }

  SnackBar _snack(String msg, Color color) => SnackBar(
        content: Text(msg),
        backgroundColor: color.withOpacity(0.85),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Reusable widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.spaceGrotesk(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: NexusColors.textDim,
        letterSpacing: 2.5,
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      const Divider(color: NexusColors.glassBorder, height: 1, indent: 16, endIndent: 16);
}

/// Permission status row
class _StatusRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final bool isOk;
  final VoidCallback onFix;

  const _StatusRow({
    required this.icon,
    required this.label,
    required this.description,
    required this.isOk,
    required this.onFix,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOk
                  ? NexusColors.success.withOpacity(0.12)
                  : NexusColors.warning.withOpacity(0.10),
              border: Border.all(
                color: isOk
                    ? NexusColors.success.withOpacity(0.4)
                    : NexusColors.warning.withOpacity(0.35),
              ),
            ),
            child: Icon(
              icon,
              size: 18,
              color: isOk ? NexusColors.success : NexusColors.warning,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: NexusColors.textBright)),
                Text(description,
                    style: TextStyle(
                        fontSize: 11, color: NexusColors.textDim)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isOk)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: NexusColors.success.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: NexusColors.success.withOpacity(0.4), width: 1),
              ),
              child: Text('OK',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: NexusColors.success,
                      letterSpacing: 0.5)),
            )
          else
            GestureDetector(
              onTap: onFix,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: NexusColors.warning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: NexusColors.warning.withOpacity(0.4), width: 1),
                ),
                child: Text('FIX',
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: NexusColors.warning,
                        letterSpacing: 0.5)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Guide step (numbered + checkbox)
class _GuideStep extends StatelessWidget {
  final String number;
  final String title;
  final String body;
  final bool done;

  const _GuideStep({
    required this.number,
    required this.title,
    required this.body,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done
                  ? NexusColors.success.withOpacity(0.15)
                  : NexusColors.overlay,
              border: Border.all(
                color: done
                    ? NexusColors.success.withOpacity(0.5)
                    : NexusColors.textDim.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: done
                ? const Icon(Icons.check_rounded,
                    size: 16, color: NexusColors.success)
                : Center(
                    child: Text(
                      number,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: NexusColors.textSecondary,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: done ? NexusColors.textBright : NexusColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                      fontSize: 12, color: NexusColors.textDim, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Developer action row
class _DevAction extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String description;
  final VoidCallback onTap;

  const _DevAction({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(0),
      splashColor: iconColor.withOpacity(0.06),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconColor.withOpacity(0.10),
                border: Border.all(
                    color: iconColor.withOpacity(0.3), width: 1),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: NexusColors.textBright)),
                  Text(description,
                      style: TextStyle(
                          fontSize: 11, color: NexusColors.textDim)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: NexusColors.textDim),
          ],
        ),
      ),
    );
  }
}

/// Static aurora for settings bg
class _SettingsAurora extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    _orb(canvas, size, 0.80, 0.10, size.width * 0.55,
        const Color(0xFF4A148C), 0.11);
    _orb(canvas, size, 0.15, 0.60, size.width * 0.50,
        const Color(0xFF006064), 0.09);
  }

  void _orb(Canvas canvas, Size size, double dx, double dy, double r,
      Color color, double opacity) {
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
  bool shouldRepaint(_SettingsAurora old) => false;
}
