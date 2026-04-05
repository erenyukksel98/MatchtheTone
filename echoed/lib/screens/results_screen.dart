import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../models/tone_model.dart';
import '../providers/game_provider.dart';
import '../services/scoring_service.dart';
import '../widgets/waveform_painter.dart';

/// Results screen — shows score, grade, per-tone waveform comparison.
class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({
    super.key,
    required this.targetFrequencies,
    required this.guessedFrequencies,
    required this.seed,
    required this.mode,
    this.sessionCode,
  });

  final List<double> targetFrequencies;
  final List<double> guessedFrequencies;
  final int seed;
  final String mode;
  final String? sessionCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameNotifierProvider);
    final tones = game?.tones ?? _computeLocalTones();
    final totalScore = tones.fold(0.0, (s, t) => s + (t.scorePoints ?? 0));
    final grade = ScoringService.gradeLabel(totalScore);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.lg),
                _TopActions(onClose: () {
                  ref.read(gameNotifierProvider.notifier).resetGame();
                  context.go('/');
                }),
                const SizedBox(height: AppSpacing.xl),

                // Total score display
                _ScoreHero(totalScore: totalScore, grade: grade),
                const SizedBox(height: AppSpacing.xxl),

                // Per-tone breakdown
                Text('TONE BREAKDOWN', style: AppTextStyles.labelLarge),
                const SizedBox(height: AppSpacing.md),
                ...tones.asMap().entries.map((entry) =>
                    _ToneResultCard(
                      tone: entry.value,
                      delay: Duration(milliseconds: 150 * entry.key),
                    )),

                const SizedBox(height: AppSpacing.xl),

                // Action buttons
                _ActionRow(
                  mode: mode,
                  sessionCode: sessionCode,
                  totalScore: totalScore,
                  onPlayAgain: () {
                    ref.read(gameNotifierProvider.notifier).resetGame();
                    context.go('/');
                  },
                  onViewLeaderboard: mode == 'daily' || mode == 'multiplayer'
                      ? () => context.push('/leaderboard', extra: {
                            'date': _todayStr(),
                            'sessionCode': sessionCode,
                          })
                      : null,
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<ToneModel> _computeLocalTones() {
    return List.generate(targetFrequencies.length, (i) {
      final target = targetFrequencies[i];
      final guess = guessedFrequencies[i];
      final cents = ScoringService.deviationCents(guess, target);
      final points = ScoringService.scoreTone(guess, target);
      return ToneModel(
        index: i,
        targetHz: target,
        guessHz: guess,
        scoreCents: cents,
        scorePoints: points,
      );
    });
  }

  String _todayStr() {
    final d = DateTime.now().toUtc();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

// ── Top actions ───────────────────────────────────────────────────────────────

class _TopActions extends StatelessWidget {
  const _TopActions({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onClose,
          child: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
        ),
        const Spacer(),
        Text('RESULT', style: AppTextStyles.labelLarge),
        const Spacer(),
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            // Share via system share sheet
            // In a real implementation, render to image and share
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Share functionality — wire to Share plugin'),
                backgroundColor: AppColors.surface,
              ),
            );
          },
          child: const Icon(Icons.share_rounded, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

// ── Score hero ────────────────────────────────────────────────────────────────

class _ScoreHero extends StatelessWidget {
  const _ScoreHero({required this.totalScore, required this.grade});
  final double totalScore;
  final String grade;

  @override
  Widget build(BuildContext context) {
    final color = _gradeColor(totalScore);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: totalScore),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutCubic,
            builder: (ctx, value, _) {
              return Text(
                value.toStringAsFixed(1),
                style: AppTextStyles.scoreDisplay.copyWith(
                  color: color,
                  shadows: [
                    Shadow(color: color.withOpacity(0.4), blurRadius: 24),
                  ],
                ),
              );
            },
          ).animate().fadeIn(duration: 400.ms),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            'out of 100',
            style: AppTextStyles.bodyMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Text(
              grade.toUpperCase(),
              style: AppTextStyles.labelLarge.copyWith(color: color, fontSize: 14),
            ),
          ),
        ).animate().fadeIn(delay: 400.ms).scale(begin: const Offset(0.85, 0.85)),
      ],
    );
  }

  Color _gradeColor(double score) {
    if (score >= 95) return const Color(0xFF7BF696);
    if (score >= 80) return const Color(0xFFB0F67B);
    if (score >= 60) return const Color(0xFFF6D46A);
    if (score >= 40) return const Color(0xFFF6926A);
    return const Color(0xFFF66A6A);
  }
}

// ── Per-tone result card ──────────────────────────────────────────────────────

class _ToneResultCard extends StatelessWidget {
  const _ToneResultCard({required this.tone, required this.delay});
  final ToneModel tone;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final points = tone.scorePoints ?? 0;
    final cents = tone.scoreCents ?? 0;
    final guess = tone.guessHz ?? 0;
    final target = tone.targetHz;
    final color = Color(ScoringService.scoreColor(points));

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.15),
                  border: Border.all(color: color.withOpacity(0.5)),
                ),
                child: Center(
                  child: Text(
                    '${tone.index + 1}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
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
                        Text(
                          '${target.toStringAsFixed(1)} Hz',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('target', style: AppTextStyles.bodyMedium.copyWith(fontSize: 11)),
                        const SizedBox(width: 12),
                        Text(
                          '${guess.toStringAsFixed(1)} Hz',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('guess', style: AppTextStyles.bodyMedium.copyWith(fontSize: 11)),
                      ],
                    ),
                    Text(
                      '${cents.toStringAsFixed(0)} cents off',
                      style: AppTextStyles.bodyMedium.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              Text(
                '+${points.toStringAsFixed(1)}',
                style: AppTextStyles.headingMedium.copyWith(color: color),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Waveform overlay comparison
          AnimatedWaveform(
            targetHz: target,
            guessHz: guess,
            height: 60,
            animate: true,
          ),

          const SizedBox(height: 8),

          // Legend
          Row(
            children: [
              _WaveLegend(color: AppColors.accent, label: 'Target'),
              const SizedBox(width: AppSpacing.md),
              _WaveLegend(color: AppColors.primary, label: 'Your guess'),
              const Spacer(),
              Text(
                ScoringService.percentMatch(points),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: delay, duration: 300.ms).slideX(begin: 0.05);
  }
}

class _WaveLegend extends StatelessWidget {
  const _WaveLegend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 2,
          decoration: BoxDecoration(
            color: color.withOpacity(0.85),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: AppTextStyles.bodyMedium.copyWith(fontSize: 11)),
      ],
    );
  }
}

// ── Action row ────────────────────────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.mode,
    required this.sessionCode,
    required this.totalScore,
    required this.onPlayAgain,
    this.onViewLeaderboard,
  });

  final String mode;
  final String? sessionCode;
  final double totalScore;
  final VoidCallback onPlayAgain;
  final VoidCallback? onViewLeaderboard;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (onViewLeaderboard != null) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onViewLeaderboard,
              icon: const Icon(Icons.leaderboard_rounded),
              label: const Text('View Leaderboard'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onPlayAgain,
            child: const Text('Play Again'),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.1);
  }
}
