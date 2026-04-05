import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/constants.dart';
import '../providers/game_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/waveform_painter.dart';

/// Main home screen — mode selector, daily challenge banner, navigation.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playCount = ref.watch(playLimitProvider);
    final isPremiumAsync = ref.watch(isPremiumProvider);
    final isPremium = isPremiumAsync.valueOrNull ?? false;
    final remaining = (AppConstants.freeGamesPerDay - playCount).clamp(0, AppConstants.freeGamesPerDay);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TopBar(isPremium: isPremium),
            const SizedBox(height: AppSpacing.lg),
            _DailyBanner(),
            const SizedBox(height: AppSpacing.xl),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PLAY',
                      style: AppTextStyles.labelLarge,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _ModeCard(
                      label: 'Solo',
                      description: 'A fresh set of five tones, right now.',
                      icon: Icons.headphones_rounded,
                      onTap: () => _startSolo(context, ref, isPremium, remaining),
                    ).animate().fadeIn(duration: 300.ms, delay: 50.ms).slideY(begin: 0.1),
                    const SizedBox(height: AppSpacing.sm),
                    _ModeCard(
                      label: 'Hard Mode',
                      description: 'Same five tones — with subtle timbre.',
                      icon: Icons.graphic_eq_rounded,
                      accentColor: AppColors.accent,
                      onTap: () => _startHard(context, ref, isPremium, remaining),
                    ).animate().fadeIn(duration: 300.ms, delay: 100.ms).slideY(begin: 0.1),
                    const SizedBox(height: AppSpacing.sm),
                    _ModeCard(
                      label: 'Play With Friends',
                      description: 'Share a code — same tones for everyone.',
                      icon: Icons.group_rounded,
                      accentColor: const Color(0xFFF6C06E),
                      onTap: () => context.push('/multi/lobby'),
                    ).animate().fadeIn(duration: 300.ms, delay: 150.ms).slideY(begin: 0.1),
                    const Spacer(),
                    if (!isPremium)
                      _FreeCountBadge(remaining: remaining)
                          .animate()
                          .fadeIn(duration: 300.ms, delay: 200.ms),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNav(),
    );
  }

  Future<void> _startSolo(
    BuildContext context,
    WidgetRef ref,
    bool isPremium,
    int remaining,
  ) async {
    HapticFeedback.mediumImpact();
    if (!isPremium && remaining <= 0) {
      context.push('/premium', extra: {'triggerSource': 'daily_limit'});
      return;
    }
    await ref.read(gameNotifierProvider.notifier).startSoloGame();
    final game = ref.read(gameNotifierProvider);
    if (game == null || !context.mounted) return;
    context.push('/play/memorize', extra: {
      'seed': game.seed,
      'mode': game.mode,
    });
  }

  Future<void> _startHard(
    BuildContext context,
    WidgetRef ref,
    bool isPremium,
    int remaining,
  ) async {
    HapticFeedback.mediumImpact();
    if (!isPremium && remaining <= 0) {
      context.push('/premium', extra: {'triggerSource': 'daily_limit'});
      return;
    }
    await ref.read(gameNotifierProvider.notifier).startSoloGame(hardMode: true);
    final game = ref.read(gameNotifierProvider);
    if (game == null || !context.mounted) return;
    context.push('/play/memorize', extra: {
      'seed': game.seed,
      'mode': game.mode,
    });
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.isPremium});
  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ECHOED', style: AppTextStyles.headingLarge),
              Text(
                'Five tones. One shot.',
                style: AppTextStyles.bodyMedium,
              ),
            ],
          ),
          const Spacer(),
          if (isPremium)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryDim,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary),
              ),
              child: Text(
                'PREMIUM',
                style: AppTextStyles.labelLarge.copyWith(color: AppColors.primaryGlow),
              ),
            ),
          const SizedBox(width: AppSpacing.sm),
          GestureDetector(
            onTap: () => context.push('/profile'),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.person_rounded, color: AppColors.textSecondary, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Daily banner ──────────────────────────────────────────────────────────────

class _DailyBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final label = '${today.day} ${_month(today.month)} ${today.year}';

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push('/daily');
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A1830), Color(0xFF0A0A18)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('DAILY CHALLENGE', style: AppTextStyles.labelLarge.copyWith(color: AppColors.primaryGlow)),
                  const SizedBox(height: 4),
                  Text(label, style: AppTextStyles.headingMedium),
                  const SizedBox(height: 4),
                  Text('One attempt. Same tones for everyone.', style: AppTextStyles.bodyMedium),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Mini static waveform as visual accent
            SizedBox(
              width: 80,
              height: 48,
              child: CustomPaint(
                painter: WaveformPainter(
                  targetHz: 440,
                  animationValue: 1.0,
                  targetColor: AppColors.primary.withOpacity(0.6),
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05);
  }

  String _month(int m) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return months[m - 1];
  }
}

// ── Mode card ─────────────────────────────────────────────────────────────────

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.label,
    required this.description,
    required this.icon,
    required this.onTap,
    this.accentColor = AppColors.primary,
  });

  final String label;
  final String description;
  final IconData icon;
  final VoidCallback onTap;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accentColor, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                  Text(description, style: AppTextStyles.bodyMedium),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textDisabled, size: 14),
          ],
        ),
      ),
    );
  }
}

// ── Free count badge ──────────────────────────────────────────────────────────

class _FreeCountBadge extends StatelessWidget {
  const _FreeCountBadge({required this.remaining});
  final int remaining;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/premium', extra: {'triggerSource': 'home_badge'}),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.timer_rounded, color: AppColors.textSecondary, size: 16),
            const SizedBox(width: 8),
            Text(
              '$remaining free ${remaining == 1 ? 'game' : 'games'} left today',
              style: AppTextStyles.bodyMedium,
            ),
            const Spacer(),
            Text('Go Premium', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primary)),
          ],
        ),
      ),
    );
  }
}

// ── Bottom nav ────────────────────────────────────────────────────────────────

class _BottomNav extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (i) {
          switch (i) {
            case 0: context.go('/'); break;
            case 1: context.push('/daily'); break;
            case 2: context.push('/multi/lobby'); break;
            case 3: context.push('/stats'); break;
            case 4: context.push('/profile'); break;
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.calendar_today_rounded), label: 'Daily'),
          NavigationDestination(icon: Icon(Icons.group_rounded), label: 'Friends'),
          NavigationDestination(icon: Icon(Icons.bar_chart_rounded), label: 'Stats'),
          NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}
