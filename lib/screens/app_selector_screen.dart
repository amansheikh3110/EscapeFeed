import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/timer_manager.dart';
import '../models/app_limit.dart';
import '../utils/constants.dart';

class AppSelectorScreen extends StatefulWidget {
  const AppSelectorScreen({super.key});
  @override
  State<AppSelectorScreen> createState() => _AppSelectorScreenState();
}

class _AppSelectorScreenState extends State<AppSelectorScreen> {
  String _query = '';
  final _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() => _focused = _focusNode.hasFocus));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = CtrlColors.of(context);
    final tm = Provider.of<TimerManager>(context);
    final installed = tm.installedApps;
    final blocked = tm.blockedApps;

    final filtered = _query.isEmpty
        ? installed
        : installed.where((a) {
            final name = (a['name'] as String? ?? '').toLowerCase();
            final pkg = (a['packageName'] as String? ?? '').toLowerCase();
            final q = _query.toLowerCase();
            return name.contains(q) || pkg.contains(q);
          }).toList();

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────
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
                    'Add Limit',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Search bar ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _focused ? c.accent : c.border,
                    width: _focused ? 1.5 : 1,
                  ),
                  boxShadow: _focused
                      ? [
                          BoxShadow(
                            color: c.accent.withValues(alpha: 0.1),
                            blurRadius: 16,
                          )
                        ]
                      : null,
                ),
                child: TextField(
                  focusNode: _focusNode,
                  onChanged: (v) => setState(() => _query = v),
                  style: TextStyle(fontSize: 15, color: c.text),
                  decoration: InputDecoration(
                    hintText: 'Search apps...',
                    hintStyle: TextStyle(color: c.textMuted, fontSize: 15),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: _focused ? c.accent : c.textMuted, size: 20),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.close_rounded,
                                size: 17, color: c.textMuted),
                            onPressed: () => setState(() => _query = ''),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),

            // ── Count row ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 2),
              child: Row(
                children: [
                  Text(
                    '${filtered.length} apps',
                    style: TextStyle(fontSize: 12, color: c.textMuted),
                  ),
                  const SizedBox(width: 6),
                  Container(
                      width: 3,
                      height: 3,
                      decoration:
                          BoxDecoration(shape: BoxShape.circle, color: c.textMuted)),
                  const SizedBox(width: 6),
                  Text(
                    '${blocked.length} controlled',
                    style: TextStyle(
                        fontSize: 12,
                        color: c.accent,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

            // ── List ───────────────────────────────────────────────────────
            Expanded(
              child: tm.isLoadingApps
                  ? Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: c.accent),
                    )
                  : filtered.isEmpty
                      ? Center(
                          child: Text('No apps found',
                              style: TextStyle(color: c.textSub)),
                        )
                      : ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final app = filtered[i];
                            final pkg = app['packageName'] as String;
                            final name = app['name'] as String;
                            final isSystem = app['isSystem'] as bool? ?? false;
                            final limIdx =
                                blocked.indexWhere((a) => a.packageName == pkg);
                            final isLimited = limIdx != -1;
                            final limit = isLimited ? blocked[limIdx] : null;
                            return _AppTile(
                              key: ValueKey(pkg),
                              name: name,
                              pkg: pkg,
                              isSystem: isSystem,
                              isLimited: isLimited,
                              limit: limit,
                              onToggle: (val) async {
                                await tm.toggleAppBlock(app, val);
                                if (mounted && val) {
                                  _openSheet(pkg, name, tm, blocked);
                                }
                              },
                              onEdit: () => _openSheet(pkg, name, tm, blocked),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  void _openSheet(
      String pkg, String name, TimerManager tm, List<AppLimit> blocked) {
    final idx = blocked.indexWhere((a) => a.packageName == pkg);
    if (idx == -1) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) =>
          _ConfigSheet(limit: blocked[idx], timerManager: tm),
    );
  }
}

// ── App tile ───────────────────────────────────────────────────────────────────
class _AppTile extends StatelessWidget {
  final String name;
  final String pkg;
  final bool isSystem;
  final bool isLimited;
  final AppLimit? limit;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;

  const _AppTile({
    super.key,
    required this.name,
    required this.pkg,
    required this.isSystem,
    required this.isLimited,
    this.limit,
    required this.onToggle,
    required this.onEdit,
  });

  static const _palette = [
    Color(0xFF8B5CF6), Color(0xFF06B6D4), Color(0xFF10B981),
    Color(0xFFF59E0B), Color(0xFFEF4444), Color(0xFF3B82F6),
  ];

  Color get _color =>
      _palette[name.isNotEmpty ? name.codeUnitAt(0) % _palette.length : 0];

  @override
  Widget build(BuildContext context) {
    final c = CtrlColors.of(context);
    final col = isLimited ? c.accent : _color;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isLimited ? c.accentSurface.withValues(alpha: 0.5) : c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLimited ? c.accentBorder : c.border,
          width: isLimited ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: col.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: col.withValues(alpha: 0.25), width: 1.5),
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: col,
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
                          fontWeight: FontWeight.w600,
                          color: c.text,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSystem)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: c.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('SYS',
                            style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                color: c.textMuted)),
                      ),
                  ],
                ),
                if (isLimited && limit != null) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        '${limit!.limitMinutes}m limit  ·  ${limit!.cooldownMinutes >= 60 ? '${(limit!.cooldownMinutes / 60).toStringAsFixed(1)}h' : '${limit!.cooldownMinutes}m'} reset',
                        style: TextStyle(
                          fontSize: 11,
                          color: c.accent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: onEdit,
                        child: Text(
                          'Edit',
                          style: TextStyle(
                            fontSize: 11,
                            color: c.textSub,
                            decoration: TextDecoration.underline,
                            decorationColor: c.textSub,
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 2),
                  Text(pkg,
                      style: TextStyle(fontSize: 11, color: c.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          _SwitchPill(value: isLimited, accent: c.accent, onToggle: onToggle),
        ],
      ),
    );
  }
}

