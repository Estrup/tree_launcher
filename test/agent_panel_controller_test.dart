import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/features/agent/data/tts_service.dart';
import 'package:tree_launcher/features/agent/presentation/controllers/agent_panel_controller.dart';
import 'package:tree_launcher/features/agent/presentation/widgets/agent_input_bar.dart';
import 'package:tree_launcher/features/copilot/data/sound_service.dart';
import 'package:tree_launcher/features/copilot/presentation/controllers/copilot_controller.dart';
import 'package:tree_launcher/features/settings/domain/app_settings.dart';
import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';
import 'package:tree_launcher/features/voice_commands/data/chatgpt_service.dart';
import 'package:tree_launcher/features/voice_commands/data/microphone_recording_service.dart';
import 'package:tree_launcher/features/workspace/data/git_service.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:tree_launcher/services/config_service.dart';

void main() {
  group('AgentPanelController', () {
    test(
      'cancelRecording returns to idle and discards the active recording',
      () async {
        final microphoneService = FakeMicrophoneRecordingService();
        final controller = await createController(
          microphoneRecordingService: microphoneService,
        );

        addTearDown(() async {
          await microphoneService.disposeTempFile();
          controller.dispose();
        });

        await controller.startRecording();

        expect(controller.phase, AgentPanelPhase.recording);
        expect(microphoneService.hasActiveRecording, isTrue);

        await controller.cancelRecording();

        expect(controller.phase, AgentPanelPhase.idle);
        expect(microphoneService.cancelCount, 1);
        expect(microphoneService.hasActiveRecording, isFalse);
      },
    );

    test('closePanel cancels an active recording', () async {
      final microphoneService = FakeMicrophoneRecordingService();
      final controller = await createController(
        microphoneRecordingService: microphoneService,
      );

      addTearDown(() async {
        await microphoneService.disposeTempFile();
        controller.dispose();
      });

      controller.openPanel();
      await controller.startRecording();

      controller.closePanel();
      await pumpEventQueue();

      expect(controller.panelOpen, isFalse);
      expect(controller.phase, AgentPanelPhase.idle);
      expect(microphoneService.cancelCount, 1);
    });

    test('dispose cancels an active recording', () async {
      final microphoneService = FakeMicrophoneRecordingService();
      final controller = await createController(
        microphoneRecordingService: microphoneService,
      );

      await controller.startRecording();
      controller.dispose();
      await pumpEventQueue();

      expect(microphoneService.cancelCount, 1);
      expect(microphoneService.hasActiveRecording, isFalse);
    });

    test(
      'summarizes the active Copilot session and speaks the summary',
      () async {
        final chatGptService = FakeChatGptService(
          copilotSummary:
              'Copilot finished the refactor and is waiting on tests.',
        );
        final ttsService = FakeTtsService();
        final controller = await createController(
          chatGptService: chatGptService,
          ttsService: ttsService,
        );

        addTearDown(controller.dispose);

        final session = await controller.debugCopilotController.createSession(
          '/tmp/tree-launcher-summary-repo',
          '/tmp/tree-launcher-summary-repo',
          'demo-session',
        );
        final terminal = controller.debugCopilotController.terminalForSession(
          session.id,
        )!;
        terminal.terminal.write(
          'Plan updated.\nImplemented the shortcut handler.\nWaiting for tests to pass.\n',
        );

        await controller.handleCopilotSummaryShortcut();

        expect(chatGptService.summaryRequests, hasLength(1));
        expect(
          chatGptService.summaryRequests.single.sessionName,
          'demo-session',
        );
        expect(
          chatGptService.summaryRequests.single.output,
          contains('Implemented the shortcut handler.'),
        );
        expect(controller.messages.last.content, chatGptService.copilotSummary);
        expect(ttsService.spokenTexts, [chatGptService.copilotSummary]);
        expect(ttsService.stopCount, 1);
        expect(controller.phase, AgentPanelPhase.idle);
        expect(controller.errorMessage, isNull);
      },
    );

    test(
      'opens the panel with an error when no Copilot session is selected',
      () async {
        final controller = await createController();

        addTearDown(controller.dispose);

        await controller.handleCopilotSummaryShortcut();

        expect(controller.panelOpen, isTrue);
        expect(controller.errorMessage, contains('Select a Copilot session'));
      },
    );
  });

  group('AgentInputBar', () {
    testWidgets('shows a separate cancel control while recording', (
      WidgetTester tester,
    ) async {
      final microphoneService = FakeMicrophoneRecordingService();
      final controller = await createController(
        microphoneRecordingService: microphoneService,
      );

      addTearDown(() async {
        await microphoneService.disposeTempFile();
        controller.dispose();
      });

      await tester.pumpWidget(buildHarness(controller));

      expect(find.byTooltip('Cancel recording'), findsNothing);

      await tester.runAsync(controller.startRecording);
      await tester.pump();

      expect(find.byTooltip('Stop recording'), findsOneWidget);
      expect(find.byTooltip('Cancel recording'), findsOneWidget);

      await tester.tap(find.byTooltip('Cancel recording'));
      await tester.pump();

      expect(microphoneService.cancelCount, 1);
      expect(controller.phase, AgentPanelPhase.idle);
      expect(find.byTooltip('Cancel recording'), findsNothing);
    });
  });
}

