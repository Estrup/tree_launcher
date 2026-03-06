import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../models/chatgpt_processing_result.dart';
import '../providers/repo_provider.dart';
import '../providers/settings_provider.dart';
import 'chatgpt_service.dart';
import 'microphone_recording_service.dart';
import 'repo_action_tool_registry.dart';
import 'voice_logging.dart';

enum ShortcutOverlayPhase {
  closed,
  recording,
  trimming,
  transcribing,
  routing,
  success,
  error,
}

class ShortcutOverlayController extends ChangeNotifier {
  ShortcutOverlayController({
    required MicrophoneRecordingService microphoneRecordingService,
    required ChatGptService chatGptService,
    required RepoProvider repoProvider,
    required SettingsProvider settingsProvider,
  }) : _microphoneRecordingService = microphoneRecordingService,
       _chatGptService = chatGptService,
       _repoProvider = repoProvider,
       _settingsProvider = settingsProvider;

  final MicrophoneRecordingService _microphoneRecordingService;
  final ChatGptService _chatGptService;
  final RepoProvider _repoProvider;
  final SettingsProvider _settingsProvider;
  bool _disposed = false;
  ShortcutOverlayPhase _phase = ShortcutOverlayPhase.closed;
  String _detailLabel = '';
  String _transcript = '';
  Timer? _closeTimer;

  ShortcutOverlayPhase get phase => _phase;
  bool get isVisible => _phase != ShortcutOverlayPhase.closed;
  bool get isRecording => _phase == ShortcutOverlayPhase.recording;
  bool get isBusy =>
      _phase == ShortcutOverlayPhase.trimming ||
      _phase == ShortcutOverlayPhase.transcribing ||
      _phase == ShortcutOverlayPhase.routing;
  bool get canDismiss =>
      _phase == ShortcutOverlayPhase.recording ||
      _phase == ShortcutOverlayPhase.error ||
      _phase == ShortcutOverlayPhase.success;
  bool get canPrimaryAction =>
      _phase == ShortcutOverlayPhase.recording ||
      _phase == ShortcutOverlayPhase.error ||
      _phase == ShortcutOverlayPhase.success;
  String get detailLabel => _detailLabel;
  String get transcript => _transcript;
  IconData get primaryIcon => switch (_phase) {
    ShortcutOverlayPhase.recording => Icons.stop_rounded,
    ShortcutOverlayPhase.error => Icons.close_rounded,
    ShortcutOverlayPhase.success => Icons.check_rounded,
    _ => Icons.arrow_upward_rounded,
  };
  String get primaryTooltip => switch (_phase) {
    ShortcutOverlayPhase.recording => 'Stop recording',
    ShortcutOverlayPhase.error => 'Close',
    ShortcutOverlayPhase.success => 'Done',
    _ => 'Busy',
  };
  String get statusLabel => switch (_phase) {
    ShortcutOverlayPhase.closed => '',
    ShortcutOverlayPhase.recording => 'Recording',
    ShortcutOverlayPhase.trimming => 'Trimming audio',
    ShortcutOverlayPhase.transcribing => 'Transcribing',
    ShortcutOverlayPhase.routing => 'Transcript',
    ShortcutOverlayPhase.success => 'Response',
    ShortcutOverlayPhase.error => 'Voice command failed',
  };

  Future<void> handleShortcut() async {
    _log('Shortcut received while phase=${_phase.name}');
    switch (_phase) {
      case ShortcutOverlayPhase.closed:
      case ShortcutOverlayPhase.error:
      case ShortcutOverlayPhase.success:
        await startRecording();
        return;
      case ShortcutOverlayPhase.recording:
        await submit();
        return;
      case ShortcutOverlayPhase.trimming:
      case ShortcutOverlayPhase.transcribing:
      case ShortcutOverlayPhase.routing:
        return;
    }
  }

