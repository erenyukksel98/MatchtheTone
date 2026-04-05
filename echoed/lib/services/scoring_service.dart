import 'dart:math' as math;
import '../core/constants.dart';
import '../models/tone_model.dart';

/// ---------------------------------------------------------------------------
/// ScoringService — computes per-tone and total scores.
///
/// Scoring formula:
///   deviation_cents = |1200 × log₂(guessHz / targetHz)|
///   score_i = max(0, 20 × (1 - deviation_cents / 1200))
///
/// Total score = sum of 5 per-tone scores (0–100).
/// ---------------------------------------------------------------------------
class ScoringService {
  const ScoringService._();

  static const double maxPointsPerTone = 20.0;
  static const double maxCentsForZero = 1200.0; // 1 octave

  /// Compute the deviation in cents between two frequencies.
  static double deviationCents(double guessHz, double targetHz) {
    if (targetHz <= 0 || guessHz <= 0) return maxCentsForZero;
    return (1200 * math.log(guessHz / targetHz) / math.ln2).abs();
  }

  /// Compute the score for a single tone (0–20).
  static double scoreTone(double guessHz, double targetHz) {
    final cents = deviationCents(guessHz, targetHz);
    return (maxPointsPerTone * (1.0 - cents / maxCentsForZero)).clamp(0, maxPointsPerTone);
  }

  /// Score a list of guesses against a list of targets.
  /// Returns an updated list of [ToneModel] with scores filled in.
  static List<ToneModel> scoreRound({
    required List<ToneModel> tones,
    required List<double> guesses,
  }) {
    assert(tones.length == guesses.length, 'Tone count must match guess count');
    return List.generate(tones.length, (i) {
      final target = tones[i].targetHz;
      final guess = guesses[i];
      final cents = deviationCents(guess, target);
      final points = scoreTone(guess, target);
      return tones[i].copyWith(
        guessHz: guess,
        scoreCents: cents,
        scorePoints: points,
      );
    });
  }

  /// Compute total score (0–100) from scored tones.
  static double totalScore(List<ToneModel> scoredTones) {
    return scoredTones.fold(0.0, (sum, t) => sum + (t.scorePoints ?? 0));
  }

  /// Return a human-readable grade label for a total score.
  static String gradeLabel(double score) {
    for (final entry in AppConstants.scoreGrades.entries) {
      final range = entry.value;
      if (score >= range[0] && score <= range[1]) {
        return entry.key;
      }
    }
    return 'Off-key';
  }

  /// Return a color (hex ARGB int) appropriate for a per-tone score.
  static int scoreColor(double scorePoints) {
    final pct = scorePoints / maxPointsPerTone;
    if (pct >= 0.95) return 0xFF7BF696; // perfect — green
    if (pct >= 0.75) return 0xFFB0F67B; // good — yellow-green
    if (pct >= 0.50) return 0xFFF6D46A; // mid — yellow
    if (pct >= 0.25) return 0xFFF6926A; // poor — orange
    return 0xFFF66A6A;                   // bad — red
  }

  /// Returns a percentage match string like "94.3%"
  static String percentMatch(double scorePoints) {
    final pct = (scorePoints / maxPointsPerTone) * 100;
    return '${pct.toStringAsFixed(1)}%';
  }
}
