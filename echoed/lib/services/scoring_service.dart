import 'dart:math' as math;
import '../core/constants.dart';
import '../models/tone_model.dart';

/// ---------------------------------------------------------------------------
/// ScoringService — computes per-tone and total scores.
///
/// Primary formula (Hz-difference):
///   diff = |guessHz - targetHz|
///   score_i = 20  if diff ≤ 5 Hz         (perfect zone)
///           = 20 × (1 - (diff - 5) / 45)  if 5 < diff < 50 Hz  (linear fade)
///           = 0   if diff ≥ 50 Hz          (too far off)
///
/// Cents deviation is also stored for display (musical context).
/// Total score = sum of 5 per-tone scores (0–100).
/// ---------------------------------------------------------------------------
class ScoringService {
  const ScoringService._();

  static const double maxPointsPerTone = 20.0;

  // Hz-difference thresholds
  static const double _perfectThresholdHz = 5.0;
  static const double _zeroThresholdHz    = 50.0;

  // Cents formula constants (kept for display / legacy)
  static const double maxCentsForZero = 1200.0;

  // ── Hz-difference scoring (primary) ────────────────────────────────────────

  /// Compute the score for a single tone using Hz-difference (0–20 pts).
  ///
  /// 100 % (20 pts) when |diff| ≤ 5 Hz.
  /// Linear decay to 0 % (0 pts) at |diff| = 50 Hz.
  /// 0 % beyond 50 Hz.
  static double scoreToneHz(double guessHz, double targetHz) {
    final diff = (guessHz - targetHz).abs();
    if (diff <= _perfectThresholdHz) return maxPointsPerTone;
    if (diff >= _zeroThresholdHz) return 0.0;
    final t = (diff - _perfectThresholdHz) / (_zeroThresholdHz - _perfectThresholdHz);
    return maxPointsPerTone * (1.0 - t);
  }

  /// Hz percentage match for a single tone (0–100 %).
  static double hzMatchPercent(double guessHz, double targetHz) {
    return (scoreToneHz(guessHz, targetHz) / maxPointsPerTone) * 100.0;
  }

  /// Score a list of guesses using the Hz-difference formula.
  /// Returns an updated list of [ToneModel] with scores filled in.
  static List<ToneModel> scoreRound({
    required List<ToneModel> tones,
    required List<double> guesses,
  }) {
    assert(tones.length == guesses.length, 'Tone count must match guess count');
    return List.generate(tones.length, (i) {
      final target = tones[i].targetHz;
      final guess  = guesses[i];
      final cents  = deviationCents(guess, target);
      final points = scoreToneHz(guess, target);
      return tones[i].copyWith(
        guessHz:     guess,
        scoreCents:  cents,
        scorePoints: points,
      );
    });
  }

  // ── Shared helpers ─────────────────────────────────────────────────────────

  /// Deviation in cents between two frequencies (always positive).
  static double deviationCents(double guessHz, double targetHz) {
    if (targetHz <= 0 || guessHz <= 0) return maxCentsForZero;
    return (1200 * math.log(guessHz / targetHz) / math.ln2).abs();
  }

  /// Compute total score (0–100) from a list of scored tones.
  static double totalScore(List<ToneModel> scoredTones) {
    return scoredTones.fold(0.0, (sum, t) => sum + (t.scorePoints ?? 0));
  }

  /// Human-readable grade label for a total score (0–100).
  static String gradeLabel(double score) {
    for (final entry in AppConstants.scoreGrades.entries) {
      final range = entry.value;
      if (score >= range[0] && score <= range[1]) {
        return entry.key;
      }
    }
    return 'Off-key';
  }

  /// Personality message based on total score — shown on the Results screen.
  static String funnyMessage(double score) {
    if (score >= 98) return 'Absolute perfect pitch. Are you even human? 🤯';
    if (score >= 90) return 'Your ear is ${score.toStringAsFixed(0)}% sharp 🔥';
    if (score >= 80) return 'Seriously impressive — barely a Hz off 🎯';
    if (score >= 70) return 'Solid! A couple of tones slipped away 🎵';
    if (score >= 60) return 'Getting warmer — keep those ears training 🎧';
    if (score >= 50) return 'Somewhere in the ballpark 🏟️';
    if (score >= 35) return 'Your ears are... a work in progress 😅';
    if (score >= 20) return 'Even a broken clock is right twice a day 😂';
    return 'Tone-deaf legend. The audacity. Respect. 😂';
  }

  /// ARGB color for a per-tone score (for UI coloring).
  static int scoreColor(double scorePoints) {
    final pct = scorePoints / maxPointsPerTone;
    if (pct >= 0.95) return 0xFF00F5FF; // perfect — cyan
    if (pct >= 0.75) return 0xFF7BF696; // good — green
    if (pct >= 0.50) return 0xFFF6D46A; // mid — yellow
    if (pct >= 0.25) return 0xFFF6926A; // poor — orange
    return 0xFFFF4455;                   // bad — red
  }

  /// Percentage match string like "94.3 %" (based on Hz-difference score).
  static String percentMatch(double scorePoints) {
    final pct = (scorePoints / maxPointsPerTone) * 100;
    return '${pct.toStringAsFixed(1)}%';
  }
}
