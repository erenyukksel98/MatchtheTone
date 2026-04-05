import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/tone_model.dart';
import '../services/audio_service.dart';
import '../services/tone_generator.dart';

/// ---------------------------------------------------------------------------
/// SoundService — high-level audio API used by screens.
///
/// Wraps AudioService (low-level playback) and ToneGenerator (PCG32 synthesis)
/// behind a single clean interface.
///
/// All tone generation is 100% procedural — no external audio files.
/// ---------------------------------------------------------------------------
class SoundService {
  SoundService(this._audio);

  final AudioService _audio;

  // ── Tone generation ────────────────────────────────────────────────────────

  /// Generate 5 ToneModels from [seed].
  /// [hardMode] adds a deterministic harmonic overtone to each tone.
  List<ToneModel> generateTones({required int seed, bool hardMode = false}) {
    final frequencies = ToneGenerator.generateFrequencies(seed: seed);
    return frequencies.asMap().entries.map((e) {
      return ToneModel(index: e.key, targetHz: e.value);
    }).toList();
  }

  /// Generate tones for today's daily challenge using today's UTC date as seed.
  List<ToneModel> generateDailyTones({bool hardMode = false}) {
    final seed = ToneGenerator.dailySeedForDate(DateTime.now().toUtc());
    return generateTones(seed: seed, hardMode: hardMode);
  }

  // ── Playback ───────────────────────────────────────────────────────────────

  /// Pre-generate and cache all tones for a session before play begins.
  Future<void> preloadTones({
    required List<ToneModel> tones,
    required int seed,
    bool hardMode = false,
  }) async {
    await _audio.preloadTones(
      frequencies: tones.map((t) => t.targetHz).toList(),
      seed: seed,
      hardMode: hardMode,
    );
  }

  /// Play the tone at [toneIndex] from [tones].
  /// [isMemorize] is reserved for future envelope differentiation (memorize vs
  /// recall phase). Currently both phases use the same 1.5 s duration.
  Future<void> playTone(
    ToneModel tone, {
    required int seed,
    required int toneIndex,
    required List<ToneModel> allTones,
    bool isMemorize = true,
    bool hardMode = false,
  }) async {
    await _audio.playTone(
      frequencies: allTones.map((t) => t.targetHz).toList(),
      index: toneIndex,
      seed: seed,
      hardMode: hardMode,
    );
  }

  /// Play a short preview of [hz] — used by the frequency sliders.
  Future<void> previewHz(double hz) async {
    await _audio.playPreviewHz(hz);
  }

  /// Stop any currently playing tone.
  Future<void> stopAll() async {
    await _audio.stop();
  }
}

/// Singleton Riverpod provider — disposes the underlying AudioService on tear-down.
final soundServiceProvider = Provider<SoundService>((ref) {
  final audio = ref.watch(audioServiceProvider);
  return SoundService(audio);
});
