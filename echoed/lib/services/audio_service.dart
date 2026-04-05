import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import 'tone_generator.dart';
import '../core/constants.dart';

// Platform-specific audio source factory.
// On web:    audio_platform_web.dart  (data URI, no dart:io)
// On native: audio_platform_io.dart   (temp file via dart:io + path_provider)
import 'audio_platform_io.dart'
    if (dart.library.html) 'audio_platform_web.dart';

/// ---------------------------------------------------------------------------
/// AudioService — manages playback of procedurally generated sine-wave tones.
///
/// Tones are synthesized in-memory as WAV bytes.
///
/// • Native (iOS / Android / desktop): bytes are written to a temp file and
///   played via AudioSource.file.
/// • Web: bytes are streamed as a data URI via AudioSource.uri — no filesystem
///   access required.
/// ---------------------------------------------------------------------------
class AudioService {
  AudioService();

  final AudioPlayer _player = AudioPlayer();

  /// In-memory WAV bytes cache: cacheKey -> WAV Uint8List.
  final Map<String, Uint8List> _wavCache = {};

  /// Native-only: cacheKey -> temp file path (populated by buildAudioSource).
  final Map<String, String> _fileCache = {};

  bool _isDisposed = false;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Pre-generate all tone WAV data for a game session.
  Future<void> preloadTones({
    required List<double> frequencies,
    required int seed,
    bool hardMode = false,
  }) async {
    await Future.wait([
      for (int i = 0; i < frequencies.length; i++)
        _ensureWav(
          seed: seed,
          toneIndex: i,
          frequencyHz: frequencies[i],
          hardMode: hardMode,
        ),
    ]);
  }

  /// Play the tone at [index]. Stops any currently playing tone first.
  Future<void> playTone({
    required List<double> frequencies,
    required int index,
    required int seed,
    bool hardMode = false,
  }) async {
    if (_isDisposed) return;
    await _player.stop();

    await _ensureWav(
      seed: seed,
      toneIndex: index,
      frequencyHz: frequencies[index],
      hardMode: hardMode,
    );

    final key = _cacheKey(seed, index, hardMode);
    final wavBytes = _wavCache[key];
    if (wavBytes == null) return;

    try {
      final source = await buildAudioSource(key, wavBytes, _fileCache);
      await _player.setAudioSource(source);
      await _player.play();
    } catch (_) {
      // Gracefully ignore playback failures (permissions, audio focus, etc.)
    }
  }

  /// Play a short preview of an arbitrary frequency (recreate-phase slider).
  Future<void> playPreviewHz(double frequencyHz) async {
    if (_isDisposed) return;
    await _player.stop();

    final wav = _buildWav(SineWaveSynthesizer.synthesize(
      frequencyHz: frequencyHz,
      durationSeconds: 0.5,
    ));

    try {
      final source = await buildPreviewSource(
        frequencyHz.toStringAsFixed(1),
        wav,
      );
      await _player.setAudioSource(source);
      await _player.play();
    } catch (_) {}
  }

  Future<void> stop() async {
    if (_isDisposed) return;
    await _player.stop();
  }

  Future<void> dispose() async {
    _isDisposed = true;
    await _player.dispose();
    clearNativeFiles(_fileCache);
    _wavCache.clear();
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  String _cacheKey(int seed, int index, bool hardMode) =>
      '${seed}_${index}_$hardMode';

  Future<void> _ensureWav({
    required int seed,
    required int toneIndex,
    required double frequencyHz,
    required bool hardMode,
  }) async {
    final key = _cacheKey(seed, toneIndex, hardMode);
    if (_wavCache.containsKey(key)) return;

    final overtoneHz = hardMode
        ? SineWaveSynthesizer.hardModeOvertoneHz(
            fundamentalHz: frequencyHz,
            seed: seed,
            toneIndex: toneIndex,
          )
        : null;

    final pcm = SineWaveSynthesizer.synthesize(
      frequencyHz: frequencyHz,
      overtoneHz: overtoneHz,
    );

    _wavCache[key] = _buildWav(pcm);
  }

  /// Builds a minimal valid WAV container around 16-bit PCM samples.
  Uint8List _buildWav(Uint8List pcm) {
    const int sampleRate = AppConstants.audioSampleRate;
    const int numChannels = 1;
    const int bitsPerSample = 16;
    const int byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    const int blockAlign = numChannels * bitsPerSample ~/ 8;
    final int dataSize = pcm.length;
    final int fileSize = 36 + dataSize;

    final hdr = ByteData(44);
    // RIFF
    hdr.setUint8(0, 0x52); hdr.setUint8(1, 0x49);
    hdr.setUint8(2, 0x46); hdr.setUint8(3, 0x46);
    hdr.setUint32(4, fileSize, Endian.little);
    hdr.setUint8(8, 0x57);  hdr.setUint8(9, 0x41);
    hdr.setUint8(10, 0x56); hdr.setUint8(11, 0x45);
    // fmt
    hdr.setUint8(12, 0x66); hdr.setUint8(13, 0x6D);
    hdr.setUint8(14, 0x74); hdr.setUint8(15, 0x20);
    hdr.setUint32(16, 16, Endian.little);
    hdr.setUint16(20, 1, Endian.little);
    hdr.setUint16(22, numChannels, Endian.little);
    hdr.setUint32(24, sampleRate, Endian.little);
    hdr.setUint32(28, byteRate, Endian.little);
    hdr.setUint16(32, blockAlign, Endian.little);
    hdr.setUint16(34, bitsPerSample, Endian.little);
    // data
    hdr.setUint8(36, 0x64); hdr.setUint8(37, 0x61);
    hdr.setUint8(38, 0x74); hdr.setUint8(39, 0x61);
    hdr.setUint32(40, dataSize, Endian.little);

    final wav = Uint8List(44 + pcm.length);
    wav.setRange(0, 44, hdr.buffer.asUint8List());
    wav.setRange(44, wav.length, pcm);
    return wav;
  }
}

/// Riverpod provider — single shared AudioService instance.
final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  ref.onDispose(() => service.dispose());
  return service;
});
