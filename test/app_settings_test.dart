import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/models/app_settings.dart';

void main() {
  group('AppSettings', () {
    test('defaults disable Copilot attention sound and use Ping', () {
      final settings = AppSettings();

      expect(settings.copilotAttentionSoundEnabled, isFalse);
      expect(settings.copilotAttentionSound, CopilotAttentionSound.ping);
      expect(settings.openAiApiKey, isNull);
      expect(settings.openAiTranscriptionModel, 'gpt-4o-transcribe');
      expect(settings.openAiResponseModel, 'gpt-5');
    });

    test('serializes and restores Copilot attention sound settings', () {
      final settings = AppSettings(
        copilotAttentionSoundEnabled: true,
        copilotAttentionSound: CopilotAttentionSound.sosumi,
        openAiApiKey: 'sk-test',
        openAiTranscriptionModel: 'gpt-4o-mini-transcribe',
        openAiResponseModel: 'gpt-5-mini',
      );

      final json = settings.toJson();
      final restored = AppSettings.fromJson(json);

      expect(restored.copilotAttentionSoundEnabled, isTrue);
      expect(restored.copilotAttentionSound, CopilotAttentionSound.sosumi);
      expect(restored.openAiApiKey, 'sk-test');
      expect(restored.openAiTranscriptionModel, 'gpt-4o-mini-transcribe');
      expect(restored.openAiResponseModel, 'gpt-5-mini');
    });

    test('falls back to Ping for unknown serialized sound values', () {
      final restored = AppSettings.fromJson({
        'copilotAttentionSound': 'unknown-sound',
      });

      expect(restored.copilotAttentionSound, CopilotAttentionSound.ping);
    });
  });
}
