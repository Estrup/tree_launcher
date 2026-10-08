import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/features/jira/domain/jira_version.dart';

JiraVersion _v(String id, {bool released = false, bool archived = false}) =>
    JiraVersion(id: id, name: 'v$id', released: released, archived: archived);

void main() {
  group('JiraVersion.fromApiJson', () {
    test('parses id, name and flags', () {
      final v = JiraVersion.fromApiJson({
        'id': '29501',
        'name': 'au2office 2.41.3',
        'released': false,
        'archived': false,
      });
      expect(v.id, '29501');
      expect(v.name, 'au2office 2.41.3');
      expect(v.released, isFalse);
      expect(v.archived, isFalse);
    });
  });

  group('orderVersionsForPicker', () {
    test('drops archived, keeps unreleased order, released newest-first', () {
      final ordered = orderVersionsForPicker([
        _v('1', released: true),
        _v('2', archived: true),
        _v('3'),
        _v('4', released: true),
        _v('5'),
        _v('6', released: true, archived: true),
      ]);
      expect(ordered.map((v) => v.id), ['3', '5', '4', '1']);
    });
  });

  group('pickVersion', () {
    final ordered = [_v('3'), _v('5'), _v('4', released: true)];

    test('returns the remembered version when it is still listed', () {
      expect(pickVersion(ordered, '4')?.id, '4');
    });

    test('falls back to the first version', () {
      expect(pickVersion(ordered, 'gone')?.id, '3');
      expect(pickVersion(ordered, null)?.id, '3');
    });

    test('returns null when there are no versions', () {
      expect(pickVersion(const [], '3'), isNull);
    });
  });

  test(
    'fixVersionIssuesJql filters by project and version, skips sub-tasks',
    () {
      expect(
        fixVersionIssuesJql('AU2', '29501'),
        'project = "AU2" AND fixVersion = 29501 '
        'AND issuetype not in subTaskIssueTypes() ORDER BY Rank ASC',
      );
    },
  );
}
