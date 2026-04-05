import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';
import '../providers/auth_provider.dart';
import '../providers/game_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Root screen
// ─────────────────────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playCount   = ref.watch(playLimitProvider);
    final isPremium   = ref.watch(isPremiumProvider).valueOrNull ?? false;
    final remaining   = (AppConstants.freeGamesPerDay - playCount)
        .clamp(0, AppConstants.freeGamesPerDay);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _TopBar(isPremium: isPremium)),
            SliverToBoxAdapter(child: _StreakSection()),
            SliverToBoxAdapter(child: _DailyBanner()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Text('PLAY', style: AppTextStyles.labelLarge),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.separated(
                itemCount: 3,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) {
                  switch (i) {
                    case 0:
                      return _ModeCard(
                        label: 'Solo',
                        description: 'A fresh set of five tones, just for you.',
                        icon: Icons.headphones_rounded,
                        accentColor: AppColors.cyan,
                        delay: 0,
                        onTap: () => _startSolo(ctx, ref, isPremium, remaining),
                      );
                    case 1:
                      return _ModeCard(
                        label: 'Hard Mode',
                        description: 'Same tones — no frequency labels shown.',
                        icon: Icons.graphic_eq_rounded,
                        accentColor: AppColors.magenta,
                        delay: 60,
                        onTap: () => _startHard(ctx, ref, isPremium, remaining),
                      );
                    default:
                      return _ModeCard(
                        label: 'Play With Friends',
                        description: 'Share a 6-letter code — same tones for all.',
                        icon: Icons.group_rounded,
                        accentColor: const Color(0xFFFFAA00),
                        delay: 120,
                        onTap: () => ctx.push('/multi/lobby'),
                      );
                  }
                },
              ),
            ),
            SliverToBoxAdapter(child: _LeaderboardTeaser()),
            if (!isPremium)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: _FreeCountBadge(remaining: remaining),
                ).animate().fadeIn(delay: 300.ms),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        ),
      ),
      bottomNavigationBar: const _BottomNav(),
    );
  }

  Future<void> _startSolo(
      BuildContext ctx, WidgetRef ref, bool isPremium, int remaining) async {
    HapticFeedback.mediumImpact();
    if (!isPremium && remaining <= 0) {
      ctx.push('/premium', extra: {'triggerSource': 'daily_limit'});
      return;
    }
    await ref.read(gameNotifierProvider.notifier).startSoloGame();
    final game = ref.read(gameNotifierProvider);
    if (game == null || !ctx.mounted) return;
    ctx.push('/play/memorize', extra: {'seed': game.seed, 'mode': game.mode});
  }

  Future<void> _startHard(
      BuildContext ctx, WidgetRef ref, bool isPremium, int remaining) async {
    HapticFeedback.mediumImpact();
    if (!isPremium && remaining <= 0) {
      ctx.push('/premium', extra: {'triggerSource': 'daily_limit'});
      return;
    }
    await ref.read(gameNotifierProvider.notifier).startSoloGame(hardMode: true);
    final game = ref.read(gameNotifierProvider);
    if (game == null || !ctx.mounted) return;
    ctx.push('/play/memorize', extra: {'seed': game.seed, 'mode': game.mode});
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top bar
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.isPremium});
  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // Wordmark
          RichText(
            text: TextSpan(children: [
              TextSpan(
                text: 'ECH',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              TextSpan(
                text: 'OED',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.cyan,
                  letterSpacing: -0.5,
                ),
              ),
            ]),
          ),
          const Spacer(),
          if (isPremium) ...[
            _PremiumBadge(),
            const SizedBox(width: 8),
          ],
          _AvatarButton(),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

class _PremiumBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cyanDim,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cyan.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: AppColors.cyan, size: 12),
          const SizedBox(width: 4),
          Text('PRO',
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.cyan)),
        ],
      ),
    );
  }
}

class _AvatarButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push('/profile');
      },
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderBright),
        ),
        child: const Icon(Icons.person_rounded,
            color: AppColors.textSecondary, size: 18),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Streak section
// ─────────────────────────────────────────────────────────────────────────────

