import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/features/jira/data/jira_api_service.dart';
import 'package:tree_launcher/features/jira/domain/jira_issue.dart';
import 'package:tree_launcher/features/jira/domain/jira_transition.dart';
import 'package:tree_launcher/features/jira/domain/jira_user.dart';
import 'package:tree_launcher/features/jira/domain/jira_version.dart';
import 'package:tree_launcher/features/jira/presentation/controllers/jira_issues_controller.dart';
import 'package:tree_launcher/models/repo_config.dart';

class _FakeJiraService extends JiraApiService {
  _FakeJiraService({required this.versions, required this.issuesByVersion});

  final List<JiraVersion> versions;
  final Map<String, List<JiraIssue>> issuesByVersion;
  final List<String> searchedJql = [];

  /// Issue key -> its transitions.
  Map<String, List<JiraTransition>> transitions = {};

  /// Issue keys Jira refuses to move, with the reason.
  Map<String, String> refusals = {};
  final applied = <String, String>{};
  final assigned = <String, String>{};

  @override
  Future<JiraUser> fetchMyself() async =>
      const JiraUser(name: 'sen', displayName: 'Steffen Nielsen');

  @override
  Future<List<JiraTransition>> fetchTransitions(String key) async =>
      transitions[key] ?? const [];

  @override
  Future<void> transitionIssue(String key, String transitionId) async {
    final refusal = refusals[key];
    if (refusal != null) throw Exception(refusal);
    applied[key] = transitionId;
  }

  @override
  Future<void> assignIssue(String key, String userName) async {
    assigned[key] = userName;
  }

  @override
  Future<List<JiraVersion>> fetchVersions(String projectKey) async => versions;

  @override
  Future<List<JiraIssue>> searchIssues(String jql) async {
    searchedJql.add(jql);
    final id = RegExp(r'fixVersion = (\S+)').firstMatch(jql)!.group(1)!;
    return issuesByVersion[id] ?? const [];
  }

  /// What a search finds.
  List<JiraIssue> found = const [];
  final foundJql = <String>[];

