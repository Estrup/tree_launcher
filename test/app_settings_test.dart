import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/models/app_settings.dart';

void main() {
  group('AppSettings', () {
    test('ignores legacy keys from removed features in serialized config', () {
      final restored = AppSettings.fromJson({
        'openAiApiKey': 'sk-legacy',
        'openAiTranscriptionModel': 'whisper-1',
        'openAiTtsVoice': 'nova',
        'copilotButtonMode': 'external',
        'copilotAttentionSound': 'sosumi',
        'copilotAddDirs': ['/tmp'],
        'markdownDocumentsFolder': '/docs',
        'markdownRecentFiles': ['/docs/a.md'],
        'prLaunchPrompt': 'Review #{number}',
        'prLaunchModel': 'opus',
        'themeName': 'vivid',
      });

      final json = restored.toJson();
      expect(restored.themeName, 'vivid');
      expect(json.containsKey('openAiApiKey'), isFalse);
      expect(json.keys.where((k) => k.startsWith('copilot')), isEmpty);
      expect(json.keys.where((k) => k.startsWith('markdown')), isEmpty);
      expect(json.keys.where((k) => k.startsWith('prLaunch')), isEmpty);
    });
  });
}
