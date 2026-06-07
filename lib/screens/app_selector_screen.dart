import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/timer_manager.dart';
import '../models/app_limit.dart';
import '../utils/constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  App Selector Screen
// ─────────────────────────────────────────────────────────────────────────────
class AppSelectorScreen extends StatefulWidget {
  const AppSelectorScreen({super.key});

  @override
  State<AppSelectorScreen> createState() => _AppSelectorScreenState();
}

class _AppSelectorScreenState extends State<AppSelectorScreen> {
  String _query = '';
  final FocusNode _searchFocus = FocusNode();
  bool _searchFocused = false;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() {
      setState(() => _searchFocused = _searchFocus.hasFocus);
    });
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tm = Provider.of<TimerManager>(context);
    final installed = tm.installedApps;
    final blocked = tm.blockedApps;

    final filtered = installed.where((app) {
      final name = (app['name'] as String? ?? '').toLowerCase();
      final pkg = (app['packageName'] as String? ?? '').toLowerCase();
      final q = _query.toLowerCase();
      return name.contains(q) || pkg.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: NexusColors.void_,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(context),
      body: Stack(
        children: [
          // Subtle static gradient bg (no animation here for perf)
          Positioned.fill(
            child: CustomPaint(painter: _StaticAurora()),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 8),
                _buildSearchBar(),
                const SizedBox(height: 4),
                _buildCountBar(filtered.length, blocked.length),
                const SizedBox(height: 4),
                Expanded(
                  child: tm.isLoadingApps
                      ? _buildLoader()
                      : filtered.isEmpty
                          ? _buildEmpty()
                          : ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                              itemCount: filtered.length,
                              itemBuilder: (_, i) {
                                final app = filtered[i];
                                final pkg = app['packageName'] as String;
                                final name = app['name'] as String;
                                final isSystem = app['isSystem'] as bool? ?? false;
                                final limIdx = blocked.indexWhere(
                                    (a) => a.packageName == pkg);
                                final isLimited = limIdx != -1;
                                final limit =
                                    isLimited ? blocked[limIdx] : null;
                                return _AppTile(
                                  key: ValueKey(pkg),
                                  name: name,
                                  packageName: pkg,
                                  isSystem: isSystem,
                                  isLimited: isLimited,
                                  limit: limit,
                                  onToggle: (val) async {
                                    await tm.toggleAppBlock(app, val);
                                    if (mounted && val) {
                                      _openConfig(context, pkg, name, tm, blocked);
                                    }
                                  },
                                  onConfigure: () =>
                                      _openConfig(context, pkg, name, tm, blocked),
                                );
                              },
                            ),
                ),
              ],
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
            'ADD LIMITS',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: NexusColors.textBright,
              letterSpacing: 3,
            ),
          ),
          Text(
            'select apps to control',
            style: TextStyle(
              fontSize: 11,
              color: NexusColors.textDim,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: NexusColors.elevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _searchFocused
                ? NexusColors.neonCyan.withOpacity(0.5)
                : NexusColors.glassBorder,
            width: _searchFocused ? 1.5 : 1,
          ),
          boxShadow: _searchFocused
              ? [
                  BoxShadow(
                    color: NexusColors.neonCyan.withOpacity(0.08),
                    blurRadius: 20,
                  ),
                ]
              : null,
        ),
        child: TextField(
          focusNode: _searchFocus,
          onChanged: (v) => setState(() => _query = v),
          style: TextStyle(
              fontSize: 14, color: NexusColors.textBright, height: 1.2),
          decoration: InputDecoration(
            hintText: 'Search installed apps...',
            hintStyle:
                TextStyle(color: NexusColors.textDim, fontSize: 14),
            prefixIcon: Icon(Icons.search_rounded,
                color: _searchFocused
                    ? NexusColors.neonCyan
                    : NexusColors.textSecondary,
                size: 20),
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    color: NexusColors.textDim,
                    onPressed: () => setState(() => _query = ''),
                  )
                : null,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildCountBar(int total, int limited) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(
            '$total apps',
            style: TextStyle(
                fontSize: 11, color: NexusColors.textDim, letterSpacing: 0.5),
          ),
          const SizedBox(width: 6),
          Container(
              width: 3,
              height: 3,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: NexusColors.textDim)),
          const SizedBox(width: 6),
          Text(
            '$limited controlled',
            style: TextStyle(
                fontSize: 11, color: NexusColors.neonCyan, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildLoader() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(NexusColors.neonCyan),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'LOADING APPS...',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 11,
              color: NexusColors.textDim,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Text(
        'No apps found',
        style: TextStyle(color: NexusColors.textDim, fontSize: 14),
      ),
    );
  }

  void _openConfig(BuildContext ctx, String pkg, String name,
      TimerManager tm, List<AppLimit> blocked) {
    final limIdx = blocked.indexWhere((a) => a.packageName == pkg);
    if (limIdx == -1) return;
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ConfigSheet(
        limit: blocked[limIdx],
        timerManager: tm,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Individual app tile
// ─────────────────────────────────────────────────────────────────────────────
class _AppTile extends StatelessWidget {
  final String name;
  final String packageName;
  final bool isSystem;
  final bool isLimited;
  final AppLimit? limit;
  final ValueChanged<bool> onToggle;
  final VoidCallback onConfigure;

  const _AppTile({
    super.key,
    required this.name,
    required this.packageName,
    required this.isSystem,
    required this.isLimited,
    this.limit,
    required this.onToggle,
    required this.onConfigure,
  });

  Color get _avatarColor {
    final colors = [
      NexusColors.neonBlue,
      NexusColors.neonCyan,
      NexusColors.neonPurple,
      NexusColors.neonPink,
      NexusColors.success,
    ];
    return colors[name.isNotEmpty ? name.codeUnitAt(0) % colors.length : 0];
  }

  @override
  Widget build(BuildContext context) {
    final ac = _avatarColor;
    return GestureDetector(
      onTap: isLimited ? onConfigure : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isLimited
              ? NexusColors.neonCyan.withOpacity(0.04)
              : NexusColors.elevated,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isLimited
                ? NexusColors.neonCyan.withOpacity(0.25)
                : NexusColors.glassBorder,
            width: 1.5,
          ),
          boxShadow: isLimited
              ? [
                  BoxShadow(
                    color: NexusColors.neonCyan.withOpacity(0.05),
                    blurRadius: 20,
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    ac.withOpacity(0.22),
                    ac.withOpacity(0.06),
                  ]),
                  border: Border.all(color: ac.withOpacity(0.3), width: 1.5),
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: ac,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: NexusColors.textBright,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isSystem)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: NexusColors.textDim.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('SYS',
                                style: TextStyle(
                                    fontSize: 8,
                                    color: NexusColors.textSecondary,
                                    fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      packageName,
                      style: TextStyle(
                          fontSize: 11, color: NexusColors.textDim),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isLimited && limit != null) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(Icons.timer_outlined,
                              size: 11, color: NexusColors.neonCyan),
                          const SizedBox(width: 4),
                          Text(
                            '${limit!.limitMinutes}m limit  ·  ${limit!.cooldownMinutes >= 60 ? '${(limit!.cooldownMinutes / 60).toStringAsFixed(1)}h' : '${limit!.cooldownMinutes}m'} cooldown',
                            style: TextStyle(
                              fontSize: 10,
                              color: NexusColors.neonCyan,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: onConfigure,
                            child: Text(
                              'EDIT',
                              style: TextStyle(
                                fontSize: 9,
                                color: NexusColors.neonCyan.withOpacity(0.7),
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                decoration: TextDecoration.underline,
                                decorationColor:
                                    NexusColors.neonCyan.withOpacity(0.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Custom toggle
              _NexusSwitch(
                value: isLimited,
                onChanged: onToggle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Custom animated toggle switch
// ─────────────────────────────────────────────────────────────────────────────
class _NexusSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _NexusSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOut,
        width: 48,
        height: 28,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: value ? NexusColors.cyberGradient : null,
          color: value ? null : NexusColors.overlay,
          boxShadow: value
              ? [
                  BoxShadow(
                    color: NexusColors.neonCyan.withOpacity(0.35),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? NexusColors.void_ : NexusColors.textDim,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Configuration bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
class _ConfigSheet extends StatefulWidget {
  final AppLimit limit;
  final TimerManager timerManager;
  const _ConfigSheet({required this.limit, required this.timerManager});

  @override
  State<_ConfigSheet> createState() => _ConfigSheetState();
}

class _ConfigSheetState extends State<_ConfigSheet> {
  late int _limitMin;
  late int _cooldownMin;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _limitMin = widget.limit.limitMinutes;
    _cooldownMin = widget.limit.cooldownMinutes;
  }

  String _fmtCooldown(int m) =>
      m >= 60 ? '${(m / 60).toStringAsFixed(1)} hours' : '$m mins';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: NexusColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // drag handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: NexusColors.overlay,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: NexusColors.neonCyan.withOpacity(0.12),
                        border: Border.all(
                            color: NexusColors.neonCyan.withOpacity(0.3)),
                      ),
                      child: Center(
                        child: Text(
                          widget.limit.appName.isNotEmpty
                              ? widget.limit.appName[0].toUpperCase()
                              : '?',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: NexusColors.neonCyan,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.limit.appName,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: NexusColors.textBright,
                          ),
                        ),
                        Text(
                          'Configure time limit',
                          style: TextStyle(
                              fontSize: 12, color: NexusColors.textDim),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // ── Daily limit slider ─────────────────────────────────
                _SliderRow(
                  icon: Icons.timer_outlined,
                  iconColor: NexusColors.neonCyan,
                  label: 'DAILY LIMIT',
                  value: '$_limitMin min',
                  valueColor: NexusColors.neonCyan,
                ),
                const SizedBox(height: 4),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: NexusColors.neonCyan,
                    inactiveTrackColor: NexusColors.overlay,
                    thumbColor: NexusColors.neonCyan,
                    overlayColor: NexusColors.neonCyan.withOpacity(0.12),
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  ),
                  child: Slider(
                    value: _limitMin.toDouble(),
                    min: 1,
                    max: 120,
                    divisions: 119,
                    onChanged: (v) => setState(() => _limitMin = v.toInt()),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('1 min',
                        style: TextStyle(
                            fontSize: 10, color: NexusColors.textDim)),
                    Text('2 hours',
                        style: TextStyle(
                            fontSize: 10, color: NexusColors.textDim)),
                  ],
                ),

                const SizedBox(height: 24),

                // ── Cooldown slider ────────────────────────────────────
                _SliderRow(
                  icon: Icons.restore_rounded,
                  iconColor: NexusColors.neonPurple,
                  label: 'RESET AFTER',
                  value: _fmtCooldown(_cooldownMin),
                  valueColor: NexusColors.neonPurple,
                ),
                const SizedBox(height: 4),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: NexusColors.neonPurple,
                    inactiveTrackColor: NexusColors.overlay,
                    thumbColor: NexusColors.neonPurple,
                    overlayColor: NexusColors.neonPurple.withOpacity(0.12),
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  ),
                  child: Slider(
                    value: _cooldownMin.toDouble(),
                    min: 5,
                    max: 360,
                    divisions: 71,
                    onChanged: (v) => setState(() => _cooldownMin = v.toInt()),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('5 min',
                        style: TextStyle(
                            fontSize: 10, color: NexusColors.textDim)),
                    Text('6 hours',
                        style: TextStyle(
                            fontSize: 10, color: NexusColors.textDim)),
                  ],
                ),

                const SizedBox(height: 28),

                // ── Apply button ───────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: GestureDetector(
                    onTap: _saving
                        ? null
                        : () async {
                            setState(() => _saving = true);
                            final nav = Navigator.of(context);
                            await widget.timerManager.updateAppLimit(
                              widget.limit.packageName,
                              _limitMin,
                              _cooldownMin,
                            );
                            if (mounted) nav.pop();
                          },
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: NexusColors.cyberGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: NexusColors.neonCyan.withOpacity(0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      NexusColors.void_),
                                ),
                              )
                            : Text(
                                'APPLY SETTINGS',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: NexusColors.void_,
                                  letterSpacing: 2,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),

                SizedBox(
                    height: MediaQuery.of(context).viewInsets.bottom + 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helper for slider section header ─────────────────────────────────────────
class _SliderRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color valueColor;
  const _SliderRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: NexusColors.textDim,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

// ── Static aurora for app selector background ─────────────────────────────────
class _StaticAurora extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    _orb(canvas, size, 0.15, 0.22, size.width * 0.5,
        const Color(0xFF0D47A1), 0.14);
    _orb(canvas, size, 0.80, 0.15, size.width * 0.45,
        const Color(0xFF4A148C), 0.10);
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
  bool shouldRepaint(_StaticAurora old) => false;
}
