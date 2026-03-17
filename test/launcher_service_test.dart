import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/services/launcher_service.dart';

void main() {
  group('LauncherService Windows VS Code launch', () {
    test('lists common Windows VS Code executable locations', () {
      expect(
        LauncherService.windowsVSCodeExecutableCandidates({
          'LOCALAPPDATA': r'C:\Users\sen\AppData\Local',
          'ProgramFiles': r'C:\Program Files',
          'ProgramFiles(x86)': r'C:\Program Files (x86)',
        }),
        [
          r'C:\Users\sen\AppData\Local\Programs\Microsoft VS Code\Code.exe',
          r'C:\Program Files\Microsoft VS Code\Code.exe',
          r'C:\Program Files (x86)\Microsoft VS Code\Code.exe',
        ],
      );
    });

    test('falls back to Code.exe when the code CLI is unavailable', () async {
      final launches =
          <({String executable, List<String> args, bool runInShell})>[];
      final service = LauncherService(
        isWindowsOverride: true,
        environment: {
          'LOCALAPPDATA': r'C:\Users\sen\AppData\Local',
          'ProgramFiles': r'C:\Program Files',
        },
        fileExists: (path) =>
            path ==
            r'C:\Users\sen\AppData\Local\Programs\Microsoft VS Code\Code.exe',
        startProcess: (
          executable,
          arguments, {
          runInShell = false,
          mode = ProcessStartMode.normal,
        }) async {
          launches.add(
            (
              executable: executable,
              args: List<String>.from(arguments),
              runInShell: runInShell,
            ),
          );
          if (executable == 'code') {
            throw ProcessException(executable, arguments, 'not found');
          }
        },
      );

      await service.openVSCode(r'C:\Projects\tree_launcher\main');

      expect(launches, hasLength(2));
      expect(launches.first.executable, 'code');
      expect(launches.first.args, [r'C:\Projects\tree_launcher\main']);
      expect(launches.first.runInShell, isTrue);
      expect(
        launches.last.executable,
        r'C:\Users\sen\AppData\Local\Programs\Microsoft VS Code\Code.exe',
      );
      expect(launches.last.args, [r'C:\Projects\tree_launcher\main']);
      expect(launches.last.runInShell, isFalse);
    });

    test('throws a helpful error when VS Code cannot be found', () async {
      final service = LauncherService(
        isWindowsOverride: true,
        environment: const {},
        fileExists: (_) => false,
        startProcess: (
          executable,
          arguments, {
          runInShell = false,
          mode = ProcessStartMode.normal,
        }) async {
          throw ProcessException(executable, arguments, 'not found');
        },
      );

      await expectLater(
        service.openVSCode(r'C:\Projects\tree_launcher\main'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Visual Studio Code'),
          ),
        ),
      );
    });
  });

  group('LauncherService non-Windows VS Code launch', () {
    test('uses the code CLI when it is available', () async {
      final launches =
          <({String executable, List<String> args, bool runInShell})>[];
      final checks = <({String executable, List<String> args, bool runInShell})>[];

      final service = LauncherService(
        isWindowsOverride: false,
        runProcess: (
          executable,
          arguments, {
          runInShell = false,
        }) async {
          checks.add(
            (
              executable: executable,
              args: List<String>.from(arguments),
              runInShell: runInShell,
            ),
          );
          return ProcessResult(1, 0, '', '');
        },
        startProcess: (
          executable,
          arguments, {
          runInShell = false,
          mode = ProcessStartMode.normal,
        }) async {
          launches.add(
            (
              executable: executable,
              args: List<String>.from(arguments),
              runInShell: runInShell,
            ),
          );
        },
      );

      await service.openVSCode('/tmp/tree_launcher');

      expect(checks, hasLength(1));
      expect(checks.single.executable, 'which');
      expect(checks.single.args, ['code']);
      expect(launches, hasLength(1));
      expect(launches.single.executable, 'code');
      expect(launches.single.args, ['/tmp/tree_launcher']);
      expect(launches.single.runInShell, isFalse);
    });

    test('falls back to open -a when the code CLI is unavailable', () async {
      final launches =
          <({String executable, List<String> args, bool runInShell})>[];

      final service = LauncherService(
        isWindowsOverride: false,
        runProcess: (
          executable,
          arguments, {
          runInShell = false,
        }) async {
          return ProcessResult(1, 1, '', 'missing');
        },
        startProcess: (
          executable,
          arguments, {
          runInShell = false,
          mode = ProcessStartMode.normal,
        }) async {
          launches.add(
            (
              executable: executable,
              args: List<String>.from(arguments),
              runInShell: runInShell,
            ),
          );
        },
      );

      await service.openVSCode('/tmp/tree_launcher');

      expect(launches, hasLength(1));
      expect(launches.single.executable, 'open');
      expect(launches.single.args, [
        '-a',
        'Visual Studio Code',
        '/tmp/tree_launcher',
      ]);
      expect(launches.single.runInShell, isFalse);
    });
  });
}