Future<AgentPanelController> createController({
  FakeMicrophoneRecordingService? microphoneRecordingService,
  FakeChatGptService? chatGptService,
  FakeTtsService? ttsService,
}) async {
  final settingsController = SettingsController(
    configService: FakeConfigService(),
  );
  await settingsController.updateOpenAiApiKey('test-key');

  final workspaceController = WorkspaceController(
    gitService: FakeGitService(),
    configService: FakeConfigService(),
  );
  final copilotController = CopilotController.create(
    workspaceController: workspaceController,
    settingsController: settingsController,
    soundService: FakeSoundService(),
  );

  return AgentPanelController(
    microphoneRecordingService:
        microphoneRecordingService ?? FakeMicrophoneRecordingService(),
    chatGptService: chatGptService ?? FakeChatGptService(),
    workspaceController: workspaceController,
    settingsController: settingsController,
    copilotController: copilotController,
    recordingStartDelay: Duration.zero,
    playSystemSound: (_) {},
    ttsService: ttsService,
  );
}

Widget buildHarness(AgentPanelController controller) {
  return MaterialApp(
    home: Scaffold(
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => AgentInputBar(controller: controller),
      ),
    ),
  );
}

class FakeMicrophoneRecordingService extends MicrophoneRecordingService {
  String? _audioPath;
  int cancelCount = 0;

  bool get hasActiveRecording => _audioPath != null;

  @override
  Future<bool> requestMicrophoneAccess() async => true;

  @override
  Future<void> startRecording() async {
    final file = File(
      '${Directory.systemTemp.path}/tree-launcher-agent-audio-${DateTime.now().microsecondsSinceEpoch}.wav',
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
    cancelCount += 1;
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
  FakeChatGptService({this.copilotSummary = 'Copilot summary'});

  final String copilotSummary;
  final List<SummaryRequest> summaryRequests = [];

  @override
  Future<String> summarizeCopilotSessionOutput({
    required String apiKey,
    required String sessionName,
    required String output,
    required String model,
  }) async {
    summaryRequests.add(
      SummaryRequest(
        apiKey: apiKey,
        sessionName: sessionName,
        output: output,
        model: model,
      ),
    );
    return copilotSummary;
  }
}

class FakeTtsService extends TtsService {
  bool _isPlaying = false;
  int stopCount = 0;
  final List<String> spokenTexts = [];

  @override
  bool get isPlaying => _isPlaying;

  @override
  Future<void> speak({
    required String apiKey,
    required String text,
    String model = 'tts-1',
    String voice = 'nova',
  }) async {
    _isPlaying = true;
    spokenTexts.add(text);
    _isPlaying = false;
  }

  @override
  Future<void> stopPlayback() async {
    stopCount += 1;
    _isPlaying = false;
  }
}

class SummaryRequest {
  const SummaryRequest({
    required this.apiKey,
    required this.sessionName,
    required this.output,
    required this.model,
  });

  final String apiKey;
  final String sessionName;
  final String output;
  final String model;
}

class FakeSoundService extends SoundService {
  @override
  Future<void> playSystemSound(CopilotAttentionSound sound) async {}
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
