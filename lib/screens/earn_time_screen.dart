import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/app_limit.dart';
import '../services/gamification_service.dart';
import '../services/usage_tracker.dart';
import '../utils/constants.dart';

enum _Mode { choose, math, breathe, success }

class EarnTimeScreen extends StatefulWidget {
  final AppLimit app;
  const EarnTimeScreen({super.key, required this.app});

  @override
  State<EarnTimeScreen> createState() => _EarnTimeScreenState();
}

class _EarnTimeScreenState extends State<EarnTimeScreen>
    with TickerProviderStateMixin {
  _Mode _mode = _Mode.choose;

  // ── Math puzzle ───────────────────────────────────────────────────────────
  late List<_Question> _questions;
  int _qIndex = 0;
  final _answerCtrl = TextEditingController();
  bool _wrongAnswer = false;

  // ── Breathing ─────────────────────────────────────────────────────────────
  late AnimationController _breatheCtrl;
  late Animation<double> _breatheAnim;
  int _breatheCycle = 0; // 0-based, 3 = done
  int _breathePhase = 0; // 0 inhale, 1 hold, 2 exhale
  static const _phaseDurations = [4, 4, 4];

  @override
  void initState() {
    super.initState();
    _questions = _buildQuestions();
    _breatheCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4));
    _breatheAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _breatheCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _answerCtrl.dispose();
    _breatheCtrl.dispose();
    super.dispose();
  }

  List<_Question> _buildQuestions() {
    final rng = math.Random();
    final pool = <_Question>[];
    // Addition
    final a = rng.nextInt(40) + 10;
    final b = rng.nextInt(40) + 10;
    pool.add(_Question('$a + $b = ?', a + b));
    // Multiplication
    final x = rng.nextInt(9) + 2;
    final y = rng.nextInt(9) + 2;
    pool.add(_Question('$x × $y = ?', x * y));
    // Subtraction (ensure positive)
    final p = rng.nextInt(50) + 30;
    final q = rng.nextInt(20) + 5;
    pool.add(_Question('$p − $q = ?', p - q));
    pool.shuffle(rng);
    return pool.take(3).toList();
  }

  // ── Breathing setup ───────────────────────────────────────────────────────

  void _startBreathe() {
    setState(() {
      _mode = _Mode.breathe;
      _breatheCycle = 0;
      _breathePhase = 0;
    });
    _runBreathPhase();
  }

  void _runBreathPhase() {
    final duration = Duration(seconds: _phaseDurations[_breathePhase]);
    if (_breathePhase == 0) {
      // Inhale: expand
      _breatheCtrl.duration = duration;
      _breatheCtrl.forward(from: 0.0);
    } else if (_breathePhase == 1) {
      // Hold: stay expanded
      _breatheCtrl.stop();
    } else {
      // Exhale: shrink
      _breatheCtrl.duration = duration;
      _breatheCtrl.reverse(from: 1.0);
    }

    Future.delayed(duration, () {
      if (!mounted || _mode != _Mode.breathe) return;
      final nextPhase = _breathePhase + 1;
      if (nextPhase >= 3) {
        // Cycle done
        final nextCycle = _breatheCycle + 1;
        if (nextCycle >= 3) {
          _onSuccess();
        } else {
          setState(() {
            _breatheCycle = nextCycle;
            _breathePhase = 0;
          });
          _runBreathPhase();
        }
      } else {
        setState(() => _breathePhase = nextPhase);
        _runBreathPhase();
      }
    });
  }

  // ── Success handler ───────────────────────────────────────────────────────

  Future<void> _onSuccess() async {
    setState(() => _mode = _Mode.success);
    await UsageTracker.saveEarnedTime(
      packageName: widget.app.packageName,
      minutes: 5,
    );
    if (!mounted) return;
    await Provider.of<GamificationService>(context, listen: false)
        .unlockProblemSolver();
  }

  // ── Math helpers ──────────────────────────────────────────────────────────

  void _checkAnswer() {
    final input = _answerCtrl.text.trim();
    final answer = int.tryParse(input);
    if (answer == null) return;
    if (answer == _questions[_qIndex].answer) {
      _answerCtrl.clear();
      setState(() => _wrongAnswer = false);
      if (_qIndex + 1 >= _questions.length) {
        _onSuccess();
      } else {
        setState(() => _qIndex++);
      }
    } else {
      HapticFeedback.lightImpact();
      setState(() => _wrongAnswer = true);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = CtrlColors.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(c),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.04),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: switch (_mode) {
                  _Mode.choose  => _ChooseView(key: const ValueKey('choose'), c: c, app: widget.app, onMath: () => setState(() { _qIndex = 0; _wrongAnswer = false; _answerCtrl.clear(); _questions = _buildQuestions(); _mode = _Mode.math; }), onBreathe: _startBreathe),
                  _Mode.math    => _MathView(key: const ValueKey('math'), c: c, questions: _questions, index: _qIndex, ctrl: _answerCtrl, wrong: _wrongAnswer, onCheck: _checkAnswer, onClear: () => setState(() => _wrongAnswer = false)),
                  _Mode.breathe => _BreatheView(key: const ValueKey('breathe'), c: c, anim: _breatheAnim, cycle: _breatheCycle, phase: _breathePhase),
                  _Mode.success => _SuccessView(key: const ValueKey('success'), c: c, appName: widget.app.appName, onDone: () => Navigator.of(context).pop()),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(CtrlColors c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 10, 16, 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: c.textSub),
            onPressed: () => Navigator.pop(context),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Earn Time',
                style: GoogleFonts.inter(
                    fontSize: 20, fontWeight: FontWeight.w700, color: c.text),
              ),
              Text(
                widget.app.appName,
                style: TextStyle(fontSize: 12, color: c.textSub),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: kColorSuccess.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kColorSuccess.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_circle_outline_rounded,
                    size: 14, color: kColorSuccess),
                const SizedBox(width: 4),
                Text(
                  '+5 min',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: kColorSuccess),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Choose view ───────────────────────────────────────────────────────────────

class _ChooseView extends StatelessWidget {
  final CtrlColors c;
  final AppLimit app;
  final VoidCallback onMath;
  final VoidCallback onBreathe;
  const _ChooseView({super.key, required this.c, required this.app, required this.onMath, required this.onBreathe});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Complete a challenge',
            style: GoogleFonts.inter(
                fontSize: 22, fontWeight: FontWeight.w800, color: c.text),
          ),
          const SizedBox(height: 6),
          Text(
            'Earn +5 minutes for ${app.appName} by finishing one of these.',
            style: TextStyle(fontSize: 14, color: c.textSub, height: 1.5),
          ),
          const SizedBox(height: 28),
          _OptionCard(
            c: c,
            emoji: '🧮',
            title: 'Math Puzzle',
            subtitle: '3 quick arithmetic questions\nAll must be answered correctly',
            accentColor: c.accent,
            onTap: onMath,
          ),
          const SizedBox(height: 14),
          _OptionCard(
            c: c,
            emoji: '🧘',
            title: 'Breathing Exercise',
            subtitle: '3 cycles of guided breathing\nInhale → Hold → Exhale (4s each)',
            accentColor: kColorSuccess,
            onTap: onBreathe,
          ),
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final CtrlColors c;
  final String emoji;
  final String title;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;
  const _OptionCard({required this.c, required this.emoji, required this.title, required this.subtitle, required this.accentColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: accentColor.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
                color: accentColor.withValues(alpha: 0.1), blurRadius: 18),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
                child: Text(emoji,
                    style: const TextStyle(fontSize: 28)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: c.text),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                        fontSize: 12, color: c.textSub, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 16, color: c.textMuted),
          ],
        ),
      ),
    );
  }
}

