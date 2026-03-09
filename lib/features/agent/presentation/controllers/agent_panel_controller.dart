import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:tree_launcher/features/agent/data/agent_conversation_service.dart';
import 'package:tree_launcher/features/agent/data/agent_tool_registry.dart';
import 'package:tree_launcher/features/agent/data/copilot_tool_registry.dart';
import 'package:tree_launcher/features/agent/data/tts_service.dart';
import 'package:tree_launcher/features/agent/domain/agent_message.dart';
import 'package:tree_launcher/features/copilot/presentation/controllers/copilot_controller.dart';
import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';
import 'package:tree_launcher/features/voice_commands/data/chatgpt_service.dart';
import 'package:tree_launcher/features/voice_commands/data/microphone_recording_service.dart';
import 'package:tree_launcher/features/voice_commands/data/repo_action_tool_registry.dart';
import 'package:tree_launcher/features/voice_commands/data/voice_logging.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';

enum AgentPanelPhase { idle, recording, processing }

class AgentPanelController extends ChangeNotifier {
  AgentPanelController({
    required MicrophoneRecordingService microphoneRecordingService,
    required ChatGptService chatGptService,
    required WorkspaceController workspaceController,
    required SettingsController settingsController,
    required CopilotController copilotController,
  }) : _microphoneRecordingService = microphoneRecordingService,
       _chatGptService = chatGptService,
       _workspaceController = workspaceController,
       _settingsController = settingsController,
       _copilotController = copilotController,
       _conversationService = AgentConversationService(
         chatGptService: chatGptService,
       ),
       _ttsService = TtsService();

  final MicrophoneRecordingService _microphoneRecordingService;
  final ChatGptService _chatGptService;
  WorkspaceController _workspaceController;
  SettingsController _settingsController;
  CopilotController _copilotController;
  final AgentConversationService _conversationService;
  final TtsService _ttsService;

  bool _disposed = false;
  bool _panelOpen = false;
  AgentPanelPhase _phase = AgentPanelPhase.idle;
  String? _errorMessage;
  String? _speakingMessageId;

  // --- Public getters ---

  bool get panelOpen => _panelOpen;
  AgentPanelPhase get phase => _phase;
  bool get isRecording => _phase == AgentPanelPhase.recording;
  bool get isProcessing => _phase == AgentPanelPhase.processing;
  bool get isSpeaking => _ttsService.isPlaying;
  String? get errorMessage => _errorMessage;
  String? get speakingMessageId => _speakingMessageId;
  List<AgentMessage> get messages => _conversationService.messages;

  void updateDependencies({
    required WorkspaceController workspaceController,
    required SettingsController settingsController,
    required CopilotController copilotController,
  }) {
    _workspaceController = workspaceController;
    _settingsController = settingsController;
    _copilotController = copilotController;
  }

  // --- Panel visibility ---

  void togglePanel() {
    _panelOpen = !_panelOpen;
    _notify();
  }

  void openPanel() {
    if (!_panelOpen) {
      _panelOpen = true;
      _notify();
    }
  }

  void closePanel() {
    if (_panelOpen) {
      _panelOpen = false;
      if (_phase == AgentPanelPhase.recording) {
        unawaited(_cancelRecording());
      }
      _notify();
    }
  }

  // --- Voice input ---

  Future<void> startRecording() async {
    _errorMessage = null;

    final apiKey = _settingsController.openAiApiKey.trim();
    if (apiKey.isEmpty) {
      _errorMessage = 'Add your OpenAI API key in Settings before recording.';
      _notify();
      return;
    }

    try {
      final accessGranted =
          await _microphoneRecordingService.requestMicrophoneAccess();
      if (!accessGranted) {
        _errorMessage =
            'Microphone access was denied. Enable it in macOS System Settings.';
        _notify();
        return;
      }

      await _microphoneRecordingService.startRecording();
      _phase = AgentPanelPhase.recording;
      _notify();
    } catch (error) {
      _log('Failed to start recording', error: error);
      _errorMessage = error.toString();
      _notify();
    }
  }

