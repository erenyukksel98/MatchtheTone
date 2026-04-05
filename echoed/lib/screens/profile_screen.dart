import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/constants.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../services/supabase_service.dart';

/// Profile / Stats screen — account info, score history, settings.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider);
    final isPremiumAsync = ref.watch(isPremiumProvider);
    final isPremium = isPremiumAsync.valueOrNull ?? false;
    final supabaseUser = ref.watch(currentSupabaseUserProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('PROFILE'),
        leading: const BackButton(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.lg),

            // Account card
            _AccountCard(
              supabaseUser: supabaseUser,
              userAsync: userAsync,
              isPremium: isPremium,
            ).animate().fadeIn(),

            const SizedBox(height: AppSpacing.lg),

            // Stats section (premium only)
            if (isPremium)
              _StatsSection(userId: supabaseUser?.id)
                  .animate()
                  .fadeIn(delay: 200.ms)
            else
              _PremiumUpsell().animate().fadeIn(delay: 200.ms),

            const SizedBox(height: AppSpacing.xl),

            // Settings
            Text('SETTINGS', style: AppTextStyles.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            _SettingRow(
              icon: Icons.notifications_rounded,
              label: 'Daily Reminder',
              child: Switch(value: false, onChanged: (_) {}),
            ),
            _SettingRow(
              icon: Icons.vibration_rounded,
              label: 'Haptic Feedback',
              child: Switch(value: true, onChanged: (_) {}),
            ),
            _SettingRow(
              icon: Icons.info_rounded,
              label: 'About Echoed',
              onTap: () {},
            ),

            const SizedBox(height: AppSpacing.lg),

            // Auth actions
            if (supabaseUser != null) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async {
                    await ref.read(authNotifierProvider.notifier).signOut();
                    if (context.mounted) context.go('/');
                  },
                  child: const Text('Sign Out'),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _showAuthSheet(context),
                  child: const Text('Create Account / Sign In'),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  void _showAuthSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AuthSheet(),
    );
  }
}

// ── Account card ──────────────────────────────────────────────────────────────

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.supabaseUser,
    required this.userAsync,
    required this.isPremium,
  });

  final dynamic supabaseUser;
  final AsyncValue<UserModel?> userAsync;
  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    final profile = userAsync.valueOrNull;
    final name = profile?.displayName ?? 'Guest';
    final email = profile?.email ?? 'Not signed in';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Avatar — procedurally drawn initials
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDim],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'G',
                style: AppTextStyles.headingLarge.copyWith(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                Text(email, style: AppTextStyles.bodyMedium),
                if (isPremium) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryDim,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'PREMIUM',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.primaryGlow,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stats section ─────────────────────────────────────────────────────────────

class _StatsSection extends ConsumerWidget {
  const _StatsSection({this.userId});
  final String? userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (userId == null) {
      return const SizedBox.shrink();
    }
    final supabase = ref.read(supabaseServiceProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('YOUR STATS', style: AppTextStyles.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        FutureBuilder<PlayerStats?>(
          future: supabase.fetchPlayerStats(userId!),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            }
            final stats = snap.data;
            if (stats == null) {
              return Text('No stats yet', style: AppTextStyles.bodyMedium);
            }
            return Column(
              children: [
                Row(
                  children: [
                    _StatTile(label: 'GAMES', value: '${stats.gamesPlayed}'),
                    const SizedBox(width: AppSpacing.sm),
                    _StatTile(label: 'AVG', value: stats.avgScore.toStringAsFixed(1)),
                    const SizedBox(width: AppSpacing.sm),
                    _StatTile(label: 'BEST', value: stats.bestScore.toStringAsFixed(1)),
                    const SizedBox(width: AppSpacing.sm),
                    _StatTile(label: 'STREAK', value: '${stats.streakDays}d'),
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(value, style: AppTextStyles.headingMedium.copyWith(color: AppColors.primary)),
            const SizedBox(height: 2),
            Text(label, style: AppTextStyles.labelLarge.copyWith(fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// ── Premium upsell ────────────────────────────────────────────────────────────

class _PremiumUpsell extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/premium', extra: {'triggerSource': 'profile'}),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E1840), Color(0xFF0D0D20)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.bar_chart_rounded, color: AppColors.primaryGlow, size: 28),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Unlock Stats', style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                  Text('Score history, graphs, and streaks with Premium.',
                      style: AppTextStyles.bodyMedium),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ── Setting row ───────────────────────────────────────────────────────────────

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.label,
    this.child,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Widget? child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: AppTextStyles.bodyLarge)),
            child ?? const Icon(Icons.chevron_right_rounded, color: AppColors.textDisabled, size: 16),
          ],
        ),
      ),
    );
  }
}

// ── Auth bottom sheet ─────────────────────────────────────────────────────────

class _AuthSheet extends ConsumerStatefulWidget {
  const _AuthSheet();

  @override
  ConsumerState<_AuthSheet> createState() => _AuthSheetState();
}

class _AuthSheetState extends ConsumerState<_AuthSheet> {
  bool _isSignUp = false;
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isSignUp ? 'Create Account' : 'Sign In',
            style: AppTextStyles.headingLarge,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_isSignUp)
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(hintText: 'Display name'),
            ),
          if (_isSignUp) const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(hintText: 'Email'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _passwordCtrl,
            obscureText: true,
            decoration: const InputDecoration(hintText: 'Password'),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: authState.isLoading ? null : _submit,
              child: authState.isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textPrimary))
                  : Text(_isSignUp ? 'Create Account' : 'Sign In'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: TextButton(
              onPressed: () => setState(() => _isSignUp = !_isSignUp),
              child: Text(_isSignUp ? 'Already have an account? Sign in' : "Don't have an account? Sign up"),
            ),
          ),
          if (authState.hasError) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              authState.error.toString(),
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.scoreBad),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final notifier = ref.read(authNotifierProvider.notifier);
    if (_isSignUp) {
      await notifier.signUpWithEmail(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        displayName: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
      );
    } else {
      await notifier.signInWithEmail(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
    }
    if (mounted && !ref.read(authNotifierProvider).hasError) {
      Navigator.pop(context);
    }
  }
}
