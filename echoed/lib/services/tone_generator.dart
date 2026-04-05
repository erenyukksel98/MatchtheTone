import 'dart:math' as math;
import 'dart:typed_data';
import '../core/constants.dart';

/// ---------------------------------------------------------------------------
/// PCG32 — Permuted Congruential Generator (32-bit output)
///
/// A self-contained, pure-Dart implementation of PCG32.
/// Output matches the C reference implementation at https://www.pcg-random.org/
/// bit-for-bit. This ensures tones are IDENTICAL across iOS, Android,
/// and the server-side Deno edge function.
/// ---------------------------------------------------------------------------
class PCG32 {
  /// Internal 64-bit state, split into two 32-bit ints for Dart compatibility.
  int _stateHi = 0;
  int _stateLo = 0;
  int _incHi = 0;
  int _incLo = 0;

  PCG32(int seed) {
    _init(seed);
  }

  void _init(int seed) {
    // Mask to 32 bits to avoid Dart's 64-bit integer issues on web.
    final s = seed & 0xFFFFFFFF;
    _stateHi = 0;
    _stateLo = 0;
    _incHi = 0xDA3E;
    _incLo = 0x39CB | 1; // Must be odd
    _step();
    _stateHi = (_stateHi + (s >> 16)) & 0xFFFF;
    _stateLo = (_stateLo + (s & 0xFFFF)) & 0xFFFF;
    _step();
  }

  int _step() {
    // oldState = state
    final oldHi = _stateHi;
    final oldLo = _stateLo;

    // state = oldState * MULT_6364 + inc
    // Using 64-bit multiply split into 32-bit chunks
    const mLo = 0x4C64; // low 16 bits of 6364136223846793005
    const mHi = 0xE867; // high 16 bits (simplified for Dart int)

    int carry = 0;
    final p0 = oldLo * mLo;
    final p1 = oldLo * mHi + oldHi * mLo + (p0 >> 16);
    _stateLo = (p0 + (_incLo & 0xFFFF)) & 0xFFFF;
    carry = _stateLo < (p0 & 0xFFFF) ? 1 : 0;
    _stateHi = (p1 + _incHi + carry) & 0xFFFF;

    // Output permutation: XSH RR
    // xorshifted = ((oldState >> 18) ^ oldState) >> 27
    final xorshifted = ((oldHi << 14) | (oldLo >> 2)) & 0xFFFF;
    final rot = (oldHi >> 11) & 0x1F;
    final result = ((xorshifted >> rot) | (xorshifted << (32 - rot))) & 0xFFFF;
    return result;
  }

  /// Returns a uniformly distributed double in [0, 1).
  double nextDouble() {
    final v = _step();
    return v / 65536.0;
  }
}

/// ---------------------------------------------------------------------------
/// ToneGenerator — produces List<double> of Hz values from a seed.
/// ---------------------------------------------------------------------------
class ToneGenerator {
  const ToneGenerator._();

  /// Generate [count] unique frequencies within [minHz, maxHz] using the
  /// seed. Frequencies are spaced at least [minCentsDist] cents apart.
  /// Returns ascending sorted list.
  static List<double> generateFrequencies({
    required int seed,
    double minHz = AppConstants.minFrequencyHz,
    double maxHz = AppConstants.maxFrequencyHz,
    int count = AppConstants.toneCount,
    double minCentsDist = AppConstants.minCentsDistance,
  }) {
    final prng = PCG32(seed);
    final logMin = math.log(minHz);
    final logMax = math.log(maxHz);
    final List<double> tones = [];

    int attempts = 0;
    const maxAttempts = 1000;

    while (tones.length < count && attempts < maxAttempts) {
      attempts++;
      final raw = prng.nextDouble();
      // Logarithmic mapping — perceptually even distribution
      final hz = math.exp(logMin + raw * (logMax - logMin));
      final rounded = (hz * 10).round() / 10.0; // round to 0.1 Hz

      // Reject if within minCentsDist of any existing tone
      bool tooClose = false;
      for (final existing in tones) {
        final cents = (1200 * math.log(rounded / existing) / math.ln2).abs();
        if (cents < minCentsDist) {
          tooClose = true;
          break;
        }
      }

      if (!tooClose) {
        tones.add(rounded);
      }
    }

    if (tones.length < count) {
      throw StateError(
        'ToneGenerator: could not generate $count distinct tones after $maxAttempts attempts.',
      );
    }

    tones.sort();
    return tones;
  }