class _StreakSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Streak is stored via shared_preferences in the provider
    final streak = ref.watch(streakProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _StatPill(
            icon: Icons.local_fire_department_rounded,
            iconColor: const Color(0xFFFF7700),
            value: '$streak',
            label: 'day streak',
          ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.1),
          const SizedBox(width: 10),
          _StatPill(
            icon: Icons.emoji_events_rounded,
            iconColor: AppColors.cyan,
            value: '—',
            label: 'best score',
          ).animate().fadeIn(delay: 150.ms).slideX(begin: -0.05),
          const SizedBox(width: 10),
          _StatPill(
            icon: Icons.bolt_rounded,
            iconColor: AppColors.magenta,
            value: '—',
            label: 'games played',
          ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.05),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor, size: 16),
            const SizedBox(height: 6),
            Text(value,
                style: AppTextStyles.headingSmall
                    .copyWith(color: AppColors.textPrimary)),
            Text(label, style: AppTextStyles.labelSmall),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Daily challenge banner
// ─────────────────────────────────────────────────────────────────────────────

class _DailyBanner extends StatefulWidget {
  @override
  State<_DailyBanner> createState() => _DailyBannerState();
}

class _DailyBannerState extends State<_DailyBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveCtrl;

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final label =
        '${_month(today.month)} ${today.day}, ${today.year}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          context.push('/daily');
        },
        child: Container(
          height: 110,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [Color(0xFF0E1A1A), Color(0xFF0A0A14)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: AppColors.cyan.withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.cyan.withOpacity(0.08),
                blurRadius: 32,
                spreadRadius: -4,
              ),
            ],
          ),
          child: Stack(
            children: [
              // Animated waveform background
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _waveCtrl,
                  builder: (_, __) => CustomPaint(
                    painter: _AmbientWavePainter(
                      progress: _waveCtrl.value,
                      color: AppColors.cyan,
                    ),
                  ),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'DAILY CHALLENGE',
                            style: AppTextStyles.labelLarge
                                .copyWith(color: AppColors.cyan),
                          ),
                          const SizedBox(height: 4),
                          Text(label, style: AppTextStyles.headingSmall),
                          const SizedBox(height: 2),
                          Text(
                            'One attempt · same tones for everyone',
                            style: AppTextStyles.bodyMedium
                                .copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.cyan.withOpacity(0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppColors.cyan.withOpacity(0.4)),
                      ),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: AppColors.cyan, size: 22),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: -0.04);
  }

  String _month(int m) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[m - 1];
  }
}

/// Ambient scrolling sine-wave background used inside the daily banner.
class _AmbientWavePainter extends CustomPainter {
  const _AmbientWavePainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.07)
      ..style = PaintingStyle.fill;

    for (int wave = 0; wave < 2; wave++) {
      final path = Path();
      final yOffset = size.height * 0.55 + wave * 10.0;
      final phase = progress * math.pi * 2 + wave * math.pi;
      path.moveTo(0, yOffset);
      for (double x = 0; x <= size.width; x++) {
        final y = yOffset +
            math.sin((x / size.width) * math.pi * 4 + phase) *
                (10.0 - wave * 3.0);
        path.lineTo(x, y);
      }
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_AmbientWavePainter old) => old.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
// Mode card — with press animation
// ─────────────────────────────────────────────────────────────────────────────

class _ModeCard extends StatefulWidget {
  const _ModeCard({
    required this.label,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.onTap,
    this.delay = 0,
  });

  final String label;
  final String description;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;
  final int delay;

  @override
  State<_ModeCard> createState() => _ModeCardState();
}

class _ModeCardState extends State<_ModeCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97)
        .animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTapDown: (_) => _pressCtrl.forward(),
        onTapUp: (_) {
          _pressCtrl.reverse();
          widget.onTap();
        },
        onTapCancel: () => _pressCtrl.reverse(),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              // Icon container with neon glow
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: widget.accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: widget.accentColor.withOpacity(0.3), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: widget.accentColor.withOpacity(0.15),
                      blurRadius: 12,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: Icon(widget.icon,
                    color: widget.accentColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.label, style: AppTextStyles.headingSmall),
                    const SizedBox(height: 2),
                    Text(widget.description, style: AppTextStyles.bodyMedium),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  color: AppColors.textDisabled, size: 13),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms, delay: Duration(milliseconds: widget.delay + 250))
        .slideY(begin: 0.08, curve: Curves.easeOut);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Leaderboard teaser
