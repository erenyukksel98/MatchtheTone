/// Minimal user model — mirrors the Supabase `users` table.
class UserModel {
  const UserModel({
    required this.id,
    this.email,
    this.displayName,
    this.isPremium = false,
    this.premiumUntil,
    this.createdAt,
  });

  final String id;
  final String? email;
  final String? displayName;
  final bool isPremium;
  final DateTime? premiumUntil;
  final DateTime? createdAt;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String?,
      displayName: json['display_name'] as String?,
      isPremium: json['is_premium'] as bool? ?? false,
      premiumUntil: json['premium_until'] != null
          ? DateTime.parse(json['premium_until'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'display_name': displayName,
        'is_premium': isPremium,
        'premium_until': premiumUntil?.toIso8601String(),
        'created_at': createdAt?.toIso8601String(),
      };

  UserModel copyWith({
    String? displayName,
    bool? isPremium,
    DateTime? premiumUntil,
  }) {
    return UserModel(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      isPremium: isPremium ?? this.isPremium,
      premiumUntil: premiumUntil ?? this.premiumUntil,
      createdAt: createdAt,
    );
  }
}

/// Result entry for leaderboard display.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.displayName,
    required this.totalScore,
    required this.mode,
    this.userId,
  });

  final int rank;
  final String displayName;
  final double totalScore;
  final String mode;
  final String? userId;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: json['rank'] as int,
      displayName: json['display_name'] as String? ?? 'Anonymous',
      totalScore: (json['total_score'] as num).toDouble(),
      mode: json['mode'] as String? ?? 'solo',
      userId: json['user_id'] as String?,
    );
  }
}

/// Aggregate stats for a player.
class PlayerStats {
  const PlayerStats({
    required this.gamesPlayed,
    required this.avgScore,
    required this.bestScore,
    required this.streakDays,
    required this.scoreHistory,
  });

  final int gamesPlayed;
  final double avgScore;
  final double bestScore;
  final int streakDays;
  final List<ScoreHistoryPoint> scoreHistory;

  factory PlayerStats.fromJson(Map<String, dynamic> json) {
    final history = (json['score_history'] as List<dynamic>? ?? [])
        .map((e) => ScoreHistoryPoint.fromJson(e as Map<String, dynamic>))
        .toList();
    return PlayerStats(
      gamesPlayed: json['games_played'] as int? ?? 0,
      avgScore: (json['avg_score'] as num?)?.toDouble() ?? 0,
      bestScore: (json['best_score'] as num?)?.toDouble() ?? 0,
      streakDays: json['streak_days'] as int? ?? 0,
      scoreHistory: history,
    );
  }
}

class ScoreHistoryPoint {
  const ScoreHistoryPoint({
    required this.date,
    required this.score,
  });

  final DateTime date;
  final double score;

  factory ScoreHistoryPoint.fromJson(Map<String, dynamic> json) {
    return ScoreHistoryPoint(
      date: DateTime.parse(json['submitted_at'] as String),
      score: (json['total_score'] as num).toDouble(),
    );
  }
}
