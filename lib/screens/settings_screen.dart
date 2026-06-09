import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/timer_manager.dart';
import '../services/theme_notifier.dart';
import '../utils/constants.dart';
import '../services/usage_tracker.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = CtrlColors.of(context);
    final tm = Provider.of<TimerManager>(context);
    final tn = Provider.of<ThemeNotifier>(context);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 10, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18, color: c.textSub),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    'Settings',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Appearance ─────────────────────────────────────────
                    _SectionLabel('APPEARANCE', c),
                    const SizedBox(height: 8),
                    _Card(
                      color: c.card,
                      border: c.border,
                      child: _Row(
                        icon: tn.isDark
                            ? Icons.dark_mode_rounded
                            : Icons.light_mode_rounded,
                        iconColor: c.accent,
                        title: 'App Theme',
                        subtitle: tn.isDark ? 'Dark mode' : 'Light mode',
                        c: c,
                        trailing: _MiniSwitch(
                          value: tn.isDark,
                          accent: c.accent,
                          onTap: tn.toggle,
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    // ── Permissions ────────────────────────────────────────
                    _SectionLabel('PERMISSIONS', c),
                    const SizedBox(height: 8),
                    _Card(
                      color: c.card,
                      border: c.border,
                      child: Column(
                        children: [
                          _PermRow(
                            icon: Icons.bar_chart_rounded,
                            title: 'Usage Stats',
                            subtitle: 'Track foreground app time',
                            isOk: tm.hasUsagePermission,
                            c: c,
                            onFix: UsageTracker.requestUsageStatsPermission,
                          ),
                          _Divider(c: c),
                          _PermRow(
                            icon: Icons.accessibility_new_rounded,
                            title: 'Accessibility',
                            subtitle: 'Close apps when limit reached',
                            isOk: tm.hasAccessibilityPermission,
                            c: c,
                            onFix: UsageTracker.openAccessibilitySettings,
                          ),
                          _Divider(c: c),
                          _PermRow(
                            icon: Icons.notifications_outlined,
                            title: 'Notifications',
                            subtitle: 'Run background service',
                            isOk: tm.hasNotificationPermission,
                            c: c,
                            onFix: tm.requestNotificationPermission,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // ── How it works ───────────────────────────────────────
                    _SectionLabel('HOW IT WORKS', c),
                    const SizedBox(height: 8),
                    _Card(
                      color: c.card,
                      border: c.border,
                      child: Column(
                        children: [
                          _GuideStep(
                            number: '1',
                            title: 'Grant Usage Stats',
                            body: 'Lets ctrl. monitor which app is in the foreground and track your usage time.',
                            done: tm.hasUsagePermission,
                            c: c,
                          ),
                          _Divider(c: c),
                          _GuideStep(
                            number: '2',
                            title: 'Enable Accessibility',
                            body: 'Allows ctrl. to press Back and return you home once your daily limit is hit.',
                            done: tm.hasAccessibilityPermission,
                            c: c,
                          ),
                          _Divider(c: c),
                          _GuideStep(
                            number: '3',
                            title: 'Allow Notifications',
                            body: 'Keeps the background tracking service alive — Android requires a notification.',
                            done: tm.hasNotificationPermission,
                            c: c,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // ── Developer tools ────────────────────────────────────
                    _SectionLabel('DEVELOPER TOOLS', c),
                    const SizedBox(height: 8),
                    _Card(
                      color: c.card,
                      border: c.border,
                      child: Column(
                        children: [
                          _DevTile(
                            icon: Icons.refresh_rounded,
                            iconColor: c.accent,
                            title: 'Refresh App List',
                            subtitle: 'Re-query Android package manager',
                            c: c,
                            onTap: () async {
                              await tm.loadInstalledApps();
                              if (context.mounted) {
                                _snack(context, 'App list refreshed',
                                    kColorSuccess);
                              }
                            },
                          ),
                          _Divider(c: c),
                          _DevTile(
                            icon: Icons.restore_rounded,
                            iconColor: kColorWarning,
                            title: 'Reset All Usage Stats',
                            subtitle: 'Zero out usage for every blocked app',
                            c: c,
                            onTap: () async {
                              await tm.forceResetAll();
                              if (context.mounted) {
                                _snack(context, 'All stats reset',
                                    kColorWarning);
                              }
                            },
                          ),
                          _Divider(c: c),
                          _DevTile(
                            icon: Icons.delete_forever_rounded,
                            iconColor: kColorDanger,
                            title: 'Clear All Limits',
                            subtitle: 'Remove every configured app limit',
                            c: c,
                            onTap: () async {
                              for (final app in List.from(tm.blockedApps)) {
                                await tm.toggleAppBlock(
                                    {'packageName': app.packageName, 'name': app.appName},
                                    false);
                              }
                              await tm.forceResetAll();
                              if (context.mounted) {
                                _snack(context, 'All limits cleared',
                                    kColorDanger);
                              }
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                    Center(
                      child: Text(
                        'ctrl.  v1.0.0  ·  Digital Well-being',
                        style: TextStyle(fontSize: 12, color: c.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _snack(BuildContext context, String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ── Reusable sub-widgets ───────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  final CtrlColors c;
  const _SectionLabel(this.text, this.c);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 2),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: c.textMuted,
            letterSpacing: 1.2,
          ),
        ),
      );
}

class _Card extends StatelessWidget {
  final Widget child;
  final Color color;
  final Color border;
  const _Card({required this.child, required this.color, required this.border});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: child,
      );
}

class _Divider extends StatelessWidget {
  final CtrlColors c;
  const _Divider({required this.c});

  @override
  Widget build(BuildContext context) =>
      Divider(color: c.border, height: 1, indent: 16, endIndent: 16);
}

class _Row extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final CtrlColors c;
  final Widget trailing;
  const _Row({
    required this.icon, required this.iconColor,
    required this.title, required this.subtitle,
    required this.c, required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: c.text)),
                Text(subtitle,
                    style: TextStyle(fontSize: 12, color: c.textSub)),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _PermRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isOk;
  final CtrlColors c;
  final VoidCallback onFix;
  const _PermRow({
    required this.icon, required this.title, required this.subtitle,
    required this.isOk, required this.c, required this.onFix,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isOk
                  ? kColorSuccess.withValues(alpha: 0.12)
                  : kColorWarning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon,
                size: 17,
                color: isOk ? kColorSuccess : kColorWarning),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: c.text)),
                Text(subtitle,
                    style: TextStyle(fontSize: 12, color: c.textSub)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isOk)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: kColorSuccess.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('OK',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: kColorSuccess)),
            )
          else
            GestureDetector(
              onTap: onFix,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: kColorWarning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: kColorWarning.withValues(alpha: 0.35)),
                ),
                child: Text('Fix',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: kColorWarning)),
              ),
            ),
        ],
      ),
    );
  }
}

class _GuideStep extends StatelessWidget {
  final String number;
  final String title;
  final String body;
  final bool done;
  final CtrlColors c;
  const _GuideStep({
    required this.number, required this.title,
    required this.body, required this.done, required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? kColorSuccess.withValues(alpha: 0.12) : c.border,
              border: Border.all(
                color: done
                    ? kColorSuccess.withValues(alpha: 0.5)
                    : c.textMuted.withValues(alpha: 0.3),
              ),
            ),
            child: done
                ? Icon(Icons.check_rounded, size: 15, color: kColorSuccess)
                : Center(
                    child: Text(number,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: c.textSub))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: done ? c.text : c.textSub)),
                const SizedBox(height: 3),
                Text(body,
                    style: TextStyle(
                        fontSize: 12, color: c.textMuted, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DevTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final CtrlColors c;
  final VoidCallback onTap;
  const _DevTile({
    required this.icon, required this.iconColor,
    required this.title, required this.subtitle,
    required this.c, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 17, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: c.text)),
                  Text(subtitle,
                      style: TextStyle(fontSize: 12, color: c.textSub)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: c.textMuted),
          ],
        ),
      ),
    );
  }
}

class _MiniSwitch extends StatelessWidget {
  final bool value;
  final Color accent;
  final VoidCallback onTap;
  const _MiniSwitch({required this.value, required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final trackOff = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF2C2C2E)
        : const Color(0xFFE5E5EA);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 46,
        height: 27,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: value ? accent : trackOff,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 250),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 21,
            height: 21,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 3)
              ],
            ),
          ),
        ),
      ),
    );
  }
}
