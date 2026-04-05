import 'tone_model.dart';

/// Possible states a game round can be in.
enum GamePhase { idle, memorizing, recalling, scoring, complete }

/// Game modes available in Echoed.
enum GameMode { solo, daily, hard, multiplayer }

/// Full state for a single round of Echoed.
class GameModel {
  const GameModel({
    required this.seed,
    required this.mode,
    required this.tones,
    this.phase = GamePhase.idle,
    this.sessionCode,
    this.memorizeStartTime,
    this.recallStartTime,
    this.totalScore,
    this.gradeLabel,
    this.isHardMode = false,
  });

  /// 64-bit integer seed — drives all tone generation.
  final int seed;

  /// Game mode string: 'solo', 'daily', 'hard', 'multiplayer'.
  final String mode;

  /// List of 5 tones with target + optional guess + optional score.
  final List<ToneModel> tones;

  /// Current phase of the game.
  final GamePhase phase;

  /// Multiplayer session code (null for solo/daily).
  final String? sessionCode;

  /// When the memorization phase began.
  final DateTime? memorizeStartTime;

  /// When the recall phase began.
  final DateTime? recallStartTime;

  /// Total score 0–100 (null until complete).
  final double? totalScore;

  /// Human-readable grade label.
  final String? gradeLabel;

  /// Whether hard mode overtones are active.
  final bool isHardMode;

  /// Seconds elapsed in memorization phase.
  int get memorizeElapsedSeconds {
    if (memorizeStartTime == null) return 0;
    return DateTime.now().difference(memorizeStartTime!).inSeconds;
  }

  /// Seconds remaining in memorization phase.
  int get memorizeRemainingSeconds {
    const limit = 300;
    final elapsed = memorizeElapsedSeconds;
    return (limit - elapsed).clamp(0, limit);
  }

  GameModel copyWith({
    GamePhase? phase,
    List<ToneModel>? tones,
    DateTime? memorizeStartTime,
    DateTime? recallStartTime,
    double? totalScore,
    String? gradeLabel,
  }) {
    return GameModel(
      seed: seed,
      mode: mode,
      tones: tones ?? this.tones,
      phase: phase ?? this.phase,
      sessionCode: sessionCode,
      memorizeStartTime: memorizeStartTime ?? this.memorizeStartTime,
      recallStartTime: recallStartTime ?? this.recallStartTime,
      totalScore: totalScore ?? this.totalScore,
      gradeLabel: gradeLabel ?? this.gradeLabel,
      isHardMode: isHardMode,
    );
  }
}
