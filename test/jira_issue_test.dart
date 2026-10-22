import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/features/jira/domain/jira_issue.dart';

void main() {
  group('JiraIssue.fromApiJson', () {
    test('reads the status category key', () {
      final issue = JiraIssue.fromApiJson({
        'key': 'AU2-1',
        'fields': {
          'summary': 's',
          'status': {
            'name': 'Review',
            'statusCategory': {'key': 'indeterminate'},
          },
        },
      });
      expect(issue.status, 'Review');
      expect(issue.statusCategory, 'indeterminate');
      expect(
        JiraIssue.fromJson(issue.toJson()).statusCategory,
        'indeterminate',
      );
    });

    test('reads the fixVersion ids and keeps them in the cache', () {
      final issue = JiraIssue.fromApiJson({
        'key': 'AU2-1',
        'fields': {
          'summary': 's',
          'fixVersions': [
            {'id': '29501', 'name': '2.41'},
            {'id': 29502, 'name': '2.42'},
          ],
        },
      });
      expect(issue.fixVersionIds, ['29501', '29502']);
      expect(JiraIssue.fromJson(issue.toJson()).fixVersionIds, [
        '29501',
        '29502',
      ]);
      expect(
        JiraIssue(key: 'AU2-2', summary: 's').toJson(),
        isNot(contains('fixVersionIds')),
      );
    });

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
  test('reads attachments and comment visibility, and caches them', () {
    final issue = JiraIssue.fromApiJson({
      'key': 'AU2-1',
      'fields': {
        'summary': 's',
        'attachment': [
          {
            'id': '901',
            'filename': 'image.png',
            'size': 2048,
            'mimeType': 'image/png',
            'content': 'https://jira/secure/attachment/901/image.png',
            'author': {'displayName': 'Susanne'},
            'created': '2025-11-11T10:29:42.000+0100',
          },
        ],
        'comment': {
          'comments': [
            {
              'body': 'intern',
              'visibility': {'type': 'role', 'value': 'Consultants'},
            },
            {'body': 'offentlig'},
          ],
        },
      },
    });

    for (final i in [issue, JiraIssue.fromJson(issue.toJson())]) {
      final a = i.attachments.single;
      expect(a.id, '901');
      expect(a.filename, 'image.png');
      expect(a.size, 2048);
      expect(a.isImage, isTrue);
      expect(a.contentUrl, 'https://jira/secure/attachment/901/image.png');
      expect(a.author, 'Susanne');
      expect(a.created, isNotNull);
      expect([for (final c in i.comments) c.visibility], ['Consultants', null]);
      expect(i.attachmentNamed('image.png'), isNotNull);
      expect(i.attachmentNamed('other.png'), isNull);
    }
  });
}
