import 'dart:convert';
import 'dart:io';

import 'package:tree_launcher/features/voice_commands/data/voice_logging.dart';

class TtsService {
  Process? _playbackProcess;
  bool _disposed = false;

  /// Synthesize speech from text using the OpenAI TTS API.
  /// Returns the path to the generated audio file.
  Future<String> synthesize({
    required String apiKey,
    required String text,
    String model = 'tts-1',
    String voice = 'nova',
  }) async {
    _log('Synthesizing TTS model=$model voice=$voice textLength=${text.length}');

    final tempDir = Directory.systemTemp;
    final outputPath =
        '${tempDir.path}/tl_tts_${DateTime.now().microsecondsSinceEpoch}.mp3';

    final client = HttpClient();
    try {
      final request = await client.postUrl(
        Uri.https('api.openai.com', '/v1/audio/speech'),
      );
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({
        'model': model,
        'input': text,
        'voice': voice,
        'response_format': 'mp3',
      }));

      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await utf8.decodeStream(response);
        throw Exception(_extractApiError(body));
      }

      final outputFile = File(outputPath);
      final sink = outputFile.openWrite();
      await response.pipe(sink);
      _log('TTS audio saved to $outputPath');
      return outputPath;
    } finally {
      client.close(force: true);
    }
  }

  /// Play an audio file using macOS afplay. Returns when playback finishes.
  Future<void> play(String audioPath) async {
    await stopPlayback();
    if (_disposed) return;

    _log('Playing TTS audio path=$audioPath');
    _playbackProcess = await Process.start('afplay', [audioPath]);
    await _playbackProcess?.exitCode;
    _playbackProcess = null;

    // Clean up the temp file after playback.
    final file = File(audioPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Synthesize and immediately play.
  Future<void> speak({
    required String apiKey,
    required String text,
    String model = 'tts-1',
    String voice = 'nova',
  }) async {
    final path = await synthesize(
      apiKey: apiKey,
      text: text,
      model: model,
      voice: voice,
    );
    await play(path);
  }

  bool get isPlaying => _playbackProcess != null;

  Future<void> stopPlayback() async {
    final process = _playbackProcess;
    if (process != null) {
      _log('Stopping TTS playback');
      process.kill();
      _playbackProcess = null;
    }
  }

  String _extractApiError(String responseBody) {
    try {
      final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
      final error = decoded['error'];
      if (error is Map<String, dynamic>) {
        final message = error['message'] as String?;
        if (message != null && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
    } catch (_) {}
    return responseBody.trim().isEmpty
        ? 'The OpenAI TTS request failed.'
        : responseBody.trim();
  }

  void _log(String message) {
    logVoice('TTS', message);
  }

  void dispose() {
    _disposed = true;
    stopPlayback();
  }
}