  Future<void> stopRecordingAndSubmit() async {
    if (_phase != AgentPanelPhase.recording) return;

    String? audioPath;
    try {
      _phase = AgentPanelPhase.processing;
      _notify();

      audioPath = await _microphoneRecordingService.stopRecordingAndTrim();

      final apiKey = _settingsController.openAiApiKey.trim();
      final transcript = await _chatGptService.transcribeAudio(
        apiKey: apiKey,
        audioPath: audioPath,
        model: _settingsController.settings.openAiTranscriptionModel,
      );

      if (transcript.trim().isEmpty) {
        _phase = AgentPanelPhase.idle;
        _notify();
        return;
      }

      await _processTranscript(transcript);
    } catch (error) {
      _log('Voice submission failed', error: error);
      _errorMessage = error.toString();
      _phase = AgentPanelPhase.idle;
      _notify();
    } finally {
      if (audioPath != null) {
        _deleteFileIfPresent(audioPath);
      }
    }
  }

  Future<void> handleVoiceShortcut() async {
    if (!_panelOpen) {
      openPanel();
      await startRecording();
      return;
    }

    switch (_phase) {
      case AgentPanelPhase.idle:
        await startRecording();
      case AgentPanelPhase.recording:
        await stopRecordingAndSubmit();
      case AgentPanelPhase.processing:
        break; // no-op while processing
    }
  }

  // --- Text input ---

  Future<void> submitText(String text) async {
    if (text.trim().isEmpty) return;
    if (_phase != AgentPanelPhase.idle) return;

    _errorMessage = null;
    final apiKey = _settingsController.openAiApiKey.trim();
    if (apiKey.isEmpty) {
      _errorMessage = 'Add your OpenAI API key in Settings.';
      _notify();
      return;
    }

    _phase = AgentPanelPhase.processing;
    _notify();

    try {
      await _processText(text);
    } catch (error) {
      _log('Text submission failed', error: error);
      _errorMessage = error.toString();
    } finally {
      _phase = AgentPanelPhase.idle;
      _notify();
    }
  }

  // --- TTS ---

  Future<void> speakMessage(String messageId) async {
    final apiKey = _settingsController.openAiApiKey.trim();
    if (apiKey.isEmpty) return;

    final message = _conversationService.messages
        .cast<AgentMessage?>()
        .firstWhere((m) => m?.id == messageId, orElse: () => null);
    if (message == null || message.content.trim().isEmpty) return;

    _speakingMessageId = messageId;
    _notify();

    try {
      await _ttsService.speak(
        apiKey: apiKey,
        text: message.content,
        model: _settingsController.settings.openAiTtsModel,
        voice: _settingsController.settings.openAiTtsVoice.apiName,
      );
    } catch (error) {
      _log('TTS failed', error: error);
    } finally {
      _speakingMessageId = null;
      if (!_disposed) _notify();
    }
  }

  Future<void> stopSpeaking() async {
    await _ttsService.stopPlayback();
    _speakingMessageId = null;
    _notify();
  }

  // --- History ---

  void clearHistory() {
    _conversationService.clearHistory();
    _errorMessage = null;
    _notify();
  }

  // --- Private helpers ---

  Future<void> _processTranscript(String transcript) async {
    try {
      final toolRegistry = _buildToolRegistry();
      await _conversationService.sendVoiceTranscript(
        transcript: transcript,
        apiKey: _settingsController.openAiApiKey.trim(),
        model: _settingsController.settings.openAiResponseModel,
        toolRegistry: toolRegistry,
      );
    } finally {
      _phase = AgentPanelPhase.idle;
      _notify();
    }
  }

  Future<void> _processText(String text) async {
    final toolRegistry = _buildToolRegistry();
    await _conversationService.sendMessage(
      text: text,
      apiKey: _settingsController.openAiApiKey.trim(),
      model: _settingsController.settings.openAiResponseModel,
      toolRegistry: toolRegistry,
    );
  }

  AgentToolRegistry _buildToolRegistry() {
    return AgentToolRegistry(
      repoToolRegistry: RepoActionToolRegistry(
        repoProvider: _workspaceController,
      ),
      copilotToolRegistry: CopilotToolRegistry(
        copilotController: _copilotController,
      ),
    );
  }

  Future<void> _cancelRecording() async {
    await _microphoneRecordingService.cancelRecording();
    _phase = AgentPanelPhase.idle;
  }

  void _deleteFileIfPresent(String path) {
    final file = File(path);
    if (file.existsSync()) {
      file.deleteSync();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _log(String message, {Object? error, StackTrace? stackTrace}) {
    logVoice('AgentPanel', message, error: error, stackTrace: stackTrace);
  }

  @override
  void dispose() {
    _disposed = true;
    _ttsService.dispose();
    super.dispose();
  }
}
