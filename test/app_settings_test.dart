import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/models/app_settings.dart';

void main() {
  group('AppSettings', () {
    test('defaults disable Copilot attention sound and use Ping', () {
      final settings = AppSettings();

      expect(settings.copilotAttentionSoundEnabled, isFalse);
      expect(settings.copilotAttentionSound, CopilotAttentionSound.ping);
    });

    test('serializes and restores Copilot attention sound settings', () {
      final settings = AppSettings(
        copilotAttentionSoundEnabled: true,
        copilotAttentionSound: CopilotAttentionSound.sosumi,
      );

      final json = settings.toJson();
      final restored = AppSettings.fromJson(json);

      expect(restored.copilotAttentionSoundEnabled, isTrue);
      expect(restored.copilotAttentionSound, CopilotAttentionSound.sosumi);
    });

    test('ignores legacy OpenAI keys in serialized config', () {
      final restored = AppSettings.fromJson({
        'openAiApiKey': 'sk-legacy',
        'openAiTranscriptionModel': 'whisper-1',
        'openAiTtsVoice': 'nova',
      });

      expect(restored.toJson().containsKey('openAiApiKey'), isFalse);
      expect(restored.copilotAttentionSound, CopilotAttentionSound.ping);
    });

    test('falls back to Ping for unknown serialized sound values', () {
      final restored = AppSettings.fromJson({
        'copilotAttentionSound': 'unknown-sound',
      });

      expect(restored.copilotAttentionSound, CopilotAttentionSound.ping);
    });
  });
}
