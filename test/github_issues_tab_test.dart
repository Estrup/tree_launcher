import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/app/dependencies.dart';
import 'package:tree_launcher/features/activity/data/worktree_event_store.dart';
import 'package:tree_launcher/features/github_issues/domain/github_issue.dart';
import 'package:tree_launcher/features/github_issues/presentation/controllers/github_issues_controller.dart';
import 'package:tree_launcher/features/github_issues/presentation/widgets/github_issues_tab.dart';
import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:tree_launcher/models/worktree.dart';
import 'package:tree_launcher/services/git_service.dart';
import 'package:tree_launcher/theme/app_theme.dart';

import 'fake_github_issues_service.dart';
import 'fake_config_stores.dart';
import 'test_database.dart';

class _FakeGitService extends GitService {
  @override
  Future<WorktreeListResult> getWorktrees(String repoPath) async =>
      WorktreeListResult(worktrees: const [], isBareLayout: false);

  @override
  Future<List<String>> listBranches(String repoPath) async => const ['develop'];
}

class _Harness {
  _Harness(this.service, this.controller, this.opened);

  final FakeGithubIssuesService service;
  final GithubIssuesController controller;

  /// URLs the tab opened in the browser.
  final List<String> opened;
}

Future<_Harness> _pumpTab(
  WidgetTester tester, {
  double width = 1400,
  int? milestone,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final workspace = WorkspaceController(
    gitService: _FakeGitService(),
    repoConfigStore: FakeRepoConfigStore(),
    eventStore: WorktreeEventStore(testDatabase()),
  );
  final settings = SettingsController(store: FakeAppSettingsStore());
  final service = FakeGithubIssuesService();
  final controller = GithubIssuesController(service: service)
    ..syncToRepo(issuesRepo(milestone: milestone));
  addTearDown(controller.dispose);
  addTearDown(settings.dispose);
  addTearDown(workspace.dispose);
  final opened = <String>[];

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<WorkspaceController>.value(value: workspace),
        ChangeNotifierProvider<SettingsController>.value(value: settings),
        ChangeNotifierProvider<GithubIssuesController>.value(value: controller),
        // The issue dialog takes its cache from here.
        Provider<AppDependencies>.value(
          value: AppDependencies(
            database: testDatabase(),
            repoConfigStore: FakeRepoConfigStore(),
            appSettingsStore: FakeAppSettingsStore(),
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.current,
        home: Scaffold(body: GithubIssuesTab(openUrl: opened.add)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _Harness(service, controller, opened);
}

/// [text] inside the issue list, not the filter chips above it.
Finder _inList(String text) =>
    find.descendant(of: find.byType(ListView), matching: find.text(text));

void main() {
  testWidgets('lists open issues, filters by label and prefills New Worktree', (
    tester,
  ) async {
    await _pumpTab(tester);

    expect(_inList('Login redirect loops'), findsOneWidget);
    expect(_inList('Dark mode'), findsOneWidget);
    expect(find.text('All open issues'), findsWidgets);
    expect(find.text('ASSIGNEES'), findsOneWidget);
    // Labels show on the rows and as filter chips.
    expect(_inList('bug'), findsOneWidget);

    await tester.tap(find.text('enhancement').first);
    await tester.pumpAndSettle();
    expect(_inList('Login redirect loops'), findsNothing);
    expect(_inList('Dark mode'), findsOneWidget);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(_inList('Login redirect loops'), findsOneWidget);

    await tester.tap(find.byTooltip('Create worktree for #482…'));
    await tester.pumpAndSettle();
    expect(find.text('New Worktree'), findsOneWidget);
    expect(find.text('#482'), findsWidgets);
    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .map((f) => f.controller?.text)
        .toList();
    expect(fields, contains('login-redirect-loops-482'));
  });

  testWidgets('lists open milestones, and closed ones when searched', (
    tester,
  ) async {
    await _pumpTab(tester);
    final picker = find.byType(DropdownMenu<int>);

    await tester.tap(picker);
    await tester.pumpAndSettle();
    expect(find.text('v2.0'), findsWidgets);
    expect(find.text('v1.0'), findsNothing);

    await tester.enterText(picker, 'v1');
    await tester.pumpAndSettle();
    expect(find.text('v1.0'), findsWidgets);
    expect(find.text('closed'), findsOneWidget);
  });

  testWidgets('a milestone shows closed issues under their state chip', (
    tester,
  ) async {
    await _pumpTab(tester, milestone: 3);
    expect(_inList('Ship it'), findsOneWidget);
    expect(_inList('Done thing'), findsOneWidget);

    await tester.tap(find.text('Closed').first);
    await tester.pumpAndSettle();
    expect(_inList('Ship it'), findsNothing);
    expect(_inList('Done thing'), findsOneWidget);
  });

  testWidgets('opens an issue in the dialog or on GitHub', (tester) async {
    final harness = await _pumpTab(tester);

    // The row button goes straight to github.com.
    await tester.tap(find.byTooltip('Open #482 in GitHub'));
    await tester.pumpAndSettle();
    expect(harness.opened, ['https://github.com/acme/app/issues/482']);

    // The number badge opens the dialog, refreshed from GitHub.
    await tester.tap(find.text('#482'));
    await tester.pumpAndSettle();
    expect(find.text('acme/app#482'), findsOneWidget);
    expect(find.text('No comments'), findsOneWidget);
    expect(harness.service.detailFetches, 1);

    await tester.tap(find.text('Open in GitHub'));
    await tester.pumpAndSettle();
    expect(harness.opened.length, 2);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    // ⌘-clicking the title opens github.com instead of the dialog.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.tap(_inList('Dark mode'));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();
    expect(harness.opened.last, 'https://github.com/acme/app/issues/480');
    expect(find.text('acme/app#480'), findsNothing);
  });

  testWidgets('offers Assign to me only on issues not assigned to me', (
    tester,
  ) async {
    final harness = await _pumpTab(tester);
    expect(find.byTooltip('Assign to me'), findsOneWidget);

    await tester.tap(find.byTooltip('Assign to me'));
    await tester.pumpAndSettle();
    expect(harness.service.assigned, {482: 'me'});
  });

  testWidgets('changes one issue\'s state from its pill', (tester) async {
    final harness = await _pumpTab(tester);

    await tester.tap(find.text('Open').at(1)); // the first row's pill
    await tester.pumpAndSettle();
    expect(find.text('Reopen'), findsNothing);
    await tester.tap(find.text('Close as not planned'));
    await tester.pumpAndSettle();
    expect(harness.service.stateChanges, {482: GithubIssueState.notPlanned});
  });

  testWidgets('changes the state of the selected issues together', (
    tester,
  ) async {
    final harness = await _pumpTab(tester, milestone: 3);

    await tester.tap(find.byTooltip('Select all'));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);

    await tester.tap(find.text('Change state'));
    await tester.pumpAndSettle();
    // Each issue is already in one of these, so each applies to 1 of 2.
    expect(find.text('1 of 2'), findsNWidgets(2));
    await tester.tap(find.text('Close as completed'));
    await tester.pumpAndSettle();

    expect(harness.service.stateChanges, {470: GithubIssueState.closed});
    expect(harness.controller.selectedNumbers, isEmpty);
  });

  testWidgets('drops the assignees column in a narrow window', (tester) async {
    await _pumpTab(tester, width: 760);
    expect(find.text('ASSIGNEES'), findsNothing);
    expect(_inList('Login redirect loops'), findsOneWidget);
  });

  testWidgets('Clear ends the selection', (tester) async {
    final harness = await _pumpTab(tester);
    harness.controller.setSelected(480, true);
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsNothing);
    expect(harness.controller.selectedNumbers, isEmpty);
  });
}