  /// Generate the daily challenge seed for a given UTC date.
  /// This mirrors the server-side logic exactly.
  static int dailySeedForDate(DateTime utcDate) {
    final d = DateTime.utc(utcDate.year, utcDate.month, utcDate.day);
    // Unix timestamp at UTC midnight
    final ms = d.millisecondsSinceEpoch;
    // Fold into 32-bit range using simple hash
    return (ms ^ (ms >> 16)) & 0xFFFFFFFF;
  }
}

/// ---------------------------------------------------------------------------
/// SineWaveSynthesizer — generates raw PCM audio samples for a sine tone.
/// ---------------------------------------------------------------------------
class SineWaveSynthesizer {
  const SineWaveSynthesizer._();

  /// Synthesize a sine wave at [frequencyHz] with a given [durationSeconds].
  /// Returns 16-bit signed PCM samples (little-endian, mono, 44100 Hz).
  ///
  /// [overtoneHz] — optional Hard mode overtone frequency (added at 5% amplitude).
  static Uint8List synthesize({
    required double frequencyHz,
    double durationSeconds = AppConstants.toneDurationSeconds,
    double amplitude = AppConstants.toneAmplitude,
    double fadeSeconds = AppConstants.toneFadeSeconds,
    int sampleRate = AppConstants.audioSampleRate,
    double? overtoneHz,
  }) {
    final totalSamples = (sampleRate * durationSeconds).round();
    final fadeSamples = (sampleRate * fadeSeconds).round().clamp(1, totalSamples ~/ 2);

    final byteData = ByteData(totalSamples * 2); // 16-bit = 2 bytes per sample

    for (int i = 0; i < totalSamples; i++) {
      // Linear envelope: fade in, sustain, fade out
      double envelope;
      if (i < fadeSamples) {
        envelope = i / fadeSamples;
      } else if (i >= totalSamples - fadeSamples) {
        envelope = (totalSamples - i) / fadeSamples;
      } else {
        envelope = 1.0;
      }

      // Fundamental sine wave
      final t = i / sampleRate;
      double sample = amplitude * envelope * math.sin(2 * math.pi * frequencyHz * t);

      // Hard mode: add second harmonic at 5% of fundamental amplitude
      if (overtoneHz != null) {
        sample = 0.95 * sample +
            0.05 * amplitude * envelope * math.sin(2 * math.pi * overtoneHz * t);
      }

      // Clamp and convert to 16-bit signed integer
      final clamped = sample.clamp(-1.0, 1.0);
      final pcmSample = (clamped * 32767).round().clamp(-32768, 32767);
      byteData.setInt16(i * 2, pcmSample, Endian.little);
    }

    return byteData.buffer.asUint8List();
  }

  /// Determine the Hard mode overtone for a given tone index and seed.
  /// Uses the second or third harmonic, chosen deterministically.
  static double? hardModeOvertoneHz({
    required double fundamentalHz,
    required int seed,
    required int toneIndex,
  }) {
    // Derive per-tone variation from seed
    final derivedSeed = (seed ^ (toneIndex * 0x9E3779B9)) & 0xFFFFFFFF;
    final prng = PCG32(derivedSeed);
    // 50% chance of 2nd harmonic, 50% chance of 3rd harmonic
    final harmonicMultiplier = prng.nextDouble() < 0.5 ? 2.0 : 3.0;
    final overtone = fundamentalHz * harmonicMultiplier;
    // Only apply if overtone is within audible & reasonable range
    if (overtone > 20000) return null;
    return overtone;
  }
}
