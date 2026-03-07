import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';
import 'package:tree_launcher/features/voice_commands/data/chatgpt_service.dart';
import 'package:tree_launcher/features/voice_commands/data/microphone_recording_service.dart';
import 'package:tree_launcher/features/voice_commands/data/repo_action_tool_registry.dart';
import 'package:tree_launcher/features/voice_commands/data/voice_logging.dart';
import 'package:tree_launcher/features/voice_commands/domain/chatgpt_processing_result.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';

enum VoiceCommandPhase {
  closed,
  recording,
  trimming,
  transcribing,
  routing,
  success,
  error,
}

class VoiceCommandController extends ChangeNotifier {
  VoiceCommandController({
    required MicrophoneRecordingService microphoneRecordingService,
    required ChatGptService chatGptService,
    WorkspaceController? workspaceController,
    WorkspaceController? repoProvider,
    SettingsController? settingsController,
    SettingsController? settingsProvider,
  }) : _microphoneRecordingService = microphoneRecordingService,
       _chatGptService = chatGptService,
       _workspaceController = workspaceController ?? repoProvider!,
       _settingsController = settingsController ?? settingsProvider!;

  final MicrophoneRecordingService _microphoneRecordingService;
  final ChatGptService _chatGptService;
  WorkspaceController _workspaceController;
  SettingsController _settingsController;
  bool _disposed = false;
  VoiceCommandPhase _phase = VoiceCommandPhase.closed;
  String _detailLabel = '';
  String _transcript = '';
  Timer? _closeTimer;

  VoiceCommandPhase get phase => _phase;
  bool get isVisible => _phase != VoiceCommandPhase.closed;
  bool get isRecording => _phase == VoiceCommandPhase.recording;
  bool get isBusy =>
      _phase == VoiceCommandPhase.trimming ||
      _phase == VoiceCommandPhase.transcribing ||
      _phase == VoiceCommandPhase.routing;
  bool get canDismiss =>
      _phase == VoiceCommandPhase.recording ||
      _phase == VoiceCommandPhase.error ||
      _phase == VoiceCommandPhase.success;
  bool get canPrimaryAction =>
      _phase == VoiceCommandPhase.recording ||
      _phase == VoiceCommandPhase.error ||
      _phase == VoiceCommandPhase.success;
  String get detailLabel => _detailLabel;
  String get transcript => _transcript;
  IconData get primaryIcon => switch (_phase) {
    VoiceCommandPhase.recording => Icons.stop_rounded,
    VoiceCommandPhase.error => Icons.close_rounded,
    VoiceCommandPhase.success => Icons.check_rounded,
    _ => Icons.arrow_upward_rounded,
  };
  String get primaryTooltip => switch (_phase) {
    VoiceCommandPhase.recording => 'Stop recording',
    VoiceCommandPhase.error => 'Close',
    VoiceCommandPhase.success => 'Done',
    _ => 'Busy',
  };
  String get statusLabel => switch (_phase) {
    VoiceCommandPhase.closed => '',
    VoiceCommandPhase.recording => 'Recording',
    VoiceCommandPhase.trimming => 'Trimming audio',
    VoiceCommandPhase.transcribing => 'Transcribing',
    VoiceCommandPhase.routing => 'Transcript',
    VoiceCommandPhase.success => 'Response',
    VoiceCommandPhase.error => 'Voice command failed',
  };

  void updateDependencies({
    required WorkspaceController workspaceController,
    required SettingsController settingsController,
  }) {
    _workspaceController = workspaceController;
    _settingsController = settingsController;
  }

  Future<void> handleShortcut() async {
    _log('Shortcut received while phase=${_phase.name}');
    switch (_phase) {
      case VoiceCommandPhase.closed:
      case VoiceCommandPhase.error:
      case VoiceCommandPhase.success:
        await startRecording();
        return;
      case VoiceCommandPhase.recording:
        await submit();
        return;
      case VoiceCommandPhase.trimming:
      case VoiceCommandPhase.transcribing:
      case VoiceCommandPhase.routing:
        return;
    }
  }

  Future<void> handlePrimaryAction() async {
    _log('Primary action pressed while phase=${_phase.name}');
    switch (_phase) {
      case VoiceCommandPhase.recording:
        await submit();
        return;
      case VoiceCommandPhase.error:
      case VoiceCommandPhase.success:
        await dismiss();
        return;
      case VoiceCommandPhase.closed:
      case VoiceCommandPhase.trimming:
      case VoiceCommandPhase.transcribing:
      case VoiceCommandPhase.routing:
        return;
    }
  }

