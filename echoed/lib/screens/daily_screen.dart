import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/constants.dart';
import '../providers/game_provider.dart';

/// Daily Challenge entry screen — shows today's date, global attempt count,
/// and lets the player begin (one attempt per day).
class DailyScreen extends ConsumerStatefulWidget {
  const DailyScreen({super.key});

  @override
  ConsumerState<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends ConsumerState<DailyScreen> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().toUtc();
    final dateStr = '${today.year}-${_month(today.month)} ${today.day}';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('DAILY CHALLENGE'),
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xl),

              Text(dateStr, style: AppTextStyles.headingLarge)
                  .animate()
                  .fadeIn(delay: 100.ms),

              const SizedBox(height: AppSpacing.sm),

              Text(
                'Every player around the world hears the same five tones today. One attempt.',
                style: AppTextStyles.bodyMedium,
              ).animate().fadeIn(delay: 200.ms),

              const SizedBox(height: AppSpacing.xl),

              // Rules card
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _RuleRow(icon: Icons.hearing_rounded, text: '300 seconds to memorize all five tones'),
                    _RuleRow(icon: Icons.tune_rounded, text: 'Recreate each tone on a frequency slider'),
                    _RuleRow(icon: Icons.leaderboard_rounded, text: 'Scores go to the global daily leaderboard'),
                    _RuleRow(icon: Icons.event_repeat_rounded, text: 'New tones every day at 00:00 UTC', isLast: true),
                  ],
                ),
              ).animate().fadeIn(delay: 300.ms),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _begin,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textPrimary),
                        )
                      : const Text('Begin Daily Challenge'),
                ),
              ).animate().fadeIn(delay: 500.ms),

              const SizedBox(height: AppSpacing.sm),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.push('/leaderboard', extra: {
                    'date': _todayDbStr(),
                  }),
                  child: const Text('View Leaderboard'),
                ),
              ).animate().fadeIn(delay: 600.ms),

              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _begin() async {
    HapticFeedback.mediumImpact();
    setState(() => _loading = true);
    try {
      await ref.read(gameNotifierProvider.notifier).startDailyChallenge();
      final game = ref.read(gameNotifierProvider);
      if (game == null || !mounted) return;
      context.pushReplacement('/play/memorize', extra: {
        'seed': game.seed,
        'mode': game.mode,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load daily challenge: $e'),
            backgroundColor: AppColors.scoreBad,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _month(int m) {
    const months = ['January','February','March','April','May','June',
        'July','August','September','October','November','December'];
    return months[m - 1];
  }

  String _todayDbStr() {
    final d = DateTime.now().toUtc();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.icon, required this.text, this.isLast = false});
  final IconData icon;
  final String text;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 18),
              const SizedBox(width: 12),
              Expanded(child: Text(text, style: AppTextStyles.bodyMedium)),
            ],
          ),
        ),
        if (!isLast) Divider(color: AppColors.border, height: 1),
      ],
    );
  }
}
