import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/jira/data/jira_api_service.dart';
import 'package:tree_launcher/features/jira/domain/jira_issue.dart';
import 'package:tree_launcher/features/jira/domain/jira_transition.dart';
import 'package:tree_launcher/features/jira/domain/jira_user.dart';
import 'package:tree_launcher/features/jira/domain/jira_version.dart';
import 'package:tree_launcher/features/jira/presentation/controllers/jira_issues_controller.dart';
import 'package:tree_launcher/features/jira/presentation/widgets/jira_issues_tab.dart';
import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';
import 'package:tree_launcher/features/workspace/data/git_service.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:tree_launcher/models/repo_config.dart';
import 'package:tree_launcher/models/worktree.dart';

class _FakeJiraService extends JiraApiService {
  @override
  Future<JiraUser> fetchMyself() async =>
      const JiraUser(name: 'me', displayName: 'Me Myself');

  @override
  Future<List<JiraVersion>> fetchVersions(String projectKey) async => const [
    JiraVersion(id: '29501', name: 'au2office 2.41.3'),
    JiraVersion(id: '29207', name: 'au2office 2.41.2', released: true),
  ];

  @override
  Future<List<JiraIssue>> searchIssues(String jql) async => const [
    JiraIssue(
      key: 'AU2-5928',
      summary: 'Værksted kontakt',
      status: 'Review',
      statusCategory: 'indeterminate',
      issueType: 'Story',
      assignee: 'Jane Doe',
    ),
    JiraIssue(
      key: 'AU2-5905',
      summary: 'Arbejdskort vælger forkert konto',
      status: 'Authorized',
      statusCategory: 'new',
      issueType: 'Bug',
      assignee: 'Me Myself',
    ),
  ];

  final applied = <String, String>{};
  final assigned = <String, String>{};
  final foundJql = <String>[];

  /// What a search finds.
  List<JiraIssue> found = const [
    JiraIssue(
      key: 'AU2-4100',
      summary: 'Konto på lånebil',
      status: 'Closed',
      statusCategory: 'done',
      issueType: 'Task',
    ),
  ];

  @override
  Future<List<JiraIssue>> findIssues(String jql, {required int limit}) async {
    foundJql.add(jql);
    return found;
  }

  @override
  Future<List<JiraTransition>> fetchTransitions(String key) async => [
    if (key == 'AU2-5905')
      const JiraTransition(
        id: '21',
        name: 'Start Progress',
        toStatus: 'In Progress',
        toStatusCategory: 'indeterminate',
      ),
    const JiraTransition(
      id: '31',
      name: 'Done',
      toStatus: 'Done',
      toStatusCategory: 'done',
    ),
  ];

  @override
  Future<void> transitionIssue(String key, String transitionId) async {
    applied[key] = transitionId;
  }

  @override
  Future<void> assignIssue(String key, String userName) async {
    assigned[key] = userName;
  }
}

class _FakeGitService extends GitService {
  @override
  Future<WorktreeListResult> getWorktrees(String repoPath) async =>
      WorktreeListResult(worktrees: const [], isBareLayout: false);

  @override
  Future<List<String>> listBranches(String repoPath) async => const ['develop'];
}

