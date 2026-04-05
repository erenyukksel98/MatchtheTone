import 'package:flutter/foundation.dart';

/// Represents one pure sine-wave tone in a game round.
@immutable
class ToneModel {
  const ToneModel({
    required this.index,
    required this.targetHz,
    this.guessHz,
    this.scoreCents,
    this.scorePoints,
  });

  /// Position in the round (0–4).
  final int index;

  /// True target frequency in Hz (server/seed authoritative).
  final double targetHz;

  /// Player's guessed frequency in Hz (null until submitted).
  final double? guessHz;

  /// Absolute deviation in cents (null until scored).
  final double? scoreCents;

  /// Score for this tone out of 20 (null until scored).
  final double? scorePoints;

  ToneModel copyWith({
    double? guessHz,
    double? scoreCents,
    double? scorePoints,
  }) {
    return ToneModel(
      index: index,
      targetHz: targetHz,
      guessHz: guessHz ?? this.guessHz,
      scoreCents: scoreCents ?? this.scoreCents,
      scorePoints: scorePoints ?? this.scorePoints,
    );
  }

  Map<String, dynamic> toJson() => {
        'index': index,
        'target_hz': targetHz,
        'guess_hz': guessHz,
        'score_cents': scoreCents,
        'score_points': scorePoints,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ToneModel &&
          runtimeType == other.runtimeType &&
          index == other.index &&
          targetHz == other.targetHz;

  @override
  int get hashCode => index.hashCode ^ targetHz.hashCode;
}
