import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/platform/launcher_service.dart';
import 'package:tree_launcher/features/activity/data/worktree_event_store.dart';
import 'package:tree_launcher/features/agents/domain/agent_kind.dart';
import 'package:tree_launcher/features/agents/presentation/controllers/agents_controller.dart';
import 'package:tree_launcher/features/github_prs/presentation/controllers/github_prs_controller.dart';
import 'package:tree_launcher/features/jira/data/jira_issue_cache.dart';
import 'package:tree_launcher/features/jira/presentation/controllers/jira_titles_controller.dart';
import 'package:tree_launcher/features/workspace/data/git_service.dart';
import 'package:tree_launcher/features/workspace/domain/worktree.dart';
import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/row_sessions.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/worktree_list.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/worktree_table.dart';

import 'fake_config_stores.dart';
import 'test_database.dart';

Worktree _wt(String name, {bool isMain = false}) => Worktree(
  path: '/tmp/repo/$name',
  branch: name,
  name: name,
  isMain: isMain,
  commitHash: 'abc123',
);

Finder _checkboxes() => find.byWidgetPredicate(
  (w) => w.runtimeType.toString() == 'SelectCheckbox',
);

class _FakeGitService extends GitService {
  @override
  Future<WorktreeListResult> getWorktrees(String repoPath) async {
    return WorktreeListResult(worktrees: const [], isBareLayout: false);
  }

  @override
  Future<bool> isGitRepo(String path) async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late WorkspaceController workspace;
  late SettingsController settings;
  late GithubPrsController prs;

