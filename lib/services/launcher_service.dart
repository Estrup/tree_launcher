import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/app_settings.dart';

class LauncherService {
  Future<void> openTerminal(String directory, AppSettings settings) async {
    switch (settings.terminalApp) {
      case TerminalApp.terminal:
        await Process.run('open', ['-a', 'Terminal', directory]);
        break;
      case TerminalApp.iterm2:
        await _openITerm2(directory);
        break;
      case TerminalApp.custom:
        if (settings.customTerminalCommand != null) {
          await _openCustomTerminal(directory, settings.customTerminalCommand!);
        }
        break;
    }
  }

  Future<void> openCopilotCli(String directory, AppSettings settings) async {
    switch (settings.terminalApp) {
      case TerminalApp.terminal:
        await _runAppleScript('''
          tell application "Terminal"
            activate
            do script "cd '${_escapeForAppleScript(directory)}' && gh copilot"
          end tell
        ''');
        break;
      case TerminalApp.iterm2:
        await _runAppleScript('''
          tell application "iTerm"
            activate
            set newWindow to (create window with default profile)
            tell current session of newWindow
              write text "cd '${_escapeForAppleScript(directory)}' && gh copilot"
            end tell
          end tell
        ''');
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
    // Try `code` CLI first, fall back to `open -a`
    final result = await Process.run('which', ['code']);
    if (result.exitCode == 0) {
      await Process.run('code', [directory]);
    } else {
      await Process.run(
          'open', ['-a', 'Visual Studio Code', directory]);
    }
  }

  Future<void> runCustomCommand(
      String directory, String command, AppSettings settings) async {
        await _runAppleScript('''
          tell application "Terminal"
            activate
            do script "cd '${_escapeForAppleScript(directory)}' && ${_escapeForAppleScript(command)}"
          end tell
        ''');
  }

  Future<void> _openITerm2(String directory) async {
    await _runAppleScript('''
      tell application "iTerm"
        activate
        set newWindow to (create window with default profile)
        tell current session of newWindow
          write text "cd '${_escapeForAppleScript(directory)}'"
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
      // Substitute {path} with the directory
      shellCommand = terminalCommand.replaceAll('{path}', directory);
    } else {
      // Legacy: assume terminal emulator with -e flag
      final fullCommand = command != null
          ? 'cd \'$directory\' && $command'
          : 'cd \'$directory\'';
      shellCommand = '$terminalCommand -e "$fullCommand"';
    }
    final args = ['-c', shellCommand];
    debugPrint('Running custom terminal: /bin/bash ${args.join(' ')}');
    try {
      final result = await Process.run('/bin/bash', args);
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
}
