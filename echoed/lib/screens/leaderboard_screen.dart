import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/constants.dart';
import '../models/user_model.dart';
import '../services/supabase_service.dart';

/// Leaderboard screen — daily challenge or session results.
class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({
    super.key,
    this.date,
    this.sessionCode,
  });

  final String? date;
  final String? sessionCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supabase = ref.read(supabaseServiceProvider);
    final isDaily = sessionCode == null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isDaily ? 'DAILY LEADERBOARD' : 'SESSION RESULTS'),
        leading: const BackButton(),
      ),
      body: FutureBuilder<List<LeaderboardEntry>>(
        future: isDaily
            ? supabase.fetchDailyLeaderboard(dateStr: date ?? _todayStr())
            : supabase.fetchSessionLeaderboard(sessionCode!),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (snap.hasError) {
            return Center(
              child: Text(
                'Failed to load leaderboard',
                style: AppTextStyles.bodyMedium,
              ),
            );
          }
          final entries = snap.data ?? [];
          if (entries.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.leaderboard_rounded, color: AppColors.textDisabled, size: 48),
                  const SizedBox(height: AppSpacing.md),
                  Text('No results yet', style: AppTextStyles.bodyMedium),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.lg),
            itemCount: entries.length,
            itemBuilder: (ctx, i) => _LeaderboardRow(
              entry: entries[i],
              delay: Duration(milliseconds: 50 * i),
            ),
          );
        },
      ),
    );
  }

  String _todayStr() {
    final d = DateTime.now().toUtc();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.entry, required this.delay});
  final LeaderboardEntry entry;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final isTop3 = entry.rank <= 3;
    final rankColor = _rankColor(entry.rank);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
      decoration: BoxDecoration(
        color: isTop3 ? rankColor.withOpacity(0.06) : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTop3 ? rankColor.withOpacity(0.3) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              isTop3 ? _rankEmoji(entry.rank) : '#${entry.rank}',
              style: isTop3
                  ? const TextStyle(fontSize: 20)
                  : AppTextStyles.headingMedium.copyWith(color: AppColors.textDisabled),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              entry.displayName,
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: isTop3 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _scoreColor(entry.totalScore).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              entry.totalScore.toStringAsFixed(1),
              style: AppTextStyles.freqReadout.copyWith(
                color: _scoreColor(entry.totalScore),
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: delay, duration: 250.ms).slideX(begin: 0.05);
  }

  String _rankEmoji(int rank) {
    switch (rank) {
      case 1: return '🥇';
      case 2: return '🥈';
      case 3: return '🥉';
      default: return '#$rank';
    }
  }

  Color _rankColor(int rank) {
    switch (rank) {
      case 1: return const Color(0xFFFFD700);
      case 2: return const Color(0xFFC0C0C0);
      case 3: return const Color(0xFFCD7F32);
      default: return AppColors.border;
    }
  }

  Color _scoreColor(double score) {
    if (score >= 95) return const Color(0xFF7BF696);
    if (score >= 80) return const Color(0xFFB0F67B);
    if (score >= 60) return const Color(0xFFF6D46A);
    if (score >= 40) return const Color(0xFFF6926A);
    return const Color(0xFFF66A6A);
  }
}
