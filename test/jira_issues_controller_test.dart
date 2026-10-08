import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/features/jira/data/jira_api_service.dart';
import 'package:tree_launcher/features/jira/domain/jira_issue.dart';
import 'package:tree_launcher/features/jira/domain/jira_version.dart';
import 'package:tree_launcher/features/jira/presentation/controllers/jira_issues_controller.dart';
import 'package:tree_launcher/models/repo_config.dart';

class _FakeJiraService extends JiraApiService {
  _FakeJiraService({required this.versions, required this.issuesByVersion});

  final List<JiraVersion> versions;
  final Map<String, List<JiraIssue>> issuesByVersion;
  final List<String> searchedJql = [];

  @override
  Future<List<JiraVersion>> fetchVersions(String projectKey) async => versions;

  @override
  Future<List<JiraIssue>> searchIssues(String jql) async {
    searchedJql.add(jql);
    final id = RegExp(r'fixVersion = (\S+)').firstMatch(jql)!.group(1)!;
    return issuesByVersion[id] ?? const [];
  }
}

JiraIssue _issue(String key, String status, String category) => JiraIssue(
  key: key,
  summary: 'Summary $key',
  status: status,
  statusCategory: category,
);

RepoConfig _repo({String? key = 'AU2', String? versionId}) => RepoConfig(
  name: 'au2office',
  path: '/repos/au2office',
  jiraProjectKey: key,
  jiraFixVersionId: versionId,
);

/// Lets syncToRepo's deferred load and the fake's futures complete.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late _FakeJiraService service;
  late JiraIssuesController controller;

  setUp(() {
    service = _FakeJiraService(
      versions: const [
        JiraVersion(id: '1', name: 'au2office 2.40', released: true),
        JiraVersion(id: '2', name: 'au2office 2.41'),
        JiraVersion(id: '3', name: 'au2office 2.42'),
      ],
      issuesByVersion: {
        '2': [
          _issue('AU2-1', 'Review', 'indeterminate'),
          _issue('AU2-2', 'Closed', 'done'),
          _issue('AU2-3', 'Open', 'new'),
          _issue('AU2-4', 'Review', 'indeterminate'),
        ],
        '3': [_issue('AU2-9', 'Open', 'new')],
      },
    );
    controller = JiraIssuesController(service: service);
  });

  tearDown(() => controller.dispose());

  test('loads the remembered fixVersion for the repo', () async {
    controller.syncToRepo(_repo(versionId: '3'));
    await _settle();

    expect(controller.selectedVersion?.id, '3');
    expect(controller.issues.map((i) => i.key), ['AU2-9']);
    expect(service.searchedJql.single, contains('project = "AU2"'));
  });

  test(
    'defaults to the first unreleased version when none is remembered',
    () async {
      controller.syncToRepo(_repo());
      await _settle();

      // Unreleased versions come first; the released 2.40 is listed last.
      expect(controller.versions.map((v) => v.id), ['2', '3', '1']);
      expect(controller.selectedVersion?.id, '2');
      expect(controller.issues, hasLength(4));
    },
  );

  test('selecting a version remembers it and loads its issues', () async {
    final remembered = <String>[];
    controller.onVersionSelected = (repoPath, version) =>
        remembered.add('$repoPath#${version.id}');
    controller.syncToRepo(_repo());
    await _settle();

    await controller.selectVersion(controller.versions[1]);

    expect(remembered, ['/repos/au2office#3']);
    expect(controller.selectedVersion?.id, '3');
    expect(controller.issues.map((i) => i.key), ['AU2-9']);
  });

  test(
    'status filter narrows the issues and counts are ordered by category',
    () async {
      controller.syncToRepo(_repo(versionId: '2'));
      await _settle();

      expect(controller.statusCounts.map((s) => '${s.name}:${s.count}'), [
        'Open:1',
        'Review:2',
        'Closed:1',
      ]);

      controller.toggleStatus('Review');
      expect(controller.visibleIssues.map((i) => i.key), ['AU2-1', 'AU2-4']);

      controller.toggleStatus('Open');
      expect(controller.visibleIssues, hasLength(3));

      controller.clearStatusFilter();
      expect(controller.visibleIssues, hasLength(4));
    },
  );

  test(
    'a filtered status missing from the new version stays toggleable',
    () async {
      controller.syncToRepo(_repo(versionId: '2'));
      await _settle();
      controller.toggleStatus('Review');

      await controller.selectVersion(controller.versions[1]);

      expect(controller.visibleIssues, isEmpty);
      final review = controller.statusCounts.singleWhere(
        (s) => s.name == 'Review',
      );
      expect(review.count, 0);
    },
  );

  test('clears everything when the repo has no project key', () async {
    controller.syncToRepo(_repo(versionId: '2'));
    await _settle();
    expect(controller.issues, isNotEmpty);

    controller.syncToRepo(_repo(key: null));
    await _settle();

    expect(controller.projectKey, isNull);
    expect(controller.versions, isEmpty);
    expect(controller.issues, isEmpty);
  });
}
