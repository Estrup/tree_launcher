import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/app_settings.dart';

typedef ProcessStarter = Future<void> Function(
  String executable,
  List<String> arguments, {
  bool runInShell,
  ProcessStartMode mode,
});

typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments, {
  bool runInShell,
});

class LauncherService {
  LauncherService({
    ProcessStarter? startProcess,
    ProcessRunner? runProcess,
    Map<String, String>? environment,
    bool Function(String path)? fileExists,
    bool? isWindowsOverride,
  }) : _startProcess = startProcess ?? _systemStartProcess,
       _runProcess = runProcess ?? _systemRunProcess,
       _environment = environment ?? Platform.environment,
       _fileExists = fileExists ?? _systemFileExists,
       _isWindowsOverride = isWindowsOverride;

  final ProcessStarter _startProcess;
  final ProcessRunner _runProcess;
  final Map<String, String> _environment;
  final bool Function(String path) _fileExists;
  final bool? _isWindowsOverride;

  bool get _isWindows => _isWindowsOverride ?? Platform.isWindows;

  Future<void> openTerminal(String directory, AppSettings settings) async {
    if (_isWindows) {
      switch (settings.terminalApp) {
        case TerminalApp.terminal:
        case TerminalApp.ghostty:
          // Ghostty not supported on Windows; fall back to PowerShell
          await Process.start('powershell.exe', [
            '-NoExit',
            '-Command',
            'Set-Location "$directory"',
          ]);
          break;
        case TerminalApp.custom:
          if (settings.customTerminalCommand != null) {
            await _openCustomTerminal(
              directory,
              settings.customTerminalCommand!,
            );
          }
          break;
      }
      return;
    }

    // macOS
    switch (settings.terminalApp) {
      case TerminalApp.terminal:
        await Process.run('open', ['-a', 'Terminal', directory]);
        break;
      case TerminalApp.ghostty:
        await openGhostty(directory);
        break;
      case TerminalApp.custom:
        if (settings.customTerminalCommand != null) {
          await _openCustomTerminal(directory, settings.customTerminalCommand!);
        }
        break;
    }
  }

  Future<void> openCopilotCli(String directory, AppSettings settings) async {
    if (_isWindows) {
      switch (settings.terminalApp) {
        case TerminalApp.terminal:
        case TerminalApp.ghostty:
          await Process.start('powershell.exe', [
            '-NoExit',
            '-Command',
            'Set-Location "$directory"; gh copilot',
          ]);
          break;
        case TerminalApp.custom:
          if (settings.customTerminalCommand != null) {
            await _openCustomTerminal(
              directory,
              settings.customTerminalCommand!,
              command: 'gh copilot',
            );
          }
          break;
      }
      return;
    }

    // macOS
    switch (settings.terminalApp) {
      case TerminalApp.terminal:
        await _runAppleScript('''
          tell application "Terminal"
            activate
            do script "cd '${_escapeForAppleScript(directory)}' && gh copilot"
          end tell
        ''');
        break;
      case TerminalApp.ghostty:
        await openGhosttyWithCommand(directory, 'gh copilot');
        break;
      case TerminalApp.custom:
        if (settings.customTerminalCommand != null) {
          await _openCustomTerminal(
            directory,
            settings.customTerminalCommand!,
            command: 'gh copilot',
          );
        }
        break;
    }
  }

  Future<void> openVSCode(String directory) async {
    if (_isWindows) {
      await _openWindowsVSCode(directory);
      return;
    }

    // macOS: try `code` CLI first, fall back to `open -a`
    final result = await _runProcess('which', ['code']);
    if (result.exitCode == 0) {
      await _startDetached('code', [directory]);
    } else {
      await _startDetached('open', ['-a', 'Visual Studio Code', directory]);
    }
  }

  Future<void> runCustomCommand(
    String directory,
    String command,
    AppSettings settings,
  ) async {
    if (_isWindows) {
      await Process.start('powershell.exe', [
        '-NoExit',
        '-Command',
        'Set-Location "$directory"; $command',
      ]);
      return;
    }

    // macOS
    await _runAppleScript('''
          tell application "Terminal"
            activate
            do script "cd '${_escapeForAppleScript(directory)}' && ${_escapeForAppleScript(command)}"
          end tell
        ''');
  }

  Future<void> openGhostty(String directory) async {
    await openGhosttyWithCommand(directory, null);
  }

  Future<void> openGhosttyWithCommand(String directory, String? command) async {
    if (_isWindows) {
      debugPrint('Ghostty automation is not supported on Windows');
      return;
    }
    final escapedDirectory = _escapeForAppleScript(directory);
    final commandToRun = command != null && command.isNotEmpty
        ? "cd '$escapedDirectory' && $command"
        : "cd '$escapedDirectory'";
    await _openGhosttyCommand(commandToRun);
  }

