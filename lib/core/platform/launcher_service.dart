import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:tree_launcher/core/design_system/app_snackbar.dart';
import 'package:tree_launcher/features/settings/domain/app_settings.dart';

/// Opens worktrees in other apps: a terminal, VS Code, Claude Desktop, or a
/// custom command. A launch that fails shows a notice saying so.
class LauncherService {
  Future<void> openTerminal(String directory, AppSettings settings) async {
    switch (settings.terminalApp) {
      case TerminalApp.terminal:
        await _run('open', ['-a', 'Terminal', directory], what: 'Terminal');
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

  Future<void> openVSCode(String directory) async {
    // Try `code` CLI first, fall back to `open -a`
    final result = await Process.run('which', ['code']);
    if (result.exitCode == 0) {
      await _run('code', [directory], what: 'VS Code');
    } else {
      await _run(
        'open',
        ['-a', 'Visual Studio Code', directory],
        what: 'VS Code',
      );
    }
  }

  /// Opens [file] in VS Code, in the window of the folder [directory] (a new
  /// one when that folder isn't open).
  Future<void> openFileInVSCode(String directory, String file) async {
    final result = await Process.run('which', ['code']);
    if (result.exitCode == 0) {
      await _run('code', [directory, file], what: 'VS Code');
    } else {
      await _run('open', ['-a', 'Visual Studio Code', file], what: 'VS Code');
    }
  }

  Future<void> openClaude(String directory, {String? prompt}) async {
    var url = 'claude://code/new?folder=${Uri.encodeComponent(directory)}';
    if (prompt != null && prompt.isNotEmpty) {
      url += '&q=${Uri.encodeComponent(prompt)}';
    }
    await _run('open', [url], what: 'Claude Desktop');
  }

  Future<void> runCustomCommand(
    String directory,
    String command,
    AppSettings settings,
  ) async {
    await _runAppleScript('''
          tell application "Terminal"
            activate
            do script "cd '${_escapeForAppleScript(directory)}' && ${_escapeForAppleScript(command)}"
          end tell
        ''', what: 'the command in Terminal');
  }

  Future<void> openGhostty(String directory) async {
    await openGhosttyWithCommand(directory, null);
  }

  Future<void> openGhosttyWithCommand(String directory, String? command) async {
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
    ''', what: 'Ghostty');
  }

  Future<void> _openCustomTerminal(
    String directory,
    String terminalCommand,
  ) async {
    final String shellCommand;
    if (terminalCommand.contains('{path}')) {
      // Substitute {path} with the directory
      shellCommand = terminalCommand.replaceAll('{path}', directory);
    } else {
      // Legacy: assume terminal emulator with -e flag
      shellCommand = '$terminalCommand -e "cd \'$directory\'"';
    }
    final args = ['-c', shellCommand];
    debugPrint('Running custom terminal: /bin/bash ${args.join(' ')}');
    try {
      final result = await Process.run('/bin/bash', args);
      if (result.exitCode != 0) {
        showAppSnackBar("Couldn't open the custom terminal");
        debugPrint('Custom terminal exited with code ${result.exitCode}');
        if ((result.stdout as String).isNotEmpty) {
          debugPrint('stdout: ${result.stdout}');
        }
        if ((result.stderr as String).isNotEmpty) {
          debugPrint('stderr: ${result.stderr}');
        }
      }
    } catch (e) {
      showAppSnackBar("Couldn't open the custom terminal");
      debugPrint('Custom terminal error: $e');
    }
  }

  Future<void> _runAppleScript(String script, {required String what}) =>
      _run('osascript', ['-e', script], what: what);

  /// Runs [executable], and shows a notice that [what] couldn't be opened
  /// when it fails.
  Future<void> _run(
    String executable,
    List<String> arguments, {
    required String what,
  }) async {
    try {
      final result = await Process.run(executable, arguments);
      if (result.exitCode == 0) return;
      debugPrint('$executable exited with ${result.exitCode}: ${result.stderr}');
    } catch (e) {
      debugPrint('$executable failed: $e');
    }
    showAppSnackBar("Couldn't open $what");
  }

  String _escapeForAppleScript(String s) => s.replaceAll("'", "'\\''");
  String _escapeForAppleScriptText(String s) =>
      s.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
}
