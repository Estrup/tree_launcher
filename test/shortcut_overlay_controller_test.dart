import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tree_launcher/models/app_settings.dart';
import 'package:tree_launcher/models/chatgpt_processing_result.dart';
import 'package:tree_launcher/providers/repo_provider.dart';
import 'package:tree_launcher/providers/settings_provider.dart';
import 'package:tree_launcher/services/chatgpt_service.dart';
import 'package:tree_launcher/services/config_service.dart';
import 'package:tree_launcher/services/git_service.dart';
import 'package:tree_launcher/services/microphone_recording_service.dart';
import 'package:tree_launcher/services/repo_action_tool_registry.dart';
import 'package:tree_launcher/services/shortcut_overlay_controller.dart';
import 'package:tree_launcher/features/voice_commands/presentation/widgets/shortcut_overlay.dart';

void main() {
  group('ShortcutOverlayController', () {
    test('requires an API key before recording', () async {
      final controller = ShortcutOverlayController(
        microphoneRecordingService: FakeMicrophoneRecordingService(),
        chatGptService: FakeChatGptService(),
        repoProvider: RepoProvider(
          gitService: FakeGitService(),
          configService: FakeConfigService(),
        ),
        settingsProvider: SettingsProvider(configService: FakeConfigService()),
      );

      addTearDown(controller.dispose);

      await controller.handleShortcut();

      expect(controller.phase, VoiceCommandPhase.error);
      expect(controller.detailLabel, contains('API key'));
    });

    test('shows transcript, then replaces it with the LLM response', () async {
      final settingsProvider = SettingsProvider(
        configService: FakeConfigService(),
      );
      await settingsProvider.updateOpenAiApiKey('test-key');
      final microphoneService = FakeMicrophoneRecordingService();
      final chatGptService = FakeChatGptService();
      final controller = ShortcutOverlayController(
        microphoneRecordingService: microphoneService,
        chatGptService: chatGptService,
        repoProvider: RepoProvider(
          gitService: FakeGitService(),
          configService: FakeConfigService(),
        ),
        settingsProvider: settingsProvider,
      );

      addTearDown(() async {
        await microphoneService.disposeTempFile();
        controller.dispose();
      });

      await controller.handleShortcut();
      expect(controller.phase, VoiceCommandPhase.recording);

      final submission = controller.handleShortcut();
      await Future<void>.delayed(Duration.zero);

      expect(controller.phase, VoiceCommandPhase.routing);
      expect(controller.detailLabel, 'open storymap');
      expect(controller.statusLabel, 'Transcript');

      chatGptService.completeResponse(
        const ChatGptProcessingResult(
          transcript: 'open storymap',
          responseText: 'Selected repository storymap.',
        ),
      );

      await submission;
      expect(controller.phase, VoiceCommandPhase.success);
      expect(controller.detailLabel, 'Selected repository storymap.');
      expect(controller.statusLabel, 'Response');
      expect(controller.transcript, 'open storymap');
    });
  });

  group('ShortcutOverlay', () {
    testWidgets('keeps a compact height for shorter detail text', (
      WidgetTester tester,
    ) async {
      _configureSurface(tester);

      final settingsProvider = SettingsProvider(
        configService: FakeConfigService(),
      );
      await settingsProvider.updateOpenAiApiKey('test-key');
      final microphoneService = FakeMicrophoneRecordingService();
      final controller = ShortcutOverlayController(
        microphoneRecordingService: microphoneService,
        chatGptService: FakeChatGptService(),
        repoProvider: RepoProvider(
          gitService: FakeGitService(),
          configService: FakeConfigService(),
        ),
        settingsProvider: settingsProvider,
      );

      addTearDown(() async {
        await microphoneService.disposeTempFile();
        controller.dispose();
      });

      await tester.runAsync(controller.handleShortcut);
      await tester.pumpWidget(_buildOverlayHarness(controller));
      await _settleOverlayTransitions(tester);

      final cardSize = tester.getSize(
        find.byKey(const ValueKey('shortcut-overlay-card')),
      );

      expect(cardSize.height, 100);
    });

    testWidgets(
      'grows for longer LLM output and then scrolls at a max height',
      (WidgetTester tester) async {
        _configureSurface(tester);

        final settingsProvider = SettingsProvider(
          configService: FakeConfigService(),
        );
        await settingsProvider.updateOpenAiApiKey('test-key');
        final microphoneService = FakeMicrophoneRecordingService();
        final chatGptService = FakeChatGptService(
          processingResult: ChatGptProcessingResult(
            transcript: 'open storymap',
            responseText: _longLlmResponse,
          ),
        );
        final controller = ShortcutOverlayController(
          microphoneRecordingService: microphoneService,
          chatGptService: chatGptService,
          repoProvider: RepoProvider(
            gitService: FakeGitService(),
            configService: FakeConfigService(),
          ),
          settingsProvider: settingsProvider,
        );

        addTearDown(() async {
          await microphoneService.disposeTempFile();
          controller.dispose();
        });

        await tester.pumpWidget(_buildOverlayHarness(controller));
        await _settleOverlayTransitions(tester);

        await tester.runAsync(controller.handleShortcut);
        await _settleOverlayTransitions(tester);

        await tester.runAsync(controller.handleShortcut);
        await tester.pump();
        await _settleOverlayTransitions(tester);

        final cardFinder = find.byKey(const ValueKey('shortcut-overlay-card'));
        final detailScrollFinder = find.byKey(
          const ValueKey('shortcut-overlay-detail-scroll'),
        );
        final scrollableFinder = find.descendant(
          of: detailScrollFinder,
          matching: find.byType(Scrollable),
        );

        final cardSize = tester.getSize(cardFinder);
        final scrollableState = tester.state<ScrollableState>(scrollableFinder);

        expect(cardSize.height, greaterThan(100));
        expect(cardSize.height, lessThanOrEqualTo(240));
        expect(scrollableState.position.maxScrollExtent, greaterThan(0));

        await tester.drag(detailScrollFinder, const Offset(0, -120));
        await tester.pump();

        expect(scrollableState.position.pixels, greaterThan(0));
      },
    );
  });
}

