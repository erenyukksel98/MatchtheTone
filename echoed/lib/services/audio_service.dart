import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'tone_generator.dart';
import '../core/constants.dart';

/// ---------------------------------------------------------------------------
/// AudioService — manages playback of procedurally generated sine-wave tones.
///
/// Tones are synthesized in memory, written to temp PCM files, and played
/// via just_audio. No external audio files or internet audio are used.
/// ---------------------------------------------------------------------------
class AudioService {
  AudioService();

  final AudioPlayer _player = AudioPlayer();

  /// Cache: seed+index+hardMode -> temp file path
  final Map<String, String> _toneFileCache = {};

  bool _isDisposed = false;

  /// Pre-generate and cache all tone files for a game session.
  /// Call this during the loading phase before the game begins.
  Future<void> preloadTones({
    required List<double> frequencies,
    required int seed,
    bool hardMode = false,
  }) async {
    final futures = <Future<void>>[];
    for (int i = 0; i < frequencies.length; i++) {
      futures.add(_ensureToneFile(
        seed: seed,
        toneIndex: i,
        frequencyHz: frequencies[i],
        hardMode: hardMode,
      ));
    }
    await Future.wait(futures);
  }

  /// Play tone at [index] in the list. Stops any currently playing tone.
  Future<void> playTone({
    required List<double> frequencies,
    required int index,
    required int seed,
    bool hardMode = false,
  }) async {
    if (_isDisposed) return;

    await _player.stop();

    await _ensureToneFile(
      seed: seed,
      toneIndex: index,
      frequencyHz: frequencies[index],
      hardMode: hardMode,
    );

    final key = _cacheKey(seed, index, hardMode);
    final path = _toneFileCache[key];
    if (path == null) return;

    try {
      // Load the raw PCM file — just_audio reads WAV; we write a minimal WAV header.
      await _player.setAudioSource(AudioSource.file(path));
      await _player.play();
    } catch (e) {
      // Gracefully handle playback failures (e.g. audio focus stolen)
    }
  }

  /// Play a preview of a single frequency (for slider preview button).
  Future<void> playPreviewHz(double frequencyHz) async {
    if (_isDisposed) return;
    await _player.stop();

    final tempPath = await _writeWavFile(
      pcm: SineWaveSynthesizer.synthesize(
        frequencyHz: frequencyHz,
        durationSeconds: 0.5,
      ),
      label: 'preview_${frequencyHz.toStringAsFixed(1)}',
    );

    try {
      await _player.setAudioSource(AudioSource.file(tempPath));
      await _player.play();
    } catch (e) {
      // Ignore
    }
  }

  Future<void> stop() async {
    if (_isDisposed) return;
    await _player.stop();
  }

  Future<void> dispose() async {
    _isDisposed = true;
    await _player.dispose();
    await _clearCache();
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  String _cacheKey(int seed, int index, bool hardMode) {
    return '${seed}_${index}_$hardMode';
  }

  Future<void> _ensureToneFile({
    required int seed,
    required int toneIndex,
    required double frequencyHz,
    required bool hardMode,
  }) async {
    final key = _cacheKey(seed, toneIndex, hardMode);
    if (_toneFileCache.containsKey(key)) return;

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

    final path = await _writeWavFile(
      pcm: pcm,
      label: '${seed}_$toneIndex',
    );
    _toneFileCache[key] = path;
  }

  /// Write a minimal valid WAV file from raw 16-bit PCM samples.
  /// The WAV header enables just_audio to decode it directly.
  Future<String> _writeWavFile({
    required Uint8List pcm,
    required String label,
  }) async {
    const int sampleRate = AppConstants.audioSampleRate;
    const int numChannels = 1;
    const int bitsPerSample = 16;
    const int byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    const int blockAlign = numChannels * bitsPerSample ~/ 8;
    final int dataChunkSize = pcm.length;
    final int fileSize = 36 + dataChunkSize;

    final header = ByteData(44);
    // RIFF chunk
    header.setUint8(0, 0x52); // 'R'
    header.setUint8(1, 0x49); // 'I'
    header.setUint8(2, 0x46); // 'F'
    header.setUint8(3, 0x46); // 'F'
    header.setUint32(4, fileSize, Endian.little);
    header.setUint8(8, 0x57);  // 'W'
    header.setUint8(9, 0x41);  // 'A'
    header.setUint8(10, 0x56); // 'V'
    header.setUint8(11, 0x45); // 'E'
    // fmt chunk
    header.setUint8(12, 0x66); // 'f'
    header.setUint8(13, 0x6D); // 'm'
    header.setUint8(14, 0x74); // 't'
    header.setUint8(15, 0x20); // ' '
    header.setUint32(16, 16, Endian.little); // Subchunk1Size = 16 for PCM
    header.setUint16(20, 1, Endian.little);  // AudioFormat = 1 (PCM)
    header.setUint16(22, numChannels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    // data chunk
    header.setUint8(36, 0x64); // 'd'
    header.setUint8(37, 0x61); // 'a'
    header.setUint8(38, 0x74); // 't'
    header.setUint8(39, 0x61); // 'a'
    header.setUint32(40, dataChunkSize, Endian.little);

    final wavBytes = Uint8List(44 + pcm.length);
    wavBytes.setRange(0, 44, header.buffer.asUint8List());
    wavBytes.setRange(44, 44 + pcm.length, pcm);

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/echoed_tone_$label.wav');
    await file.writeAsBytes(wavBytes, flush: true);
    return file.path;
  }

  Future<void> _clearCache() async {
    for (final path in _toneFileCache.values) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
    _toneFileCache.clear();
  }
}

/// Riverpod provider — single shared AudioService instance.
final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  ref.onDispose(() => service.dispose());
  return service;
});