  Future<void> _openGhosttyCommand(String commandToRun) async {
    final escapedCommand = _escapeForAppleScriptText(commandToRun);
    await _runAppleScript('''
      set commandToRun to "$escapedCommand"
      tell application "System Events"
        set ghosttyRunning to (exists (processes where name is "Ghostty"))
      end tell
      if ghosttyRunning then
        tell application "Ghostty" to activate
        delay 0.2
        tell application "System Events"
          tell process "Ghostty"
            keystroke "t" using command down
          end tell
        end tell
        delay 1
      else
        tell application "Ghostty" to activate
        delay 0.5
      end if
      tell application "System Events"
        tell process "Ghostty"
          keystroke commandToRun
          key code 36
        end tell
      end tell
    ''');
  }

  Future<void> _openCustomTerminal(
    String directory,
    String terminalCommand, {
    String? command,
  }) async {
    final String shellCommand;
    if (terminalCommand.contains('{path}')) {
      shellCommand = terminalCommand.replaceAll('{path}', directory);
    } else {
      if (_isWindows) {
        final fullCommand = command != null
            ? 'Set-Location "$directory"; $command'
            : 'Set-Location "$directory"';
        shellCommand = '$terminalCommand -e "$fullCommand"';
      } else {
        final fullCommand = command != null
            ? 'cd \'$directory\' && $command'
            : 'cd \'$directory\'';
        shellCommand = '$terminalCommand -e "$fullCommand"';
      }
    }

    final shell = _isWindows ? 'powershell.exe' : '/bin/bash';
    final args = _isWindows ? ['-Command', shellCommand] : ['-c', shellCommand];
    debugPrint('Running custom terminal: $shell ${args.join(' ')}');
    try {
      final result = await Process.run(shell, args);
      if (result.exitCode != 0) {
        debugPrint('Custom terminal exited with code ${result.exitCode}');
        if ((result.stdout as String).isNotEmpty) {
          debugPrint('stdout: ${result.stdout}');
        }
        if ((result.stderr as String).isNotEmpty) {
          debugPrint('stderr: ${result.stderr}');
        }
      }
    } catch (e) {
      debugPrint('Custom terminal error: $e');
    }
  }

  Future<void> _runAppleScript(String script) async {
    await Process.run('osascript', ['-e', script]);
  }

  Future<void> _openWindowsVSCode(String directory) async {
    try {
      await _startDetached('code', [directory], runInShell: true);
      return;
    } on ProcessException catch (error) {
      debugPrint('VS Code CLI launch failed: $error');
    }

    for (final executable in windowsVSCodeExecutableCandidates(_environment)) {
      if (!_fileExists(executable)) {
        continue;
      }
      try {
        await _startDetached(executable, [directory]);
        return;
      } on ProcessException catch (error) {
        debugPrint('VS Code launch failed for $executable: $error');
      }
    }

    throw StateError(
      'Could not find a Visual Studio Code installation. Install VS Code or add the `code` command to PATH.',
    );
  }

  Future<void> _startDetached(
    String executable,
    List<String> arguments, {
    bool runInShell = false,
  }) {
    return _startProcess(
      executable,
      arguments,
      runInShell: runInShell,
      mode: ProcessStartMode.detached,
    );
  }

  static Future<void> _systemStartProcess(
    String executable,
    List<String> arguments, {
    bool runInShell = false,
    ProcessStartMode mode = ProcessStartMode.normal,
  }) async {
    await Process.start(
      executable,
      arguments,
      runInShell: runInShell,
      mode: mode,
    );
  }

  static Future<ProcessResult> _systemRunProcess(
    String executable,
    List<String> arguments, {
    bool runInShell = false,
  }) {
    return Process.run(executable, arguments, runInShell: runInShell);
  }

  static bool _systemFileExists(String path) => File(path).existsSync();

  @visibleForTesting
  static List<String> windowsVSCodeExecutableCandidates(
    Map<String, String> environment,
  ) {
    final candidates = <String>[
      if ((environment['LOCALAPPDATA'] ?? '').isNotEmpty)
        '${environment['LOCALAPPDATA']}\\Programs\\Microsoft VS Code\\Code.exe',
      if ((environment['ProgramFiles'] ?? '').isNotEmpty)
        '${environment['ProgramFiles']}\\Microsoft VS Code\\Code.exe',
      if ((environment['ProgramFiles(x86)'] ?? '').isNotEmpty)
        '${environment['ProgramFiles(x86)']}\\Microsoft VS Code\\Code.exe',
    ];
    return candidates.toSet().toList(growable: false);
  }

  String _escapeForAppleScript(String s) => s.replaceAll("'", "'\\''");
  String _escapeForAppleScriptText(String s) =>
      s.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
}
