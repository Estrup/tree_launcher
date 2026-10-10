import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tree_launcher/features/terminal/data/claude_desktop_handoff.dart';

/// Shell 50 runs the CLI 100 (through a wrapper, 60); shell 70 runs the CLI
/// 200. A registry file for 300 is left behind by a CLI that is gone.
const _parents = {60: 50, 100: 60, 200: 70, 50: 1, 70: 1};

void main() {
  late Directory sessionsDir;

  setUp(() {
    sessionsDir = Directory.systemTemp.createTempSync('claude_sessions');
  });

  tearDown(() => sessionsDir.deleteSync(recursive: true));

  void register(int pid, {String status = 'idle', String? kind}) {
    File(p.join(sessionsDir.path, '$pid.json')).writeAsStringSync(
      jsonEncode({
        'pid': pid,
        'sessionId': 'session-$pid',
        'cwd': '/work/$pid',
        'status': status,
        'kind': ?kind,
      }),
    );
  }

  ClaudeCliRegistry registry() => ClaudeCliRegistry(
    sessionsDir: sessionsDir.path,
    parentPids: () async => _parents,
  );

  group('ClaudeCliRegistry.runningUnder', () {
    test(
      'finds the CLI below the shell, through intermediate processes',
      () async {
        register(100, status: 'shell', kind: 'interactive');
        register(200);
        File(p.join(sessionsDir.path, '999.json')).writeAsStringSync('{oops');

        final cli = await registry().runningUnder(50);

        expect(cli?.pid, 100);
        expect(cli?.sessionId, 'session-100');
        expect(cli?.cwd, '/work/100');
        expect(cli?.status, 'shell');
        expect(cli?.atPrompt, isTrue);
      },
    );

    test('ignores CLIs of other shells and ones that are gone', () async {
      register(200);
      register(300);

      expect(await registry().runningUnder(50), isNull);
    });

    test('ignores background CLIs', () async {
      register(100, kind: 'bg');

      expect(await registry().runningUnder(50), isNull);
    });

    test('is null when there is no registry', () async {
      final missing = ClaudeCliRegistry(
        sessionsDir: p.join(sessionsDir.path, 'missing'),
        parentPids: () async => _parents,
      );

      expect(await missing.runningUnder(50), isNull);
    });
  });

  group('ClaudeDesktopHandoff.continueInDesktop', () {
    late List<String> typed;
    late List<String> continued;

    setUp(() {
      typed = [];
      continued = [];
    });

    ClaudeDesktopHandoff handoff({int exitCode = 0, String stderr = ''}) =>
        ClaudeDesktopHandoff(
          registry: registry(),
          keyDelay: Duration.zero,
          continueLatest: (dir) async {
            continued.add(dir);
            return ProcessResult(0, exitCode, '', stderr);
          },
        );

    Future<String?> run(ClaudeDesktopHandoff h, {int? shellPid = 50}) =>
        h.continueInDesktop(
          shellPid: shellPid,
          workingDirectory: '/work/tree',
          type: typed.add,
        );

    test('runs /desktop in a CLI at its prompt, clearing any draft', () async {
      register(100);

      expect(await run(handoff()), isNull);
      expect(typed, ['\x0c', '/desktop', '\r']);
      expect(continued, isEmpty);
    });

    test('types nothing while Claude is working or asking', () async {
      register(100, status: 'busy');
      expect(await run(handoff()), contains('working'));

      register(100, status: 'waiting');
      expect(await run(handoff()), contains('waiting'));

      expect(typed, isEmpty);
      expect(continued, isEmpty);
    });

    test('continues the latest session when Claude is not running', () async {
      expect(await run(handoff()), isNull);
      expect(await run(handoff(), shellPid: null), isNull);

      expect(continued, ['/work/tree', '/work/tree']);
      expect(typed, isEmpty);
    });

    test("reports the CLI's error when that fails", () async {
      final error = await run(
        handoff(exitCode: 1, stderr: 'No session in this directory.\n'),
      );

      expect(error, 'No session in this directory.');
    });
  });
}
