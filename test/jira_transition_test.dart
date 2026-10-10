import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/features/jira/domain/jira_transition.dart';

void main() {
  group('JiraTransition.fromApiJson', () {
    test('reads the name and the status it leads to', () {
      final t = JiraTransition.fromApiJson({
        'id': '21',
        'name': 'Start Progress',
        'to': {
          'name': 'In Progress',
          'statusCategory': {'key': 'indeterminate'},
        },
      });

      expect(t.id, '21');
      expect(t.name, 'Start Progress');
      expect(t.toStatus, 'In Progress');
      expect(t.toStatusCategory, 'indeterminate');
    });

    test('falls back to its own name without a target status', () {
      final t = JiraTransition.fromApiJson({'id': 31, 'name': 'Done'});

      expect(t.id, '31');
      expect(t.toStatus, 'Done');
      expect(t.toStatusCategory, isNull);
    });
  });
}
