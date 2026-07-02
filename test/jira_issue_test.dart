import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/features/jira/domain/jira_issue.dart';

void main() {
  group('JiraIssue.fromApiJson', () {
    test('parses nested fields and comments', () {
      final issue = JiraIssue.fromApiJson({
        'key': 'AU2-1234',
        'fields': {
          'summary': 'Fix the login bug',
          'status': {'name': 'In Progress'},
          'issuetype': {'name': 'Bug'},
          'assignee': {'displayName': 'Jane Doe'},
          'priority': {'name': 'High'},
          'description': 'Steps to reproduce…',
          'updated': '2026-06-05T18:22:17.000+0200',
          'comment': {
            'comments': [
              {
                'author': {'displayName': 'John Smith'},
                'body': 'Looking into it',
                'created': '2026-06-06T09:00:00.000+0200',
              },
            ],
          },
        },
      });

      expect(issue.key, 'AU2-1234');
      expect(issue.summary, 'Fix the login bug');
      expect(issue.status, 'In Progress');
      expect(issue.issueType, 'Bug');
      expect(issue.assignee, 'Jane Doe');
      expect(issue.priority, 'High');
      expect(issue.description, 'Steps to reproduce…');
      expect(issue.updated, isNotNull);
      expect(issue.comments.length, 1);
      expect(issue.comments.single.author, 'John Smith');
      expect(issue.comments.single.body, 'Looking into it');
      expect(issue.comments.single.created, isNotNull);
    });

    test('tolerates null assignee, priority, and missing comments', () {
      final issue = JiraIssue.fromApiJson({
        'key': 'OA-1',
        'fields': {
          'summary': 'Unassigned task',
          'status': {'name': 'Open'},
          'issuetype': {'name': 'Task'},
          'assignee': null,
          'priority': null,
          'description': null,
        },
      });

      expect(issue.assignee, isNull);
      expect(issue.priority, isNull);
      expect(issue.description, isNull);
      expect(issue.updated, isNull);
      expect(issue.comments, isEmpty);
    });

    test('tolerates an entirely missing fields object', () {
      final issue = JiraIssue.fromApiJson({'key': 'OA-2'});
      expect(issue.key, 'OA-2');
      expect(issue.summary, '');
      expect(issue.comments, isEmpty);
    });
  });

  group('JiraIssue cache round-trip (toJson/fromJson)', () {
    test('preserves all fields including comments', () {
      final original = JiraIssue(
        key: 'AU2-9',
        summary: 'Round trip',
        status: 'Done',
        issueType: 'Story',
        assignee: 'Jane Doe',
        priority: 'Low',
        description: 'desc',
        updated: DateTime.parse('2026-06-05T18:22:17.000Z'),
        comments: [
          JiraComment(
            author: 'A',
            body: 'b',
            created: DateTime.parse('2026-06-06T09:00:00.000Z'),
          ),
        ],
      );

      final restored = JiraIssue.fromJson(original.toJson());

      expect(restored.key, original.key);
      expect(restored.summary, original.summary);
      expect(restored.status, original.status);
      expect(restored.issueType, original.issueType);
      expect(restored.assignee, original.assignee);
      expect(restored.priority, original.priority);
      expect(restored.description, original.description);
      expect(restored.updated, original.updated);
      expect(restored.comments.single.author, 'A');
      expect(restored.comments.single.body, 'b');
      expect(restored.comments.single.created, original.comments.single.created);
    });

    test('omits null fields and round-trips them back to null', () {
      final original = JiraIssue(key: 'AU2-10', summary: 'minimal');
      final json = original.toJson();
      expect(json.containsKey('assignee'), isFalse);
      expect(json.containsKey('priority'), isFalse);

      final restored = JiraIssue.fromJson(json);
      expect(restored.assignee, isNull);
      expect(restored.priority, isNull);
      expect(restored.comments, isEmpty);
    });
  });
}
