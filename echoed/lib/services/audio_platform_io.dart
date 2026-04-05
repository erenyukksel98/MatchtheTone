import 'dart:io';
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

Future<AudioSource> buildAudioSource(
    String key, Uint8List wavBytes, Map<String, String> fileCache) async {
  if (!fileCache.containsKey(key)) {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/echoed_$key.wav');
    await file.writeAsBytes(wavBytes, flush: true);
    fileCache[key] = file.path;
  }
  return AudioSource.file(fileCache[key]!);
}

Future<AudioSource> buildPreviewSource(
    String label, Uint8List wavBytes) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/echoed_preview_$label.wav');
  await file.writeAsBytes(wavBytes, flush: true);
  return AudioSource.file(file.path);
}

void clearNativeFiles(Map<String, String> fileCache) {
  for (final path in fileCache.values) {
    try { File(path).deleteSync(); } catch (_) {}
  }
  fileCache.clear();
}
