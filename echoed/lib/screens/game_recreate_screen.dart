import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/constants.dart';
import '../providers/game_provider.dart';
import '../widgets/frequency_slider.dart';

/// Recall phase — player positions 5 sliders to recreate the memorized tones.
class GameRecreateScreen extends ConsumerStatefulWidget {
  const GameRecreateScreen({
    super.key,
    required this.seed,
    required this.mode,
    required this.targetFrequencies,
    this.sessionCode,
  });

  final int seed;
  final String mode;
  final List<double> targetFrequencies;
  final String? sessionCode;

  @override
  ConsumerState<GameRecreateScreen> createState() => _GameRecreateScreenState();
}

class _GameRecreateScreenState extends ConsumerState<GameRecreateScreen> {
  /// Current guess for each slider — initialized to log-midpoint (~600 Hz).
  late final List<double> _guesses;
  bool _isSubmitting = false;

  // Geometric midpoint of [200, 1800] Hz — exp of the log midpoint ≈ 600 Hz
  static double get _initialHz {
    return math.exp((math.log(AppConstants.minFrequencyHz) + math.log(AppConstants.maxFrequencyHz)) / 2);
  }

  @override
  void initState() {
    super.initState();
    // Start sliders at log midpoint (~600 Hz)
    _guesses = List.generate(
      widget.targetFrequencies.length,
      (_) => _initialHz,
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    HapticFeedback.heavyImpact();
    setState(() => _isSubmitting = true);

    final result = await ref.read(gameNotifierProvider.notifier).submitGuesses(_guesses);
    if (!mounted) return;

    if (result == null) {
      setState(() => _isSubmitting = false);
      return;
    }

    context.pushReplacement('/results', extra: {
      'targetFrequencies': widget.targetFrequencies,
      'guessedFrequencies': _guesses,
      'seed': widget.seed,
      'mode': widget.mode,
      'sessionCode': widget.sessionCode,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Row(
                children: [
                  const Icon(Icons.lock_rounded, color: AppColors.textDisabled, size: 18),
                  const SizedBox(width: 8),
                  Text('RECREATE', style: AppTextStyles.labelLarge),
                  const Spacer(),
                  Text(
                    _modeLabel(widget.mode),
                    style: AppTextStyles.bodyMedium,
                  ),
                ],
              ),
            ),
            Container(height: 1, color: AppColors.border),
            const SizedBox(height: AppSpacing.lg),

            // Instruction
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                'Drag each slider to match the tone you memorized.\nTap the speaker to preview your guess.',
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ).animate().fadeIn(delay: 100.ms),

            const SizedBox(height: AppSpacing.xl),

            // Sliders
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: List.generate(
                    widget.targetFrequencies.length,
                    (i) => FrequencySlider(
                      index: i,
                      initialHz: _guesses[i],
                      onChanged: (hz) => setState(() => _guesses[i] = hz),
                      onPreviewTap: () {
                        ref.read(gameNotifierProvider.notifier).previewGuess(_guesses[i]);
                      },
                      height: 320,
                    ).animate().fadeIn(delay: Duration(milliseconds: 60 * i + 200)).slideY(begin: 0.1),
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Submit button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.textPrimary,
                          ),
                        )
                      : const Text('Submit Guesses'),
                ),
              ),
            ).animate().fadeIn(delay: 500.ms),

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  String _modeLabel(String mode) {
    switch (mode) {
      case 'daily': return 'DAILY CHALLENGE';
      case 'hard': return 'HARD MODE';
      case 'multiplayer': return 'MULTIPLAYER';
      default: return 'SOLO';
    }
  }
}