// ── Pill toggle ────────────────────────────────────────────────────────────────
class _SwitchPill extends StatelessWidget {
  final bool value;
  final Color accent;
  final ValueChanged<bool> onToggle;
  const _SwitchPill({required this.value, required this.accent, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final trackOff = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF2C2C2E)
        : const Color(0xFFE5E5EA);
    return GestureDetector(
      onTap: () => onToggle(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 48,
        height: 28,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: value ? accent : trackOff,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 250),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
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

// ── Config bottom sheet ────────────────────────────────────────────────────────
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
    final c = CtrlColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                22, 20, 22, MediaQuery.of(context).viewInsets.bottom + 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // App header
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: c.accentSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: c.accentBorder),
                      ),
                      child: Center(
                        child: Text(
                          widget.limit.appName.isNotEmpty
                              ? widget.limit.appName[0].toUpperCase()
                              : '?',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: c.accent,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.limit.appName,
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: c.text)),
                        Text('Configure time limit',
                            style:
                                TextStyle(fontSize: 12, color: c.textSub)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Daily limit
                _sliderLabel(c, 'Daily Limit', '$_limitMin min', c.accent),
                const SizedBox(height: 6),
                _styledSlider(c, _limitMin.toDouble(), 1, 120, 119, c.accent,
                    (v) => setState(() => _limitMin = v.toInt())),
                _sliderRange(c, '1 min', '2 hours'),
                const SizedBox(height: 22),

                // Cooldown
                _sliderLabel(c, 'Reset After', _fmtCooldown(_cooldownMin),
                    kColorWarning),
                const SizedBox(height: 6),
                _styledSlider(c, _cooldownMin.toDouble(), 5, 360, 71,
                    kColorWarning,
                    (v) => setState(() => _cooldownMin = v.toInt())),
                _sliderRange(c, '5 min', '6 hours'),
                const SizedBox(height: 28),

                // Apply
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _saving
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Apply',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sliderLabel(
      CtrlColors c, String title, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: c.textSub)),
        Text(value,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: valueColor)),
      ],
    );
  }

  Widget _styledSlider(CtrlColors c, double value, double min, double max,
      int div, Color color, ValueChanged<double> onChanged) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: color,
        inactiveTrackColor: c.border,
        thumbColor: color,
        overlayColor: color.withValues(alpha: 0.1),
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      ),
      child: Slider(
        value: value,
        min: min,
        max: max,
        divisions: div,
        onChanged: onChanged,
      ),
    );
  }

  Widget _sliderRange(CtrlColors c, String lo, String hi) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(lo, style: TextStyle(fontSize: 10, color: c.textMuted)),
          Text(hi, style: TextStyle(fontSize: 10, color: c.textMuted)),
        ],
      ),
    );
  }
}
