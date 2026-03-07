import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/models/issue.dart';
import 'package:tree_launcher/models/issue_status.dart';

void main() {
  group('Issue', () {
    test('serializes and restores shared issue status values', () {
      final issue = Issue(
        id: 'issue-1',
        projectId: 'project-1',
        issueNumber: 7,
        projectKey: 'KAN',
        title: 'Test issue',
        description: 'Description',
        status: IssueStatus.inReview,
        tags: const ['bug', 'api'],
        createdAt: DateTime.parse('2026-03-07T10:00:00.000Z'),
        updatedAt: DateTime.parse('2026-03-07T10:05:00.000Z'),
      );

      final restored = Issue.fromMap(issue.toMap());

      expect(restored.status, IssueStatus.inReview);
      expect(restored.displayId, 'KAN-007');
      expect(restored.tags, ['bug', 'api']);
    });

    test('copyWith can clear description explicitly', () {
      final issue = Issue(
        id: 'issue-1',
        projectId: 'project-1',
        issueNumber: 7,
        projectKey: 'KAN',
        title: 'Test issue',
        description: 'Description',
        createdAt: DateTime.parse('2026-03-07T10:00:00.000Z'),
        updatedAt: DateTime.parse('2026-03-07T10:05:00.000Z'),
      );

      final cleared = issue.copyWith(description: null);

      expect(cleared.description, isNull);
    });
  });
}