// ─────────────────────────────────────────────────────────────────────────────

class _LeaderboardTeaser extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const entries = [
      ('aurora_k',  98),
      ('deep_ears', 91),
      ('synwave',   87),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('TODAY\'S TOP', style: AppTextStyles.labelLarge),
            const Spacer(),
            GestureDetector(
              onTap: () => context.push('/leaderboard'),
              child: Text(
                'VIEW ALL',
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.cyan),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: List.generate(entries.length, (i) {
                final (name, score) = entries[i];
                return _LeaderRow(
                  rank: i + 1,
                  name: name,
                  score: score,
                  isLast: i == entries.length - 1,
                );
              }),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.06);
  }
}

class _LeaderRow extends StatelessWidget {
  const _LeaderRow({
    required this.rank,
    required this.name,
    required this.score,
    required this.isLast,
  });
  final int rank;
  final String name;
  final int score;
  final bool isLast;

  static const List<Color> _rankColors = [
    Color(0xFFFFD700), // gold
    Color(0xFFC0C0C0), // silver
    Color(0xFFCD7F32), // bronze
  ];

  @override
  Widget build(BuildContext context) {
    final rankColor = _rankColors[rank - 1];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  '$rank',
                  style: AppTextStyles.labelLarge.copyWith(color: rankColor),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(name, style: AppTextStyles.bodyLarge),
              ),
              // Score bar
              SizedBox(
                width: 80,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: 40,
                      height: 4,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: score / 100.0,
                          backgroundColor: AppColors.surfaceTop,
                          valueColor: AlwaysStoppedAnimation<Color>(rankColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$score',
                      style: AppTextStyles.headingSmall
                          .copyWith(color: rankColor, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(height: 1, color: AppColors.border, indent: 16),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Free count badge
// ─────────────────────────────────────────────────────────────────────────────

class _FreeCountBadge extends StatelessWidget {
  const _FreeCountBadge({required this.remaining});
  final int remaining;

  @override
  Widget build(BuildContext context) {
    final isCritical = remaining == 0;
    return GestureDetector(
      onTap: () =>
          context.push('/premium', extra: {'triggerSource': 'home_badge'}),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isCritical
              ? AppColors.magentaDim.withOpacity(0.4)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isCritical
                ? AppColors.magenta.withOpacity(0.4)
                : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isCritical ? Icons.lock_rounded : Icons.timer_rounded,
              color: isCritical ? AppColors.magenta : AppColors.textSecondary,
              size: 16,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isCritical
                    ? 'No free games left today'
                    : '$remaining free ${remaining == 1 ? 'game' : 'games'} left today',
                style: AppTextStyles.bodyMedium,
              ),
            ),
            Text(
              'Upgrade',
              style: AppTextStyles.bodyMedium.copyWith(
                color: isCritical ? AppColors.magenta : AppColors.cyan,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom navigation bar
// ─────────────────────────────────────────────────────────────────────────────

class _BottomNav extends ConsumerWidget {
  const _BottomNav();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: NavigationBar(
        selectedIndex: 0,
        backgroundColor: Colors.transparent,
        onDestinationSelected: (i) {
          HapticFeedback.selectionClick();
          switch (i) {
            case 0: context.go('/');           break;
            case 1: context.push('/daily');    break;
            case 2: context.push('/multi/lobby'); break;
            case 3: context.push('/stats');    break;
            case 4: context.push('/profile');  break;
          }
        },
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.calendar_today_rounded), label: 'Daily'),
          NavigationDestination(
              icon: Icon(Icons.group_rounded), label: 'Friends'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart_rounded), label: 'Stats'),
          NavigationDestination(
              icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}