  @override
  Future<List<JiraIssue>> findIssues(String jql, {required int limit}) async {
    foundJql.add(jql);
    return found.take(limit).toList();
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

  group('selection', () {
    setUp(() async {
      controller.syncToRepo(_repo(versionId: '2'));
      await _settle();
    });

    test('selects all visible issues, then none', () {
      controller.toggleStatus('Review');
      controller.toggleSelectAll();
      expect(controller.selectedKeys, {'AU2-1', 'AU2-4'});

      controller.toggleSelectAll();
      expect(controller.selectedKeys, isEmpty);
    });

    test('drops issues the status filter hides', () {
      controller.setSelected('AU2-1', true);
      controller.setSelected('AU2-3', true);

      controller.toggleStatus('Review');

      expect(controller.selectedKeys, {'AU2-1'});
      expect(controller.selectedIssues.map((i) => i.key), ['AU2-1']);
    });

    test('is cleared by switching version', () async {
      controller.setSelected('AU2-1', true);

      await controller.selectVersion(service.versions.last);

      expect(controller.selectedKeys, isEmpty);
    });
  });

  group('changing issues', () {
    const start = JiraTransition(
      id: '21',
      name: 'Start Progress',
      toStatus: 'In Progress',
      toStatusCategory: 'indeterminate',
    );
    const close = JiraTransition(
      id: '31',
      name: 'Close',
      toStatus: 'Closed',
      toStatusCategory: 'done',
    );

    setUp(() async {
      controller.syncToRepo(_repo(versionId: '2'));
      await _settle();
    });

    test('offers every status any of the issues can move to', () async {
      service.transitions = {
        'AU2-1': [close, start],
        // Another workflow: a different transition id to the same status.
        'AU2-3': [
          const JiraTransition(
            id: '11',
            name: 'Begin',
            toStatus: 'In Progress',
          ),
        ],
      };

      final moves = await controller.statusMovesFor(['AU2-1', 'AU2-3']);

      expect(moves.map((m) => m.toStatus), ['In Progress', 'Closed']);
      expect(moves.first.transitions.map((key, t) => MapEntry(key, t.id)), {
        'AU2-1': '21',
        'AU2-3': '11',
      });
      expect(moves.last.transitions.keys, ['AU2-1']);
    });

    test('moves the issues, reports refusals and reloads', () async {
      service.transitions = {
        'AU2-1': [close],
        'AU2-3': [close],
      };
      service.refusals = {'AU2-3': 'Resolution is required.'};
      final searches = service.searchedJql.length;

      final moves = await controller.statusMovesFor(['AU2-1', 'AU2-3']);
      final failures = await controller.applyStatusMove(moves.single);

      expect(service.applied, {'AU2-1': '31'});
      expect(failures, {'AU2-3': 'Resolution is required.'});
      expect(service.searchedJql.length, searches + 1);
    });

    test('assigns an issue to the token user and reloads', () async {
      final searches = service.searchedJql.length;

      await controller.assignToMe('AU2-2');

      expect(service.assigned, {'AU2-2': 'sen'});
      expect(controller.myDisplayName, 'Steffen Nielsen');
      expect(service.searchedJql.length, searches + 1);
    });
  });

  group('search', () {
    setUp(() async {
      service.found = [
        _issue('AU2-7', 'Open', 'new'),
        _issue('AU2-5928', 'Review', 'indeterminate'),
      ];
      controller.syncToRepo(_repo(versionId: '2'));
      await _settle();
    });

    test('shows the issues found, the named issue first', () async {
      await controller.search(' au2-5928 ');

      expect(controller.isSearching, isTrue);
      expect(controller.searchQuery, 'au2-5928');
      expect(service.foundJql.single, startsWith('key = "AU2-5928" OR'));
      expect(controller.issues.map((i) => i.key), ['AU2-5928', 'AU2-7']);
      expect(controller.statusCounts.map((s) => s.name), ['Open', 'Review']);
      expect(controller.searchTruncated, isFalse);
    });

    test('says when it may have found more than it shows', () async {
      service.found = [
        for (var i = 0; i < JiraIssuesController.searchLimit + 5; i++)
          _issue('AU2-$i', 'Open', 'new'),
      ];

      await controller.search('konto');

      expect(controller.issues, hasLength(JiraIssuesController.searchLimit));
      expect(controller.searchTruncated, isTrue);
    });

    test(
      'an empty search goes back to the fixVersion and reloads it',
      () async {
        await controller.search('konto');
        final loads = service.searchedJql.length;

        await controller.search('  ');

        expect(controller.isSearching, isFalse);
        expect(controller.issues, hasLength(4));
        expect(service.searchedJql, hasLength(loads + 1));
      },
    );

    test('nothing searchable keeps the fixVersion without reloading', () async {
      final loads = service.searchedJql.length;

      await controller.search('*');

      expect(controller.isSearching, isFalse);
      expect(controller.issues, hasLength(4));
      expect(service.searchedJql, hasLength(loads));
      expect(service.foundJql, isEmpty);
    });

    test('picking a fixVersion, even the same one, ends it', () async {
      await controller.search('konto');

      await controller.selectVersion(controller.selectedVersion!);

      expect(controller.searchQuery, isEmpty);
      expect(controller.issues, hasLength(4));
    });

    test('refreshing, e.g. after a status change, searches again', () async {
      await controller.search('konto');
      service.transitions = {
        'AU2-7': const [
          JiraTransition(id: '31', name: 'Done', toStatus: 'Done'),
        ],
      };

      final moves = await controller.statusMovesFor(['AU2-7']);
      await controller.applyStatusMove(moves.single);

      expect(service.foundJql, hasLength(2));
      expect(controller.isSearching, isTrue);
    });

    test('is cleared by switching repo', () async {
      await controller.search('konto');

      controller.syncToRepo(_repo(key: 'OA'));
      await _settle();

      expect(controller.searchQuery, isEmpty);
      expect(controller.isSearching, isFalse);
    });
  });
}