Future<_FakeJiraService> _pumpTab(
  WidgetTester tester, {
  required double width,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final workspace = WorkspaceController(gitService: _FakeGitService());
  final settings = SettingsController();
  final service = _FakeJiraService();
  final jira = JiraIssuesController(service: service)
    ..syncToRepo(
      RepoConfig(name: 'au2office', path: '/repos/au2', jiraProjectKey: 'AU2'),
    );
  addTearDown(jira.dispose);
  addTearDown(settings.dispose);
  addTearDown(workspace.dispose);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<WorkspaceController>.value(value: workspace),
        ChangeNotifierProvider<SettingsController>.value(value: settings),
        ChangeNotifierProvider<JiraIssuesController>.value(value: jira),
      ],
      child: MaterialApp(
        theme: AppTheme.current,
        home: const Scaffold(body: JiraIssuesTab()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return service;
}

/// [text] inside the issue list, not the status filter above it.
Finder _inList(String text) =>
    find.descendant(of: find.byType(ListView), matching: find.text(text));

void main() {
  testWidgets('lists issues, filters by status and prefills New Worktree', (
    tester,
  ) async {
    await _pumpTab(tester, width: 1400);

    // Both issues and the selected fixVersion are shown.
    expect(find.text('Værksted kontakt'), findsOneWidget);
    expect(find.text('Arbejdskort vælger forkert konto'), findsOneWidget);
    expect(find.text('au2office 2.41.3'), findsWidgets);
    expect(find.text('ASSIGNEE'), findsOneWidget);

    // Filtering on a status hides the other issue.
    await tester.tap(find.text('Authorized').first);
    await tester.pumpAndSettle();
    expect(find.text('Værksted kontakt'), findsNothing);
    expect(find.text('Arbejdskort vælger forkert konto'), findsOneWidget);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.text('Værksted kontakt'), findsOneWidget);

    // The create button opens New Worktree with the name and key filled in.
    await tester.tap(find.byTooltip('Create worktree for AU2-5928…'));
    await tester.pumpAndSettle();

    expect(find.text('New Worktree'), findsOneWidget);
    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .map((f) => f.controller?.text)
        .toList();
    expect(fields, contains('vaerksted-kontakt-au2-5928'));
    expect(fields, contains('AU2-5928'));
  });

  testWidgets('drops the assignee column in a narrow window without overflow', (
    tester,
  ) async {
    await _pumpTab(tester, width: 640);

    expect(find.text('Værksted kontakt'), findsOneWidget);
    expect(find.text('ASSIGNEE'), findsNothing);
    expect(find.text('Jane Doe'), findsNothing);
  });

  testWidgets('searches after a pause in typing, and Escape ends it', (
    tester,
  ) async {
    final service = await _pumpTab(tester, width: 1400);

    await tester.enterText(find.byType(TextField).last, 'kont');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(find.byType(TextField).last, 'konto');
    await tester.pump(const Duration(milliseconds: 200));
    expect(service.foundJql, isEmpty);
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    expect(service.foundJql.single, contains('text ~ "konto*"'));
    expect(find.text('Konto på lånebil'), findsOneWidget);
    expect(find.text('Værksted kontakt'), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('Konto på lånebil'), findsNothing);
    expect(find.text('Værksted kontakt'), findsOneWidget);
    expect(find.text('konto'), findsNothing);
  });

  testWidgets('searches at once on Enter and says when nothing matches', (
    tester,
  ) async {
    final service = await _pumpTab(tester, width: 1400)
      ..found = const [];

    await tester.enterText(find.byType(TextField).last, 'zzz');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(service.foundJql, hasLength(1));
    await tester.pumpAndSettle();
    expect(find.text('No issues match "zzz"'), findsOneWidget);
    expect(find.text('Værksted kontakt'), findsNothing);
  });

  testWidgets("changes an issue's status from its row", (tester) async {
    final service = await _pumpTab(tester, width: 1400);

    await tester.tap(_inList('Review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(service.applied, {'AU2-5928': '31'});
  });

  testWidgets('assigns an issue to me, offered only on others\' issues', (
    tester,
  ) async {
    final service = await _pumpTab(tester, width: 1400);

    // AU2-5905 is already mine.
    expect(find.byTooltip('Assign to me'), findsOneWidget);
    await tester.tap(find.byTooltip('Assign to me'));
    await tester.pumpAndSettle();

    expect(service.assigned, {'AU2-5928': 'me'});
  });

  testWidgets('changes the status of the selected issues together', (
    tester,
  ) async {
    final service = await _pumpTab(tester, width: 1400);

    await tester.tap(find.byTooltip('Select all'));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);

    await tester.tap(find.text('Change status'));
    await tester.pumpAndSettle();
    // Only AU2-5905 can start progress.
    expect(find.text('1 of 2'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(service.applied, {'AU2-5928': '31', 'AU2-5905': '31'});
    expect(find.text('2 selected'), findsNothing);
  });

  group('bulkMoveSummary', () {
    const done = JiraTransition(id: '31', name: 'Done', toStatus: 'Done');
    const move = JiraStatusMove(
      toStatus: 'Done',
      toStatusCategory: 'done',
      transitions: {'AU2-1': done, 'AU2-2': done, 'AU2-3': done},
    );

    test('counts the moved issues', () {
      expect(bulkMoveSummary(move, 3, const {}), 'Moved 3 issues to Done.');
    });

    test("names refusals and issues that can't move there", () {
      expect(
        bulkMoveSummary(move, 4, const {'AU2-2': 'Resolution is required.'}),
        'Moved 2 of 4 issues to Done. AU2-2: Resolution is required. '
        "1 can't move to Done.",
      );
    });
  });
}
