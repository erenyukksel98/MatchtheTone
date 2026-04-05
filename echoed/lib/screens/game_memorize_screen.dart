import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';
import '../providers/game_provider.dart';
import '../services/tone_generator.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Root widget
// ─────────────────────────────────────────────────────────────────────────────

class GameMemorizeScreen extends ConsumerStatefulWidget {
  const GameMemorizeScreen({
    super.key,
    required this.seed,
    required this.mode,
    this.sessionCode,
  });

  final int seed;
  final String mode;
  final String? sessionCode;

  @override
  ConsumerState<GameMemorizeScreen> createState() =>
      _GameMemorizeScreenState();
}

class _GameMemorizeScreenState extends ConsumerState<GameMemorizeScreen>
    with TickerProviderStateMixin {
  // ── state ──────────────────────────────────────────────────────────────────
  late final List<double> _frequencies;
  late Timer _countdown;
  int _secondsRemaining = AppConstants.memorizeTimeLimitSeconds;
  int? _activeIndex;
  final Set<int> _playedIndices = {};

  // ── animation controllers ──────────────────────────────────────────────────
  late final AnimationController _pulseCtrl;   // ring pulse when playing
  late final AnimationController _ringCtrl;    // countdown ring
  late final AnimationController _readyCtrl;   // ready button glow

  @override
  void initState() {
    super.initState();

    _frequencies = ToneGenerator.generateFrequencies(seed: widget.seed);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(gameNotifierProvider.notifier).beginMemorization();
    });

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _ringCtrl = AnimationController(
      vsync: this,
      value: 1.0,
      duration: Duration(seconds: AppConstants.memorizeTimeLimitSeconds),
    )..reverse();

    _readyCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _secondsRemaining =
            (_secondsRemaining - 1).clamp(0, AppConstants.memorizeTimeLimitSeconds);
      });
      if (_secondsRemaining <= 0) _advance();
    });
  }

  @override
  void dispose() {
    _countdown.cancel();
    _pulseCtrl.dispose();
    _ringCtrl.dispose();
    _readyCtrl.dispose();
    super.dispose();
  }

  // ── actions ────────────────────────────────────────────────────────────────

  Future<void> _playTone(int index) async {
    HapticFeedback.mediumImpact();
    setState(() {
      _activeIndex = index;
      _playedIndices.add(index);
    });

    try {
      await ref.read(gameNotifierProvider.notifier).playTone(index);
      await Future<void>.delayed(
        Duration(
            milliseconds:
                (AppConstants.toneDurationSeconds * 1000).round() + 150),
      );
    } catch (_) {
      // Audio failure — still unblock the UI below.
    } finally {
      if (mounted) {
        setState(() => _activeIndex = null);
        // Trigger ready glow when all tones heard
        if (_playedIndices.length == _frequencies.length) {
          HapticFeedback.heavyImpact();
          _readyCtrl.repeat(reverse: true);
        }
      }
    }
  }

  void _advance() {
    _countdown.cancel();
    _ringCtrl.stop();
    _readyCtrl.stop();
    ref.read(gameNotifierProvider.notifier).endMemorization();
    if (!mounted) return;
    context.pushReplacement('/play/recreate', extra: {
      'seed': widget.seed,
      'mode': widget.mode,
      'frequencies': _frequencies,
      'sessionCode': widget.sessionCode,
    });
  }

  Future<void> _showExitDialog() async {
    HapticFeedback.lightImpact();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _ExitDialog(),
    );
    if (ok == true && mounted) {
      ref.read(gameNotifierProvider.notifier).resetGame();
      context.go('/');
    }
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final allPlayed = _playedIndices.length == _frequencies.length;
    final isLow = _secondsRemaining < 30;
    final isHard = widget.mode == 'hard';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── header ────────────────────────────────────────────────────
            _Header(
              mode: widget.mode,
              secondsRemaining: _secondsRemaining,
              progress: _secondsRemaining /
                  AppConstants.memorizeTimeLimitSeconds,
              isLow: isLow,
              onExit: _showExitDialog,
            ),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 28),

                    // ── Instruction ───────────────────────────────────────
                    Text(
                      'Tap each tone to listen. Memorize all five.',
                      style: AppTextStyles.bodyMedium,
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 200.ms),

                    if (isHard) ...[
                      const SizedBox(height: 10),
                      _HardBadge(),
                    ],

                    const SizedBox(height: 32),

                    // ── Countdown ring ────────────────────────────────────
                    _CountdownRing(
                      secondsRemaining: _secondsRemaining,
                      total: AppConstants.memorizeTimeLimitSeconds,
                      isLow: isLow,
                      activeIndex: _activeIndex,
                      pulseCtrl: _pulseCtrl,
                    ).animate().fadeIn(delay: 150.ms).scale(
                          begin: const Offset(0.9, 0.9),
                          curve: Curves.elasticOut,
                          duration: 500.ms,
                          delay: 150.ms,
                        ),

                    const SizedBox(height: 36),

                    // ── Tone cards ─────────────────────────────────────────
                    Text('TONES', style: AppTextStyles.labelLarge),
                    const SizedBox(height: 12),

                    Column(
                      children: List.generate(_frequencies.length, (i) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ToneCard(
                            index: i,
                            hz: _frequencies[i],
                            isActive: _activeIndex == i,
                            hasPlayed: _playedIndices.contains(i),
                            isDisabled: _activeIndex != null && _activeIndex != i,
                            pulseCtrl: _pulseCtrl,
                            showHz: false,
                            onTap: (_activeIndex != null && _activeIndex != i)
                                ? null
                                : () => _playTone(i),
                          )
                              .animate()
                              .fadeIn(
                                  delay: Duration(milliseconds: 60 * i + 400))
                              .slideX(
                                  begin: 0.05,
                                  delay:
                                      Duration(milliseconds: 60 * i + 400)),
                        );
                      }),
                    ),

                    const SizedBox(height: 8),

                    // ── Progress label ────────────────────────────────────
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        key: ValueKey(_playedIndices.length),
                        allPlayed
                            ? 'All tones heard — you\'re ready!'
                            : '${_playedIndices.length} of ${_frequencies.length} heard',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: allPlayed
                              ? AppColors.cyan
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Ready button ──────────────────────────────────────
                    AnimatedBuilder(
                      animation: _readyCtrl,
                      builder: (_, child) {
                        final glow = allPlayed ? _readyCtrl.value : 0.0;
                        return Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: allPlayed
                                ? [
                                    BoxShadow(
                                      color: AppColors.cyan
                                          .withOpacity(0.35 + glow * 0.25),
                                      blurRadius: 20 + glow * 16,
                                      spreadRadius: -4,
                                    ),
                                  ]
                                : [],
                          ),
                          child: child,
                        );
                      },
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: allPlayed ? _advance : null,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                allPlayed ? 'Recreate Tones' : 'Listen to All Tones First',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: allPlayed
                                      ? AppColors.background
                                      : AppColors.textDisabled,
                                ),
                              ),
                              if (allPlayed) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_rounded,
                                    size: 18),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ).animate().fadeIn(delay: 700.ms),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.mode,
    required this.secondsRemaining,
    required this.progress,
    required this.isLow,
    required this.onExit,
  });

  final String mode;
  final int secondsRemaining;
  final double progress;
  final bool isLow;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final mins = secondsRemaining ~/ 60;
    final secs = secondsRemaining % 60;
    final timeStr = '$mins:${secs.toString().padLeft(2, '0')}';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Close button
              GestureDetector(
                onTap: onExit,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: AppColors.textSecondary, size: 18),
                ),
              ),
              const Spacer(),
              // Mode label
              Text(_modeLabel(mode), style: AppTextStyles.labelLarge),
              const Spacer(),
              // Timer
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: AppTextStyles.timerDisplay.copyWith(
                  color: isLow ? AppColors.scoreBad : AppColors.textPrimary,
                ),
                child: Text(timeStr),
              ),
            ],
          ),
        ),
        // Thin progress bar
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          height: 2,
          color: Colors.transparent,
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(
              isLow ? AppColors.scoreBad : AppColors.cyan,
            ),
            minHeight: 2,
          ),
        ),
      ],
    );
  }

  String _modeLabel(String mode) {
    switch (mode) {
      case 'daily':       return 'DAILY CHALLENGE';
      case 'hard':        return 'HARD MODE';
      case 'multiplayer': return 'MULTIPLAYER';
      default:            return 'MEMORIZE';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hard mode badge
// ─────────────────────────────────────────────────────────────────────────────

class _HardBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.magenta.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.magenta.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.graphic_eq_rounded,
              color: AppColors.magenta, size: 13),
          const SizedBox(width: 6),
          Text(
            'HARD MODE — no Hz readout',
            style: AppTextStyles.labelLarge
                .copyWith(color: AppColors.magenta),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Countdown ring — central hero widget
// ─────────────────────────────────────────────────────────────────────────────

class _CountdownRing extends StatelessWidget {
  const _CountdownRing({
    required this.secondsRemaining,
    required this.total,
    required this.isLow,
    required this.activeIndex,
    required this.pulseCtrl,
  });

  final int secondsRemaining;
  final int total;
  final bool isLow;
  final int? activeIndex;
  final AnimationController pulseCtrl;

  @override
  Widget build(BuildContext context) {
    final progress = secondsRemaining / total;
    final ringColor = isLow ? AppColors.scoreBad : AppColors.cyan;
    final mins = secondsRemaining ~/ 60;
    final secs = secondsRemaining % 60;

    return SizedBox(
      width: 130,
      height: 130,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Animated ring
          AnimatedBuilder(
            animation: pulseCtrl,
            builder: (_, __) => CustomPaint(
              size: const Size(130, 130),
              painter: _RingPainter(
                progress: progress,
                ringColor: ringColor,
                pulseValue: activeIndex != null ? pulseCtrl.value : 0,
              ),
            ),
          ),
          // Inner content
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$mins:${secs.toString().padLeft(2, '0')}',
                style: AppTextStyles.timerDisplay.copyWith(
                  color: isLow ? AppColors.scoreBad : AppColors.textPrimary,
                  fontSize: 26,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                activeIndex != null ? 'playing...' : 'tap a tone',
                style: AppTextStyles.labelSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.ringColor,
    required this.pulseValue,
  });

  final double progress;
  final Color ringColor;
  final double pulseValue;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = (size.width - 12) / 2;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    // Background track
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi,
      false,
      Paint()
        ..color = AppColors.border
        ..strokeWidth = 6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Progress arc
    final progressPaint = Paint()
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + 2 * math.pi * progress,
        colors: [
          ringColor.withOpacity(0.5),
          ringColor,
        ],
        tileMode: TileMode.clamp,
      ).createShader(rect);

    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );

    // Pulsing glow ring when a tone is active
    if (pulseValue > 0) {
      canvas.drawCircle(
        Offset(cx, cy),
        r + 8 + pulseValue * 6,
        Paint()
          ..color = ringColor.withOpacity(0.08 + pulseValue * 0.06)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.pulseValue != pulseValue ||
      old.ringColor != ringColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// Tone card — full-width horizontal card
// ─────────────────────────────────────────────────────────────────────────────

class _ToneCard extends StatefulWidget {
  const _ToneCard({
    required this.index,
    required this.hz,
    required this.isActive,
    required this.hasPlayed,
    required this.isDisabled,
    required this.pulseCtrl,
    required this.onTap,
    this.showHz = true,
  });

  final int index;
  final double hz;
  final bool isActive;
  final bool hasPlayed;
  final bool isDisabled;
  final AnimationController pulseCtrl;
  final VoidCallback? onTap;
  final bool showHz;

  @override
  State<_ToneCard> createState() => _ToneCardState();
}

class _ToneCardState extends State<_ToneCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 180),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.toneColors[widget.index % AppColors.toneColors.length];

    return ScaleTransition(
      scale: Tween<double>(begin: 1.0, end: 0.97).animate(
        CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut),
      ),
      child: GestureDetector(
        onTapDown: widget.onTap != null ? (_) => _pressCtrl.forward() : null,
        onTapUp: widget.onTap != null
            ? (_) {
                _pressCtrl.reverse();
                widget.onTap!();
              }
            : null,
        onTapCancel: () => _pressCtrl.reverse(),
        child: AnimatedBuilder(
          animation: widget.pulseCtrl,
          builder: (_, __) {
            final pulse =
                widget.isActive ? widget.pulseCtrl.value : 0.0;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: widget.isActive
                    ? color.withOpacity(0.1)
                    : widget.hasPlayed
                        ? AppColors.surface
                        : AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.isActive
                      ? color
                      : widget.hasPlayed
                          ? color.withOpacity(0.35)
                          : AppColors.border,
                  width: widget.isActive ? 1.5 : 1,
                ),
                boxShadow: widget.isActive
                    ? [
                        BoxShadow(
                          color: color.withOpacity(0.15 + pulse * 0.2),
                          blurRadius: 16 + pulse * 12,
                          spreadRadius: -4,
                        ),
                      ]
                    : [],
              ),
              child: Row(
                children: [
                  // Number badge
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.isActive
                          ? color.withOpacity(0.2)
                          : widget.hasPlayed
                              ? color.withOpacity(0.1)
                              : AppColors.surfaceHigh,
                      border: Border.all(
                        color: widget.isActive
                            ? color
                            : widget.hasPlayed
                                ? color.withOpacity(0.4)
                                : AppColors.borderBright,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: widget.isActive
                          ? _PulsingBars(color: color, pulse: pulse)
                          : Text(
                              '${widget.index + 1}',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: widget.hasPlayed
                                    ? color
                                    : AppColors.textDisabled,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(width: 14),

                  // Label
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              'Tone ${widget.index + 1}',
                              style: AppTextStyles.headingSmall.copyWith(
                                color: widget.isDisabled && !widget.isActive
                                    ? AppColors.textDisabled
                                    : AppColors.textPrimary,
                              ),
                            ),
                            if (widget.showHz) ...[
                              const SizedBox(width: 8),
                              Text(
                                '${widget.hz.toStringAsFixed(0)} Hz',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: color.withOpacity(
                                    widget.isDisabled && !widget.isActive
                                        ? 0.3
                                        : 0.85,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.isActive
                              ? 'Playing...'
                              : widget.hasPlayed
                                  ? 'Heard ✓'
                                  : 'Tap to listen',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: widget.isActive
                                ? color
                                : widget.hasPlayed
                                    ? AppColors.scoreGood
                                    : AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Right-side mini waveform
                  SizedBox(
                    width: 64,
                    height: 32,
                    child: CustomPaint(
                      painter: _MiniWavePainter(
                        hz: widget.hz,
                        color: widget.isActive
                            ? color
                            : widget.hasPlayed
                                ? color.withOpacity(0.5)
                                : AppColors.textDisabled,
                        animPulse: pulse,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Play / replayed icon
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: widget.isActive
                        ? Icon(Icons.volume_up_rounded,
                            key: const ValueKey('active'),
                            color: color,
                            size: 20)
                        : widget.hasPlayed
                            ? Icon(Icons.replay_rounded,
                                key: const ValueKey('replay'),
                                color: color.withOpacity(0.6),
                                size: 18)
                            : Icon(Icons.play_circle_outline_rounded,
                                key: const ValueKey('play'),
                                color: AppColors.textDisabled,
                                size: 20),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Three animated bars shown inside the tone-number badge when playing.
class _PulsingBars extends StatelessWidget {
  const _PulsingBars({required this.color, required this.pulse});
  final Color color;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(3, (i) {
        final heights = [0.4, 1.0, 0.6];
        final h = 6.0 + heights[i] * 8.0 * pulse;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            width: 2.5,
            height: h.clamp(4.0, 14.0),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

/// Small inline sine wave drawn per tone card.
class _MiniWavePainter extends CustomPainter {
  const _MiniWavePainter({
    required this.hz,
    required this.color,
    this.animPulse = 0,
  });

  final double hz;
  final Color color;
  final double animPulse;

  @override
  void paint(Canvas canvas, Size size) {
    // Normalise frequency (200–1800 Hz) → 1–5 visible cycles
    final t = (math.log(hz / 200.0) / math.log(1800.0 / 200.0)).clamp(0.0, 1.0);
    final cycles = 1.5 + t * 3.0;
    final amplitude = (size.height * 0.35) * (1.0 + animPulse * 0.3);

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    for (int px = 0; px <= size.width.toInt(); px++) {
      final x = px.toDouble();
      final y = size.height / 2 +
          amplitude *
              math.sin((x / size.width) * cycles * 2 * math.pi + animPulse * math.pi);
      if (px == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_MiniWavePainter old) =>
      old.hz != hz || old.color != color || old.animPulse != animPulse;
}

// ─────────────────────────────────────────────────────────────────────────────
// Exit confirmation dialog
// ─────────────────────────────────────────────────────────────────────────────

class _ExitDialog extends StatelessWidget {
  const _ExitDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Leave game?'),
      content: const Text('Your current attempt will be lost.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Stay'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            'Leave',
            style: TextStyle(color: AppColors.scoreBad),
          ),
        ),
      ],
    );
  }
}
