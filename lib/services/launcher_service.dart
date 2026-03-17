import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/app_settings.dart';

class LauncherService {
  Future<void> openTerminal(String directory, AppSettings settings) async {
    if (Platform.isWindows) {
      switch (settings.terminalApp) {
        case TerminalApp.terminal:
        case TerminalApp.ghostty:
          // Ghostty not supported on Windows; fall back to PowerShell
          await Process.start('powershell.exe', ['-NoExit', '-Command', 'Set-Location "$directory"']);
          break;
        case TerminalApp.custom:
          if (settings.customTerminalCommand != null) {
            await _openCustomTerminal(directory, settings.customTerminalCommand!);
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
    if (Platform.isWindows) {
      switch (settings.terminalApp) {
        case TerminalApp.terminal:
        case TerminalApp.ghostty:
          await Process.start(
            'powershell.exe',
            ['-NoExit', '-Command', 'Set-Location "$directory"; gh copilot'],
          );
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
    if (Platform.isWindows) {
      final result = await Process.run('where.exe', ['code']);
      if (result.exitCode == 0) {
        await Process.run('code', [directory]);
      } else {
        // Try launching via cmd start
        await Process.run('cmd', ['/c', 'start', '', 'code', directory]);
      }
      return;
    }

    // macOS: try `code` CLI first, fall back to `open -a`
    final result = await Process.run('which', ['code']);
    if (result.exitCode == 0) {
      await Process.run('code', [directory]);
    } else {
      await Process.run('open', ['-a', 'Visual Studio Code', directory]);
    }
  }

  Future<void> runCustomCommand(
    String directory,
    String command,
    AppSettings settings,
  ) async {
    if (Platform.isWindows) {
      await Process.start(
        'powershell.exe',
        ['-NoExit', '-Command', 'Set-Location "$directory"; $command'],
      );
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
    if (Platform.isWindows) {
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
      if (Platform.isWindows) {
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

    final shell = Platform.isWindows ? 'powershell.exe' : '/bin/bash';
    final args = Platform.isWindows ? ['-Command', shellCommand] : ['-c', shellCommand];
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

  String _escapeForAppleScript(String s) => s.replaceAll("'", "'\\''");
  String _escapeForAppleScriptText(String s) =>
      s.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
}