// ── Math puzzle view ──────────────────────────────────────────────────────────

class _MathView extends StatelessWidget {
  final CtrlColors c;
  final List<_Question> questions;
  final int index;
  final TextEditingController ctrl;
  final bool wrong;
  final VoidCallback onCheck;
  final VoidCallback onClear;
  const _MathView({super.key, required this.c, required this.questions, required this.index, required this.ctrl, required this.wrong, required this.onCheck, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final q = questions[index];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress dots
          Row(
            children: List.generate(questions.length, (i) {
              final done = i < index;
              final active = i == index;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  width: active ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: done
                        ? kColorSuccess
                        : active
                            ? c.accent
                            : c.border,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 28),
          Text(
            'Question ${index + 1} of ${questions.length}',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: c.textSub,
                letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                  color: wrong
                      ? kColorDanger.withValues(alpha: 0.4)
                      : c.border),
              boxShadow: [
                BoxShadow(
                    color: wrong
                        ? kColorDanger.withValues(alpha: 0.1)
                        : c.accent.withValues(alpha: 0.06),
                    blurRadius: 18),
              ],
            ),
            child: Column(
              children: [
                Text(
                  q.question,
                  style: GoogleFonts.inter(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: c.text,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (wrong) ...[
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.close_rounded,
                          color: kColorDanger, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Wrong — try again',
                        style: TextStyle(
                            color: kColorDanger,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),
          // Answer input
          TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
            ],
            onChanged: (_) {
              if (wrong) onClear();
            },
            onSubmitted: (_) => onCheck(),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: c.text,
            ),
            decoration: InputDecoration(
              hintText: 'Your answer',
              hintStyle: TextStyle(color: c.textMuted, fontSize: 18),
              filled: true,
              fillColor: c.card,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 16),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: c.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: c.accent, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: _PrimaryButton(
              label: index + 1 < questions.length ? 'Next' : 'Submit',
              color: c.accent,
              onTap: onCheck,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Breathing view ────────────────────────────────────────────────────────────

class _BreatheView extends StatelessWidget {
  final CtrlColors c;
  final Animation<double> anim;
  final int cycle;
  final int phase;
  const _BreatheView({super.key, required this.c, required this.anim, required this.cycle, required this.phase});

  static const _phaseColors = [
    Color(0xFF34C759), // inhale green
    Color(0xFFA78BFA), // hold purple
    Color(0xFF64D2FF), // exhale blue
  ];
  static const _phaseLabels = ['Inhale', 'Hold', 'Exhale'];
  static const _phaseSubs = [
    'Breathe in slowly through your nose',
    'Hold your breath gently',
    'Breathe out through your mouth',
  ];

  @override
  Widget build(BuildContext context) {
    final color = _phaseColors[phase];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      child: Column(
        children: [
          // Cycle dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              final done = i < cycle;
              final active = i == cycle;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done
                        ? kColorSuccess
                        : active
                            ? color
                            : c.border,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            'Cycle ${cycle + 1} of 3',
            style: TextStyle(fontSize: 12, color: c.textSub),
          ),
          const Spacer(),
          // Breathing ring
          AnimatedBuilder(
            animation: anim,
            builder: (_, __) => Container(
              width: 220 * anim.value,
              height: 220 * anim.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.08),
                border: Border.all(
                    color: color.withValues(alpha: 0.4), width: 3),
                boxShadow: [
                  BoxShadow(
                      color: color.withValues(alpha: 0.2 * anim.value),
                      blurRadius: 40,
                      spreadRadius: 4),
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _phaseLabels[phase],
                      style: GoogleFonts.inter(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '4s',
                      style: TextStyle(fontSize: 14, color: color.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
          Text(
            _phaseSubs[phase],
            style: TextStyle(fontSize: 14, color: c.textSub, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Success view ──────────────────────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  final CtrlColors c;
  final String appName;
  final VoidCallback onDone;
  const _SuccessView({super.key, required this.c, required this.appName, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kColorSuccess.withValues(alpha: 0.1),
              border: Border.all(
                  color: kColorSuccess.withValues(alpha: 0.4), width: 2),
              boxShadow: [
                BoxShadow(
                    color: kColorSuccess.withValues(alpha: 0.2),
                    blurRadius: 30),
              ],
            ),
            child: const Center(
              child: Text('⚡', style: TextStyle(fontSize: 48)),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            '+5 minutes earned!',
            style: GoogleFonts.inter(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: kColorSuccess,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Added to your $appName allowance\nfor today.',
            style: TextStyle(fontSize: 15, color: c.textSub, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: c.accent.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🧩', style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(
                  'Problem Solver achievement unlocked',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.accent),
                ),
              ],
            ),
          ),
          const SizedBox(height: 44),
          SizedBox(
            width: double.infinity,
            child: _PrimaryButton(
              label: 'Back to app',
              color: c.accent,
              onTap: onDone,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _PrimaryButton({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, Color.lerp(color, Colors.black, 0.18)!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 5)),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _Question {
  final String question;
  final int answer;
  const _Question(this.question, this.answer);
}