  Future<void> startRecording() async {
    _cancelCloseTimer();
    _transcript = '';
    _log('Starting recording flow');

    final apiKey = _settingsController.openAiApiKey.trim();
    if (apiKey.isEmpty) {
      _log('Recording blocked because no OpenAI API key is configured.');
      _setError('Add your OpenAI API key in Settings before recording audio.');
      return;
    }

    try {
      final accessGranted = await _microphoneRecordingService
          .requestMicrophoneAccess();
      if (!accessGranted) {
        _log('Microphone access denied.');
        _setError(
          'Microphone access was denied. Enable it in macOS System Settings.',
        );
        return;
      }

      await _microphoneRecordingService.startRecording();
      _log('Recording started successfully.');
      _updateState(
        VoiceCommandPhase.recording,
        detail:
            'Speak now. Press Control+M again or use the right button to stop.',
      );
    } catch (error, stackTrace) {
      _log('Failed to start recording.', error: error, stackTrace: stackTrace);
      _setError(error.toString());
    }
  }

  Future<void> submit() async {
    if (_phase != VoiceCommandPhase.recording) return;

    String? audioPath;
    try {
      _log('Submitting voice command.');
      final apiKey = _settingsController.openAiApiKey.trim();
      final toolRegistry = RepoActionToolRegistry(
        repoProvider: _workspaceController,
      );

      _updateState(
        VoiceCommandPhase.trimming,
        detail: 'Removing leading and trailing silence from the recording.',
      );
      _log('Entering trimming phase.');
      audioPath = await _microphoneRecordingService.stopRecordingAndTrim();
      _log('Audio ready for transcription path=$audioPath');

      _updateState(
        VoiceCommandPhase.transcribing,
        detail:
            'Transcribing with ${_settingsController.settings.openAiTranscriptionModel}.',
      );
      _log(
        'Transcribing with model=${_settingsController.settings.openAiTranscriptionModel}.',
      );

      final transcript = await _chatGptService.transcribeAudio(
        apiKey: apiKey,
        audioPath: audioPath,
        model: _settingsController.settings.openAiTranscriptionModel,
      );
      _transcript = transcript;
      _log('Received transcript length=${transcript.length}.');

      _updateState(VoiceCommandPhase.routing, detail: transcript);
      _log(
        'Routing transcript with model=${_settingsController.settings.openAiResponseModel}.',
      );

      final result = await _chatGptService.processTranscriptCommand(
        apiKey: apiKey,
        transcript: transcript,
        responseModel: _settingsController.settings.openAiResponseModel,
        toolRegistry: toolRegistry,
      );

      _applySuccess(result);
    } catch (error, stackTrace) {
      _log(
        'Voice command submission failed.',
        error: error,
        stackTrace: stackTrace,
      );
      _setError(error.toString());
    } finally {
      if (audioPath != null) {
        _log('Cleaning up temporary audio file path=$audioPath');
        await _deleteFileIfPresent(audioPath);
      }
    }
  }

  Future<void> dismiss() async {
    _cancelCloseTimer();
    _log('Dismissing overlay from phase=${_phase.name}');

    if (_phase == VoiceCommandPhase.recording) {
      await _microphoneRecordingService.cancelRecording();
    }

    _detailLabel = '';
    _transcript = '';
    _setPhase(VoiceCommandPhase.closed);
  }

  void _applySuccess(ChatGptProcessingResult result) {
    _transcript = result.transcript;
    _log(
      'Voice command completed responseLength=${result.responseText.length} '
      'toolCalls=${result.toolSummaries.length}',
    );
    _updateState(VoiceCommandPhase.success, detail: result.summary);
  }

  void _setError(String message) {
    _log('Overlay entering error state: $message');
    _updateState(VoiceCommandPhase.error, detail: message);
  }

  void _updateState(VoiceCommandPhase phase, {required String detail}) {
    _detailLabel = detail;
    _setPhase(phase);
    if (phase == VoiceCommandPhase.success ||
        phase == VoiceCommandPhase.error) {
      _scheduleAutoClose();
    }
  }

  void _setPhase(VoiceCommandPhase phase) {
    _phase = phase;
    if (!_disposed) {
      notifyListeners();
    }
  }

  void _scheduleAutoClose() {
    _cancelCloseTimer();
    _closeTimer = Timer(const Duration(seconds: 5), () {
      unawaited(dismiss());
    });
  }

  void _cancelCloseTimer() {
    _closeTimer?.cancel();
    _closeTimer = null;
  }

  Future<void> _deleteFileIfPresent(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  void _log(String message, {Object? error, StackTrace? stackTrace}) {
    logVoice('Overlay', message, error: error, stackTrace: stackTrace);
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelCloseTimer();
    super.dispose();
  }
}