  Future<void> handlePrimaryAction() async {
    _log('Primary action pressed while phase=${_phase.name}');
    switch (_phase) {
      case ShortcutOverlayPhase.recording:
        await submit();
        return;
      case ShortcutOverlayPhase.error:
      case ShortcutOverlayPhase.success:
        await dismiss();
        return;
      case ShortcutOverlayPhase.closed:
      case ShortcutOverlayPhase.trimming:
      case ShortcutOverlayPhase.transcribing:
      case ShortcutOverlayPhase.routing:
        return;
    }
  }

  Future<void> startRecording() async {
    _cancelCloseTimer();
    _transcript = '';
    _log('Starting recording flow');

    final apiKey = _settingsProvider.openAiApiKey.trim();
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
        ShortcutOverlayPhase.recording,
        detail:
            'Speak now. Press Control+M again or use the right button to stop.',
      );
    } catch (error, stackTrace) {
      _log('Failed to start recording.', error: error, stackTrace: stackTrace);
      _setError(error.toString());
    }
  }

  Future<void> submit() async {
    if (_phase != ShortcutOverlayPhase.recording) {
      return;
    }

    String? audioPath;
    try {
      _log('Submitting voice command.');
      final apiKey = _settingsProvider.openAiApiKey.trim();
      final toolRegistry = RepoActionToolRegistry(repoProvider: _repoProvider);

      _updateState(
        ShortcutOverlayPhase.trimming,
        detail: 'Removing leading and trailing silence from the recording.',
      );
      _log('Entering trimming phase.');
      audioPath = await _microphoneRecordingService.stopRecordingAndTrim();
      _log('Audio ready for transcription path=$audioPath');

      _updateState(
        ShortcutOverlayPhase.transcribing,
        detail:
            'Transcribing with ${_settingsProvider.settings.openAiTranscriptionModel}.',
      );
      _log(
        'Transcribing with model=${_settingsProvider.settings.openAiTranscriptionModel}.',
      );

      final transcript = await _chatGptService.transcribeAudio(
        apiKey: apiKey,
        audioPath: audioPath,
        model: _settingsProvider.settings.openAiTranscriptionModel,
      );
      _transcript = transcript;
      _log('Received transcript length=${transcript.length}.');

      _updateState(ShortcutOverlayPhase.routing, detail: transcript);
      _log(
        'Routing transcript with model=${_settingsProvider.settings.openAiResponseModel}.',
      );

      final result = await _chatGptService.processTranscriptCommand(
        apiKey: apiKey,
        transcript: transcript,
        responseModel: _settingsProvider.settings.openAiResponseModel,
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

    if (_phase == ShortcutOverlayPhase.recording) {
      await _microphoneRecordingService.cancelRecording();
    }

    _detailLabel = '';
    _transcript = '';
    _setPhase(ShortcutOverlayPhase.closed);
  }

  void _applySuccess(ChatGptProcessingResult result) {
    _transcript = result.transcript;
    _log(
      'Voice command completed responseLength=${result.responseText.length} '
      'toolCalls=${result.toolSummaries.length}',
    );
    _updateState(ShortcutOverlayPhase.success, detail: result.summary);
  }

  void _setError(String message) {
    _log('Overlay entering error state: ${_stripExceptionPrefix(message)}');
    _updateState(
      ShortcutOverlayPhase.error,
      detail: _stripExceptionPrefix(message),
    );
  }

  Future<void> _deleteFileIfPresent(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  void _updateState(ShortcutOverlayPhase phase, {required String detail}) {
    _detailLabel = detail;
    _setPhase(phase);
  }

  void _setPhase(ShortcutOverlayPhase phase) {
    if (_disposed || _phase == phase) {
      return;
    }

    _phase = phase;
    notifyListeners();
  }

  String _stripExceptionPrefix(String message) {
    const prefix = 'Exception: ';
    return message.startsWith(prefix)
        ? message.substring(prefix.length)
        : message;
  }

  void _cancelCloseTimer() {
    _closeTimer?.cancel();
    _closeTimer = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelCloseTimer();
    unawaited(_microphoneRecordingService.dispose());
    super.dispose();
  }

  void _log(String message, {Object? error, StackTrace? stackTrace}) {
    logVoice('Overlay', message, error: error, stackTrace: stackTrace);
  }
}