void _configureSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Widget _buildOverlayHarness(ShortcutOverlayController controller) {
  return MaterialApp(
    home: Scaffold(body: ShortcutOverlay(controller: controller)),
  );
}

Future<void> _settleOverlayTransitions(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

final _longLlmResponse = List<String>.generate(
  40,
  (index) =>
      'LLM response line ${index + 1}: this overlay should allow substantially '
      'more room before it starts clipping or hiding the generated output.',
).join('\n');

class FakeMicrophoneRecordingService extends MicrophoneRecordingService {
  String? _audioPath;

  @override
  Future<bool> requestMicrophoneAccess() async => true;

  @override
  Future<void> startRecording() async {
    final file = File(
      '${Directory.systemTemp.path}/tree-launcher-test-audio-${DateTime.now().microsecondsSinceEpoch}.wav',
    );
    await file.writeAsBytes(const [1, 2, 3, 4]);
    _audioPath = file.path;
  }

  @override
  Future<String> stopRecordingAndTrim() async {
    if (_audioPath == null) {
      throw StateError('Recording was never started.');
    }

    return _audioPath!;
  }

  @override
  Future<void> cancelRecording() async {
    await disposeTempFile();
  }

  Future<void> disposeTempFile() async {
    if (_audioPath == null) {
      return;
    }

    final file = File(_audioPath!);
    if (await file.exists()) {
      await file.delete();
    }
    _audioPath = null;
  }
}

class FakeChatGptService extends ChatGptService {
  FakeChatGptService({
    this.transcript = 'open storymap',
    this.processingResult,
  });

  final String transcript;
  final ChatGptProcessingResult? processingResult;
  final Completer<ChatGptProcessingResult> _responseCompleter =
      Completer<ChatGptProcessingResult>();

  @override
  Future<String> transcribeAudio({
    required String apiKey,
    required String audioPath,
    required String model,
  }) async => transcript;

  @override
  Future<ChatGptProcessingResult> processTranscriptCommand({
    required String apiKey,
    required String transcript,
    required String responseModel,
    required RepoActionToolRegistry toolRegistry,
  }) async => processingResult ?? _responseCompleter.future;

  void completeResponse(ChatGptProcessingResult result) {
    if (!_responseCompleter.isCompleted) {
      _responseCompleter.complete(result);
    }
  }
}

class FakeConfigService extends ConfigService {
  AppSettings? _settings;

  @override
  Future<AppSettings> loadSettings() async => _settings ?? AppSettings();

  @override
  Future<void> saveSettings(AppSettings settings) async {
    _settings = settings;
  }
}

class FakeGitService extends GitService {}
