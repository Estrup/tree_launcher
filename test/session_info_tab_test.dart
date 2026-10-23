import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/features/activity/data/worktree_event_store.dart';
import 'package:tree_launcher/features/agents/data/agent_run_store.dart';
import 'package:tree_launcher/features/agents/domain/agent_kind.dart';
import 'package:tree_launcher/features/agents/presentation/controllers/agents_controller.dart';
import 'package:tree_launcher/features/github_prs/domain/pull_request.dart';
import 'package:tree_launcher/features/github_prs/presentation/controllers/github_prs_controller.dart';
import 'package:tree_launcher/features/session_panel/presentation/controllers/session_panel_controller.dart';
import 'package:tree_launcher/features/session_panel/presentation/widgets/session_info_tab.dart';
import 'package:tree_launcher/features/terminal/data/terminal_session.dart';
import 'package:tree_launcher/features/workspace/data/git_service.dart';
import 'package:tree_launcher/features/workspace/domain/worktree.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_status.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';

import 'fake_config_stores.dart';
import 'test_database.dart';

class _FakeGitService extends GitService {
  String? askedBase;

  @override
  Future<WorktreeListResult> getWorktrees(String repoPath) async =>
      WorktreeListResult(worktrees: const [], isBareLayout: false);

  @override
  Future<bool> isGitRepo(String path) async => true;

  @override
  Future<WorktreeStatus> worktreeStatus(
    String worktreePath, {
    String? baseBranch,
  }) async {
    askedBase = baseBranch;
    return WorktreeStatus(
      branch: 'feature/au2-1',
      commit: '0123456789abcdef',
      subject: 'Fix the thing',
      upstream: 'origin/feature/au2-1',
      aheadOfUpstream: 1,
      modified: 2,
      base: 'origin/$baseBranch',
      aheadOfBase: 3,
      behindBase: 0,
    );
  }
}

/// Serves fixed pull requests instead of calling GitHub.
class _FakePrs extends GithubPrsController {
  @override
  List<GithubPullRequest> get pullRequests => [
    GithubPullRequest(
      number: 7,
      title: 'Branch PR',
      htmlUrl: 'https://github.com/o/r/pull/7',
      createdAt: DateTime(2026, 10, 1),
      author: 'kim',
      headBranch: 'feature/au2-1',
      baseBranch: 'develop',
    ),
    GithubPullRequest(
      number: 42,
      title: 'Fix konto (AU2-6001)',
      htmlUrl: 'https://github.com/o/r/pull/42',
      createdAt: DateTime(2026, 10, 2),
      author: 'jane',
      headBranch: 'feature/au2-6001-fix-konto',
      baseBranch: 'develop',
    ),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tempDir = Directory.systemTemp.createTempSync('session_info_test');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => tempDir.path,
      );

  late _FakeGitService git;
  late WorkspaceController workspace;
  late SessionPanelController panel;

  setUp(() async {
    git = _FakeGitService();
    workspace = WorkspaceController(
      gitService: git,
      repoConfigStore: FakeRepoConfigStore(),
      eventStore: WorktreeEventStore(testDatabase()),
      metadataStore: MemoryWorktreeMetadataStore(),
    );
    panel = SessionPanelController(git: git);
    await workspace.addRepo('/tmp/repo');
    await workspace.updateJiraIssue('/tmp/repo-au2-1', 'AU2-1');
    await workspace.metadata.update(
      '/tmp/repo',
      '/tmp/repo-au2-1',
      (m) => m.copyWith(baseBranch: 'develop'),
    );
  });

  tearDown(() {
    panel.dispose();
    workspace.dispose();
  });

  Future<void> pump(
    WidgetTester tester,
    String worktree, {
    AgentsController? agents,
    String? agentId,
    GithubPrsController? prs,
  }) => tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: workspace),
        ChangeNotifierProvider.value(value: panel),
        if (agents != null)
          ChangeNotifierProvider<AgentsController>.value(value: agents),
        if (prs != null)
          ChangeNotifierProvider<GithubPrsController>.value(value: prs),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SessionInfoTab(
            session: TerminalSession(
              title: 'Claude',
              workingDirectory: worktree,
              repoPath: '/tmp/repo',
              isClaude: true,
              agentId: agentId,
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets("shows the worktree's branch, base, changes and issue", (
    tester,
  ) async {
    await pump(tester, '/tmp/repo-au2-1');
    await tester.pump();
    await tester.pump();

    expect(git.askedBase, 'develop');
    expect(find.text('feature/au2-1'), findsOneWidget);
    expect(
      find.text('3 commits ahead · 0 commits behind origin/develop'),
      findsOneWidget,
    );
    expect(find.text('1 commit to push'), findsOneWidget);
    expect(find.text('2 modified'), findsOneWidget);
    expect(find.text('AU2-1'), findsOneWidget);

    // Stop the refresh timer.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reads the status again for another session', (tester) async {
    await pump(tester, '/tmp/repo-au2-1');
    await tester.pump();
    await tester.pump();

    await pump(tester, '/tmp/repo-au2-2');
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(panel.statusFor('/tmp/repo-au2-2')?.branch, 'feature/au2-1');
    // The second worktree has no base branch.
    expect(git.askedBase, isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'an agent in a shared checkout shows the PR and issue it was started on',
    (tester) async {
      late AgentsController agents;
      late String runId;
      await tester.runAsync(() async {
        agents = AgentsController(store: AgentRunStore(testDatabase()));
        final run = await agents.createForLaunch(
          kind: AgentKind.review,
          repoName: workspace.selectedRepo!.name,
          issueKeys: ['AU2-6001'],
          worktreePath: '/tmp/repo-au2-1',
          prNumber: 42,
        );
        runId = run.id;
        await agents.flush();
      });
      addTearDown(agents.dispose);
      final prs = _FakePrs();
      addTearDown(prs.dispose);

      // The checkout is on another PR's branch, and has another issue.
      await pump(
        tester,
        '/tmp/repo-au2-1',
        agents: agents,
        agentId: runId,
        prs: prs,
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('#42'), findsOneWidget);
      expect(find.text('Fix konto (AU2-6001)'), findsOneWidget);
      expect(find.text('#7'), findsNothing);
      expect(find.text('AU2-6001'), findsOneWidget);
      expect(find.text('AU2-1'), findsNothing);

      await tester.pumpWidget(const SizedBox());
    },
  );
}
