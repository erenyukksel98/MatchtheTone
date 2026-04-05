import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/constants.dart';
import '../models/game_model.dart';
import '../providers/game_provider.dart';
import '../widgets/waveform_painter.dart';
import '../services/tone_generator.dart';

/// Memorization phase — player listens to all 5 tones before recreating them.
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
  ConsumerState<GameMemorizeScreen> createState() => _GameMemorizeScreenState();
}

class _GameMemorizeScreenState extends ConsumerState<GameMemorizeScreen>
    with SingleTickerProviderStateMixin {
  late final List<double> _frequencies;
  late final Timer _countdownTimer;
  int _secondsRemaining = AppConstants.memorizeTimeLimitSeconds;
  int? _activeIndex; // which tone is currently playing
  final Set<int> _playedIndices = {};

  // Pulse animation for active tone
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _frequencies = ToneGenerator.generateFrequencies(seed: widget.seed);

    // Begin memorize phase in provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(gameNotifierProvider.notifier).beginMemorization();
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    // Countdown timer
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _secondsRemaining =
            (_secondsRemaining - 1).clamp(0, AppConstants.memorizeTimeLimitSeconds);
      });
      if (_secondsRemaining <= 0) {
        _advance();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _playTone(int index) async {
    HapticFeedback.lightImpact();
    setState(() {
      _activeIndex = index;
      _playedIndices.add(index);
    });

    await ref.read(gameNotifierProvider.notifier).playTone(index);

    // Tone finishes after toneDurationSeconds
    await Future.delayed(
      Duration(milliseconds: (AppConstants.toneDurationSeconds * 1000).round() + 100),
    );
    if (mounted) {
      setState(() => _activeIndex = null);
    }
  }

  void _advance() {
    _countdownTimer.cancel();
    ref.read(gameNotifierProvider.notifier).endMemorization();

    if (!mounted) return;
    context.pushReplacement('/play/recreate', extra: {
      'seed': widget.seed,
      'mode': widget.mode,
      'frequencies': _frequencies,
      'sessionCode': widget.sessionCode,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isHard = widget.mode == 'hard';
    final progress = _secondsRemaining / AppConstants.memorizeTimeLimitSeconds;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              mode: widget.mode,
              secondsRemaining: _secondsRemaining,
              progress: progress,
              onExit: () => _showExitDialog(context),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Instruction text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                'Tap each tone to listen. Memorize all five.',
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ).animate().fadeIn(delay: 200.ms),

            if (isHard) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.graphic_eq_rounded, color: AppColors.accent, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'HARD MODE — timbre variation active',
                      style: AppTextStyles.labelLarge.copyWith(color: AppColors.accent),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 300.ms),
            ],

            const SizedBox(height: AppSpacing.xxl),

            // Tone indicators
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: List.generate(
                    _frequencies.length,
                    (i) => _ToneButton(
                      index: i,
                      hz: _frequencies[i],
                      isActive: _activeIndex == i,
                      hasBeenPlayed: _playedIndices.contains(i),
                      pulseController: _pulseController,
                      onTap: _activeIndex != null ? null : () => _playTone(i),
                    ).animate().fadeIn(delay: Duration(milliseconds: 50 * i + 400)).slideY(begin: 0.15),
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Played count
            Text(
              '${_playedIndices.length} of ${_frequencies.length} listened',
              style: AppTextStyles.bodyMedium,
            ),

            const SizedBox(height: AppSpacing.lg),

            // Ready button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _playedIndices.length == _frequencies.length ? _advance : null,
                  child: const Text('Ready — Recreate Tones'),
                ),
              ),
            ).animate().fadeIn(delay: 600.ms),

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Future<void> _showExitDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave game?'),
        content: const Text('Your progress will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave', style: TextStyle(color: AppColors.scoreBad)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      ref.read(gameNotifierProvider.notifier).resetGame();
      context.go('/');
    }
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.mode,
    required this.secondsRemaining,
    required this.progress,
    required this.onExit,
  });

  final String mode;
  final int secondsRemaining;
  final double progress;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final mins = secondsRemaining ~/ 60;
    final secs = secondsRemaining % 60;
    final timeStr = '$mins:${secs.toString().padLeft(2, '0')}';

    final isLow = secondsRemaining < 30;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Row(
            children: [
              GestureDetector(
                onTap: onExit,
                child: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
              ),
              const Spacer(),
              Text(
                _modeLabel(mode),
                style: AppTextStyles.labelLarge,
              ),
              const Spacer(),
              Text(
                timeStr,
                style: AppTextStyles.freqReadout.copyWith(
                  color: isLow ? AppColors.scoreBad : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        // Progress bar
        LinearProgressIndicator(
          value: progress,
          backgroundColor: AppColors.border,
          valueColor: AlwaysStoppedAnimation<Color>(
            isLow ? AppColors.scoreBad : AppColors.primary,
          ),
          minHeight: 2,
        ),
      ],
    );
  }

  String _modeLabel(String mode) {
    switch (mode) {
      case 'daily': return 'DAILY CHALLENGE';
      case 'hard': return 'HARD MODE';
      case 'multiplayer': return 'MULTIPLAYER';
      default: return 'MEMORIZE';
    }
  }
}

// ── Tone button ───────────────────────────────────────────────────────────────

class _ToneButton extends StatelessWidget {
  const _ToneButton({
    required this.index,
    required this.hz,
    required this.isActive,
    required this.hasBeenPlayed,
    required this.pulseController,
    required this.onTap,
  });

  final int index;
  final double hz;
  final bool isActive;
  final bool hasBeenPlayed;
  final AnimationController pulseController;
  final VoidCallback? onTap;

  static const List<Color> _colors = [
    Color(0xFF7B6EF6),
    Color(0xFF6EA8F6),
    Color(0xFF6EF6D4),
    Color(0xFFD46EF6),
    Color(0xFFF6A06E),
  ];

  @override
  Widget build(BuildContext context) {
    final color = _colors[index % _colors.length];

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Waveform display
          SizedBox(
            width: 56,
            height: 64,
            child: AnimatedBuilder(
              animation: pulseController,
              builder: (_, __) => CustomPaint(
                painter: ToneIndicatorPainter(
                  hz: hz,
                  pulseValue: pulseController.value,
                  isActive: isActive,
                  hasBeenPlayed: hasBeenPlayed,
                  accentColor: color,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Outer ring shows active state
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? color.withOpacity(0.2)
                  : hasBeenPlayed
                      ? color.withOpacity(0.08)
                      : AppColors.surface,
              border: Border.all(
                color: isActive
                    ? color
                    : hasBeenPlayed
                        ? color.withOpacity(0.5)
                        : AppColors.border,
                width: isActive ? 2 : 1.5,
              ),
            ),
            child: Center(
              child: isActive
                  ? Icon(Icons.volume_up_rounded, color: color, size: 24)
                  : Text(
                      '${index + 1}',
                      style: AppTextStyles.headingMedium.copyWith(
                        color: hasBeenPlayed ? color : AppColors.textDisabled,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          // Played indicator dot
          AnimatedContainer(
            duration: 200.ms,
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hasBeenPlayed ? color : Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }
}