  // Some stores (settings, event log) resolve the app-support directory even
  // when a fake ConfigService is injected; point them at a temp dir.
  final tempDir = Directory.systemTemp.createTempSync('worktree_table_test');
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        pathProviderChannel,
        (call) async => tempDir.path,
      );

  setUp(() async {
    workspace = WorkspaceController(
      gitService: _FakeGitService(),
      repoConfigStore: FakeRepoConfigStore(),
      eventStore: WorktreeEventStore(testDatabase()),
      metadataStore: MemoryWorktreeMetadataStore(),
    );
    settings = SettingsController(store: FakeAppSettingsStore());
    prs = GithubPrsController();
    await workspace.addRepo('/tmp/repo');
  });

  tearDown(() {
    prs.dispose();
    settings.dispose();
    workspace.dispose();
  });

  /// Checkboxes only accept pointer events once revealed by hover (or an
  /// active selection), so move a mouse pointer over the target first.
  Future<void> hoverAndTap(WidgetTester tester, Finder finder) async {
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    await gesture.moveTo(tester.getCenter(finder));
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await gesture.removePointer();
    await tester.pumpAndSettle();
  }

  Future<void> pumpApp(
    WidgetTester tester,
    List<Worktree> worktrees, {
    AgentsController? agents,
  }) async {
    // A realistic window width; the default 800px test surface is below what
    // the desktop app ever runs at and overflows the fixed-width columns.
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WorkspaceController>.value(value: workspace),
          ChangeNotifierProvider<SettingsController>.value(value: settings),
          ChangeNotifierProvider<GithubPrsController>.value(value: prs),
          if (agents != null)
            ChangeNotifierProvider<AgentsController>.value(value: agents),
          ChangeNotifierProvider(
            create: (_) =>
                JiraTitlesController(cache: JiraIssueCache(testDatabase())),
          ),
          Provider.value(value: LauncherService()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const WorktreeListOptionsButton(),
                Expanded(child: WorktreeTable(worktrees: worktrees)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('selecting rows shows the bulk bar with a count', (tester) async {
    final worktrees = [_wt('main', isMain: true), _wt('one'), _wt('two')];
    await pumpApp(tester, worktrees);

    expect(find.text('Hide'), findsNothing);

    // Checkbox 0 is the header's select-all; 1..3 are the rows.
    await hoverAndTap(tester, _checkboxes().at(1));
    expect(find.text('1 selected'), findsOneWidget);

    await hoverAndTap(tester, _checkboxes().at(2));
    expect(find.text('2 selected'), findsOneWidget);

    // Header select-all picks up the remaining row.
    await hoverAndTap(tester, _checkboxes().at(0));
    expect(find.text('3 selected'), findsOneWidget);

    // Clear empties the selection and removes the bar.
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('Hide'), findsNothing);
  });

  testWidgets('delete is a no-op when only the primary worktree is selected', (
    tester,
  ) async {
    final worktrees = [_wt('main', isMain: true), _wt('one')];
    await pumpApp(tester, worktrees);

    await hoverAndTap(tester, _checkboxes().at(1)); // the primary row
    expect(find.text('1 selected'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Delete 1 worktrees?'), findsNothing);
  });

  testWidgets('selection is pruned when worktrees leave the table', (
    tester,
  ) async {
    final one = _wt('one');
    final two = _wt('two');
    await pumpApp(tester, [one, two]);

    await hoverAndTap(tester, _checkboxes().at(1));
    await hoverAndTap(tester, _checkboxes().at(2));
    expect(find.text('2 selected'), findsOneWidget);

    // Rebuild with one worktree gone — e.g. deleted or hidden elsewhere.
    await pumpApp(tester, [two]);
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);

    await pumpApp(tester, const []);
    await tester.pumpAndSettle();
    expect(find.text('Hide'), findsNothing);
  });

  testWidgets('bulk hide persists all selected paths in one update', (
    tester,
  ) async {
    final worktrees = [_wt('one'), _wt('two'), _wt('three')];
    await pumpApp(tester, worktrees);

    await hoverAndTap(tester, _checkboxes().at(0)); // select all via header
    expect(find.text('3 selected'), findsOneWidget);

    await tester.tap(find.text('Hide'));
    await tester.pumpAndSettle();

    for (final name in ['one', 'two', 'three']) {
      expect(workspace.metadataFor('/tmp/repo/$name')?.hidden, isTrue);
    }
    // Selection cleared even though the rows were not rebuilt away.
    expect(find.text('Hide'), findsNothing);
  });

  testWidgets(
    "a worktree lists the sessions in it, and archives a closed one",
    (tester) async {
      late AgentsController agents;
      // Made with real async, so their pending writes complete.
      await tester.runAsync(() async {
        await workspace.rememberClaudeSession('/tmp/repo', '/tmp/repo/one');
        agents = AgentsController(store: MemoryAgentRunStore());
        await agents.createForLaunch(
          kind: AgentKind.verify,
          repoName: workspace.selectedRepo!.name,
          title: 'Verify two',
          worktreePath: '/tmp/repo/two',
        );
      });
      addTearDown(agents.dispose);
      await pumpApp(tester, [
        _wt('main', isMain: true),
        _wt('one'),
        _wt('two'),
      ], agents: agents);
      await tester.pumpAndSettle();

      expect(find.byType(SessionsToggle), findsNWidgets(2));
      await tester.tap(find.byType(SessionsToggle).last);
      await tester.pumpAndSettle();
      expect(find.text('Verify two'), findsOneWidget);

      await tester.tap(find.byType(SessionsToggle).first);
      await tester.pumpAndSettle();
      expect(find.text('Closed'), findsOneWidget);

      await tester.tap(find.text('Closed'));
      await tester.pumpAndSettle();
      expect(find.text('Reopen'), findsOneWidget);
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();

      expect(workspace.metadata.sessionsFor('/tmp/repo'), isEmpty);
      expect(find.byType(SessionsToggle), findsOneWidget);
    },
  );

  testWidgets('two-line rows put the branch under the name', (tester) async {
    await pumpApp(tester, [
      Worktree(
        path: '/tmp/repo/one',
        branch: 'feature/one',
        name: 'one',
        isMain: false,
        commitHash: 'abc123',
        jiraIssue: 'AU2-1',
      ),
    ]);
    await tester.pumpAndSettle();

    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(find.text('BRANCH'), findsOneWidget);
    expect(
      top('feature/one'),
      lessThan(tester.getBottomLeft(find.text('one')).dy),
    );

    await tester.tap(find.byTooltip('View options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Two-line rows'));
    await tester.pumpAndSettle();
    expect(settings.settings.twoLineWorktreeRows, isTrue);

    // Fits a window too narrow for the one-line row.
    tester.view.physicalSize = const Size(800, 1000);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Only the worktree and actions are labelled; branch and issue go on the
    // second line.
    expect(find.text('BRANCH'), findsNothing);
    expect(find.text('WORKTREE'), findsOneWidget);
    final nameBottom = tester.getBottomLeft(find.text('one')).dy;
    expect(top('feature/one'), greaterThan(nameBottom));
    expect(top('AU2-1'), greaterThan(nameBottom));
  });
}
