import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/jira/data/jira_api_service.dart';
import 'package:tree_launcher/features/jira/domain/jira_issue.dart';
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
    ),
  ];
}

class _FakeGitService extends GitService {
  @override
  Future<WorktreeListResult> getWorktrees(String repoPath) async =>
      WorktreeListResult(worktrees: const [], isBareLayout: false);

  @override
  Future<List<String>> listBranches(String repoPath) async => const ['develop'];
}

Future<void> _pumpTab(WidgetTester tester, {required double width}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final workspace = WorkspaceController(gitService: _FakeGitService());
  final settings = SettingsController();
  final jira = JiraIssuesController(service: _FakeJiraService())
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
        theme: AppTheme.dark,
        home: const Scaffold(body: JiraIssuesTab()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

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
}
