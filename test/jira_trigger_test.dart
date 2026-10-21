import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/core/database/app_database.dart';
import 'package:tree_launcher/features/jira/data/jira_trigger_store.dart';
import 'package:tree_launcher/features/jira/domain/jira_trigger.dart';
import 'package:tree_launcher/features/jira/domain/jira_trigger_schedule.dart';
import 'package:tree_launcher/features/settings/domain/app_settings.dart';

import 'test_database.dart';

void main() {
  final since = DateTime(2026, 10, 21, 9, 5, 42);

  group('JiraTrigger', () {
    test('round-trips through JSON', () {
      final trigger = JiraTrigger(
        id: 't1',
        fixVersionId: '29501',
        since: since,
        enabled: false,
        event: JiraTriggerEvent.created,
        status: 'QA Rejected',
        assignedToMe: true,
        promptName: 'Refine',
        worktreePath: '/repos/shared',
        model: 'sonnet',
        effort: 'max',
      );
      final restored = JiraTrigger.fromJson(trigger.toJson());
      expect(restored.toJson(), trigger.toJson());
      expect(restored.since, since);
      expect(restored.event, JiraTriggerEvent.created);
      expect((restored.model, restored.effort), ('sonnet', 'max'));
      // A rule saved without them, or with an unknown one, gets the defaults.
      final bare = JiraTrigger.fromJson({
        'id': 't',
        'fixVersionId': '1',
        'model': 'gpt',
      });
      expect((bare.model, bare.effort), ('opus', 'high'));
      expect(restored.copyWith(clearWorktreePath: true).worktreePath, isNull);
    });

    test('needs a prompt, and a status for a status rule', () {
      final trigger = JiraTrigger(id: 't', fixVersionId: '1', since: since);
      expect(trigger.isComplete, isFalse);
      expect(trigger.copyWith(promptName: 'Fix').isComplete, isFalse);
      expect(
        trigger.copyWith(promptName: 'Fix', status: ' ').isComplete,
        isFalse,
      );
      expect(
        trigger.copyWith(promptName: 'Fix', status: 'QA Rejected').isComplete,
        isTrue,
      );
      expect(
        trigger
            .copyWith(promptName: 'Refine', event: JiraTriggerEvent.created)
            .isComplete,
        isTrue,
      );
    });

    test('a status rule matches issues that moved to the status since', () {
      final trigger = JiraTrigger(
        id: 't',
        fixVersionId: '29501',
        since: since,
        status: 'QA "Rejected"',
        assignedToMe: true,
      );
      expect(
        trigger.jql('AU2'),
        'project = "AU2" AND fixVersion = 29501 AND '
        r'status = "QA \"Rejected\"" AND '
        r'status CHANGED TO "QA \"Rejected\"" AFTER "2026/10/21 09:05" AND '
        'assignee = currentUser() AND '
        'issuetype not in subTaskIssueTypes() ORDER BY created ASC',
      );
    });

    test('a created rule matches issues created since', () {
      final trigger = JiraTrigger(
        id: 't',
        fixVersionId: '29501',
        since: since,
        event: JiraTriggerEvent.created,
      );
      expect(
        trigger.jql('AU2'),
        'project = "AU2" AND fixVersion = 29501 AND '
        'created >= "2026/10/21 09:05" AND '
        'issuetype not in subTaskIssueTypes() ORDER BY created ASC',
      );
    });
  });

  group('JiraTriggerStore', () {
    test('remembers fired issues while they match', () async {
      final store = JiraTriggerStore(testDatabase());
      expect(await store.claim('t1', 'AU2-1'), isTrue);
      expect(await store.claim('t1', 'AU2-2'), isTrue);
      expect(await store.claim('t2', 'AU2-1'), isTrue);
      // Already fired, e.g. by another instance.
      expect(await store.claim('t1', 'AU2-1'), isFalse);
      expect(await store.firedFor('t1'), {'AU2-1', 'AU2-2'});

      await store.keepOnly('t1', {'AU2-2'});
      expect(await store.firedFor('t1'), {'AU2-2'});
      expect(await store.firedFor('t2'), {'AU2-1'});

      await store.keepTriggers({'t2'});
      expect(await store.firedFor('t1'), isEmpty);
      expect(await store.firedFor('t2'), {'AU2-1'});
    });

    test('claims once on a file database in a background isolate', () async {
      final dir = await Directory.systemTemp.createTemp('trigger_db');
      final db = AppDatabase.open(directory: dir.path);
      addTearDown(() async {
        await db.close();
        await dir.delete(recursive: true);
      });
      final store = JiraTriggerStore(db);
      expect(await store.claim('t1', 'AU2-1'), isTrue);
      expect(await store.claim('t1', 'AU2-1'), isFalse);
    });
  });

  group('JiraTriggerSchedule', () {
    DateTime at(int hour, int minute) => DateTime(2026, 10, 21, hour, minute);

    test('checks all day without hours, never when off', () {
      const schedule = JiraTriggerSchedule();
      expect(schedule.isActiveAt(at(3, 0)), isTrue);
      expect(schedule.intervalMinutes, 10);
      expect(schedule.copyWith(enabled: false).isActiveAt(at(12, 0)), isFalse);
    });

    test('checks from the start time until the end time', () {
      const day = JiraTriggerSchedule(from: 7 * 60, until: 17 * 60);
      expect(day.isActiveAt(at(6, 59)), isFalse);
      expect(day.isActiveAt(at(7, 0)), isTrue);
      expect(day.isActiveAt(at(16, 59)), isTrue);
      expect(day.isActiveAt(at(17, 0)), isFalse);

      const night = JiraTriggerSchedule(from: 22 * 60, until: 6 * 60);
      expect(night.isActiveAt(at(23, 0)), isTrue);
      expect(night.isActiveAt(at(5, 0)), isTrue);
      expect(night.isActiveAt(at(12, 0)), isFalse);
    });

    test('reads and writes times as HH:mm', () {
      expect(parseTimeOfDay('7:05'), 425);
      expect(parseTimeOfDay('07:05'), 425);
      expect(parseTimeOfDay('24:00'), isNull);
      expect(parseTimeOfDay('7'), isNull);
      expect(formatTimeOfDay(425), '07:05');

      const schedule = JiraTriggerSchedule(
        enabled: false,
        intervalMinutes: 15,
        from: 7 * 60,
        until: 17 * 60,
      );
      expect(schedule.toJson(), {
        'enabled': false,
        'intervalMinutes': 15,
        'from': '07:00',
        'until': '17:00',
      });
      final settings = AppSettings.fromJson(
        AppSettings(jiraTriggerSchedule: schedule).toJson(),
      );
      expect(settings.jiraTriggerSchedule, schedule);
      expect(
        AppSettings.fromJson(const {}).jiraTriggerSchedule,
        const JiraTriggerSchedule(),
      );
    });
  });
}
