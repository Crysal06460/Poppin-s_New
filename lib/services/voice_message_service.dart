import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:firebase_storage/firebase_storage.dart';

class VoiceMessageService {
  static final AudioRecorder _recorder = AudioRecorder();
  static String? _currentPath;

  static Future<bool> requestPermission() async {
    if (kIsWeb) return true;
    return await _recorder.hasPermission();
  }

  static Future<bool> startRecording() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) return false;

      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentPath = '${dir.path}/voice_$timestamp.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 44100,
        ),
        path: _currentPath!,
      );
      return true;
    } catch (e) {
      debugPrint('VoiceMessageService.startRecording error: $e');
      return false;
    }
  }

  static Future<String?> stopRecording() async {
    try {
      final path = await _recorder.stop();
      _currentPath = null;
      return path;
    } catch (e) {
      debugPrint('VoiceMessageService.stopRecording error: $e');
      return null;
    }
  }

  static Future<void> cancelRecording() async {
    try {
      await _recorder.cancel();
      if (_currentPath != null) {
        final file = File(_currentPath!);
        if (await file.exists()) {
          await file.delete();
        }
        _currentPath = null;
      }
    } catch (e) {
      debugPrint('VoiceMessageService.cancelRecording error: $e');
    }
  }

  static Future<bool> isRecording() async {
    return _recorder.isRecording();
  }

  static Future<({String url, int duration})> uploadAudio({
    required String localPath,
    required String conversationId,
    required String messageId,
  }) async {
    final file = File(localPath);
    if (!await file.exists()) {
      throw Exception('Fichier audio introuvable');
    }

    final bytes = await file.readAsBytes();
    final storagePath =
        'messages/$conversationId/audio/$messageId.m4a';
    final ref = FirebaseStorage.instance.ref().child(storagePath);

    await ref.putData(
      bytes,
      SettableMetadata(contentType: 'audio/m4a'),
    );

    final durationSec = await _estimateDuration(localPath);

    final url = await ref.getDownloadURL();

    await file.delete();

    return (url: url, duration: durationSec);
  }

  static Future<int> _estimateDuration(String path) async {
    try {
      final stat = await File(path).stat();
      final sizeBytes = stat.size;
      // 64000 bits/s => 8000 octets/s
      const bytesPerSecond = 8000;
      return max(1, (sizeBytes / bytesPerSecond).round());
    } catch (_) {
      return 0;
    }
  }

  static int max(int a, int b) => a > b ? a : b;
}
