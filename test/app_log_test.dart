import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/core/logging/app_log.dart';
import 'package:tree_launcher/features/log/presentation/widgets/log_dialog.dart';

void main() {
  group('LogEntry', () {
    test('reads back the line it writes', () {
      final entry = LogEntry(
        at: DateTime(2026, 10, 22, 9, 5, 3, 120),
        level: LogLevel.warning,
        source: 'jira-triggers',
        message: 'Checked 2 triggers',
      );
      final line = entry.toLine();
      expect(
        line,
        '2026-10-22 09:05:03.120 WARNING jira-triggers  Checked 2 triggers',
      );
      final parsed = LogEntry.parse(line)!;
      expect(parsed.at, entry.at);
      expect(parsed.level, LogLevel.warning);
      expect(parsed.source, 'jira-triggers');
      expect(parsed.message, 'Checked 2 triggers');
      expect(LogEntry.parse('    a later line'), isNull);
    });
  });

  group('AppLog', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('app_log');
      addTearDown(() => dir.delete(recursive: true));
    });

    test('writes a file a day and reads today\'s back in', () async {
      final log = AppLog(directory: dir.path);
      await log.open();
      log.add(LogLevel.info, 'app', 'Started');
      log.add(LogLevel.error, 'agent-api', 'Failed\nwith a second line');
      await log.flush();

      final file = File(log.fileFor(DateTime.now())!);
      final lines = await file.readAsLines();
      expect(lines, hasLength(3));
      expect(lines[1], endsWith('ERROR   agent-api      Failed'));
      expect(lines[2], '    with a second line');

      final reopened = AppLog(directory: dir.path);
      await reopened.open();
      expect(reopened.entries.map((e) => e.message), [
        'Started',
        'Failed\nwith a second line',
      ]);
    });

    test('deletes day files older than it keeps', () async {
      final old = File('${dir.path}/2020-01-01.log')..writeAsStringSync('x');
      final other = File('${dir.path}/notes.txt')..writeAsStringSync('x');
      await AppLog(directory: dir.path, keepDays: 14).open();
      expect(old.existsSync(), isFalse);
      expect(other.existsSync(), isTrue);
    });

    test('keeps the newest entries in memory', () {
      final log = AppLog(capacity: 2);
      for (var i = 0; i < 3; i++) {
        log.add(LogLevel.info, 'app', '$i');
      }
      expect(log.entries.map((e) => e.message), ['1', '2']);
    });

    test('logs debugPrints, failures as warnings', () {
      final original = debugPrint;
      addTearDown(() => debugPrint = original);
      final log = AppLog()..captureDebugPrint();

      debugPrint('Loaded 3 repos');
      debugPrint('Reading the token failed: nope');
      expect(log.entries.map((e) => (e.level, e.message)), [
        (LogLevel.debug, 'Loaded 3 repos'),
        (LogLevel.warning, 'Reading the token failed: nope'),
      ]);
    });
  });

  testWidgets('the Log window filters by level and text', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final log = AppLog()
      ..add(LogLevel.debug, 'jira', 'Loaded 34 issues')
      ..add(LogLevel.info, 'jira-triggers', 'Checked 2 triggers')
      ..add(LogLevel.error, 'agent-api', 'Failed to start');
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: log,
        child: MaterialApp(
          theme: AppTheme.current,
          home: const Scaffold(body: LogDialog()),
        ),
      ),
    );

    // Info and up by default.
    expect(find.text('Checked 2 triggers'), findsOneWidget);
    expect(find.text('Failed to start'), findsOneWidget);
    expect(find.text('Loaded 34 issues'), findsNothing);

    await tester.enterText(find.byType(TextField), 'fail');
    await tester.pump();
    expect(find.text('Checked 2 triggers'), findsNothing);
    expect(find.text('Failed to start'), findsOneWidget);

    // New entries show as they come.
    await tester.enterText(find.byType(TextField), '');
    log.add(LogLevel.info, 'claude', 'Started Claude');
    await tester.pump();
    expect(find.text('Started Claude'), findsOneWidget);
  });
}
