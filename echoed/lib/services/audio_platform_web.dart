import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';

Future<AudioSource> buildAudioSource(
    String key, Uint8List wavBytes, Map<String, String> fileCache) async {
  return AudioSource.uri(
    Uri.dataFromBytes(wavBytes, mimeType: 'audio/wav'),
  );
}

Future<AudioSource> buildPreviewSource(
    String label, Uint8List wavBytes) async {
  return AudioSource.uri(
    Uri.dataFromBytes(wavBytes, mimeType: 'audio/wav'),
  );
}

void clearNativeFiles(Map<String, String> fileCache) {
  // No-op on web; no files were written.
}
