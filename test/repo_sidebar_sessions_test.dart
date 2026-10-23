import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/app/use_cases/agent_launcher.dart';
import 'package:tree_launcher/features/activity/data/claude_session_activity.dart';
import 'package:tree_launcher/features/activity/data/worktree_event_store.dart';
import 'package:tree_launcher/features/agents/data/agent_run_store.dart';
import 'package:tree_launcher/features/agents/presentation/controllers/agents_controller.dart';
import 'package:tree_launcher/features/documents/data/document_store.dart';
import 'package:tree_launcher/features/documents/domain/session_document.dart';
import 'package:tree_launcher/features/documents/presentation/controllers/documents_controller.dart';
import 'package:tree_launcher/features/documents/presentation/widgets/document_badges.dart';
import 'package:tree_launcher/features/jira/data/jira_issue_cache.dart';
import 'package:tree_launcher/features/jira/presentation/controllers/jira_titles_controller.dart';
import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';
import 'package:tree_launcher/features/terminal/data/terminal_session.dart';
import 'package:tree_launcher/features/terminal/presentation/controllers/terminal_controller.dart';
import 'package:tree_launcher/features/workspace/data/git_service.dart';
import 'package:tree_launcher/features/agents/domain/agent_kind.dart';
import 'package:tree_launcher/features/agents/domain/agent_type.dart';
import 'package:tree_launcher/features/agents/domain/agent_run.dart';
import 'package:tree_launcher/features/agents/domain/claude_prompt.dart';
import 'package:tree_launcher/features/workspace/domain/repo_config.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_metadata.dart';
import 'package:tree_launcher/features/workspace/domain/worktree.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/repo_pages.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/repo_sidebar.dart';

import 'fake_config_stores.dart';
import 'test_database.dart';

class _FakeGitService extends GitService {
  @override
  Future<WorktreeListResult> getWorktrees(String repoPath) async {
    return WorktreeListResult(worktrees: const [], isBareLayout: false);
  }

  @override
  Future<bool> isGitRepo(String path) async => true;
}

/// Knows one title and never asks Jira.
class _FakeJiraTitles extends JiraTitlesController {
  _FakeJiraTitles() : super(cache: JiraIssueCache(testDatabase()));

  @override
  String? titleFor(String issueKey) =>
      issueKey == 'AU2-5788' ? 'Udlån sker til en kontakt' : null;

  @override
  Future<void> ensureTitles(Iterable<String> issueKeys) async {}
}

/// A terminal whose sessions are set by the test, without starting PTYs.
class _FakeTerminal extends TerminalController {
  final fakeSessions = <TerminalSession>[];

  @override
  List<TerminalSession> get sessions => fakeSessions;

  @override
  TerminalSession? claudeSessionFor(String workingDirectory) => fakeSessions
      .where((s) => s.isClaude && s.workingDirectory == workingDirectory)
      .firstOrNull;

  @override
  TerminalSession? claudeSessionForAgent(String agentId) =>
      fakeSessions.where((s) => s.agentId == agentId).firstOrNull;

  @override
  void closeAgentSession(String agentId) {
    fakeSessions.removeWhere((s) => s.agentId == agentId);
    notifyListeners();
  }

  void changed() => notifyListeners();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late WorkspaceController workspace;
  late SettingsController settings;
  late _FakeTerminal terminal;

  final tempDir = Directory.systemTemp.createTempSync('repo_sidebar_test');
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        pathProviderChannel,
        (call) async => tempDir.path,
      );

  const repoPath = '/tmp/repo';
  const withIssue = '/tmp/udlaan-sker-til-en-kontakt-au2-5788';
  const withoutIssue = '/tmp/spike';

  setUp(() async {
    workspace = WorkspaceController(
      gitService: _FakeGitService(),
      repoConfigStore: FakeRepoConfigStore(),
      eventStore: WorktreeEventStore(testDatabase()),
      metadataStore: MemoryWorktreeMetadataStore(),
    );
    settings = SettingsController(store: FakeAppSettingsStore());
    terminal = _FakeTerminal();
    await workspace.addRepo(repoPath);
    await workspace.rememberClaudeSession(repoPath, withIssue);
    await workspace.rememberClaudeSession(repoPath, withoutIssue);
    await workspace.updateJiraIssue(withIssue, 'AU2-5788');
  });

  tearDown(() {
    terminal.dispose();
    settings.dispose();
    workspace.dispose();
  });

  Future<void> pumpSidebar(
    WidgetTester tester, {
    AgentsController? agents,
    DocumentsController? documents,
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WorkspaceController>.value(value: workspace),
          ChangeNotifierProvider<SettingsController>.value(value: settings),
          ChangeNotifierProvider<TerminalController>.value(value: terminal),
          if (agents != null)
            ChangeNotifierProvider<AgentsController>.value(value: agents),
          if (documents != null)
            ChangeNotifierProvider<DocumentsController>.value(value: documents),
          ChangeNotifierProvider<JiraTitlesController>(
            create: (_) => _FakeJiraTitles(),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: RepoSidebar(onAddRepo: () {}, onOpenSettings: () {}),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('session names get two lines and a Jira badge below', (
    tester,
  ) async {
    await pumpSidebar(tester);

    final name = tester.widget<Text>(
      find.text('udlaan-sker-til-en-kontakt-au2-5788'),
    );
    expect(name.maxLines, 2);
    expect(find.text('AU2-5788'), findsOneWidget);
    expect(find.text('spike'), findsOneWidget);
    // Only the session whose worktree has an issue gets a badge.
    expect(find.textContaining('AU2-'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('AU2-5788')).dy,
      greaterThan(tester.getBottomLeft(find.byWidget(name)).dy),
    );
  });

  testWidgets("the Jira badge's tooltip shows the issue title", (tester) async {
    await pumpSidebar(tester);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.text('AU2-5788')));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('AU2-5788: Udlån sker til en kontakt'), findsOneWidget);
  });

  testWidgets('the selected repo lists its pages with sessions under them', (
    tester,
  ) async {
    await workspace.updateJiraProjectKey(workspace.selectedRepo!, 'AU2');
    await pumpSidebar(tester);

    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(find.text('Worktrees'), findsOneWidget);
    expect(find.text('Jira'), findsOneWidget);
    // Activity and Documents are only tabs above the repo.
    expect(find.text('Activity'), findsNothing);
    // The issue's session goes under Jira, the other under Worktrees.
    expect(top('spike'), greaterThan(top('Worktrees')));
    expect(top('spike'), lessThan(top('Jira')));
    expect(
      top('udlaan-sker-til-en-kontakt-au2-5788'),
      greaterThan(top('Jira')),
    );
  });

  testWidgets('an agent type switched off for the repo has no page', (
    tester,
  ) async {
    final agents = AgentsController(store: AgentRunStore(testDatabase()));
    addTearDown(agents.dispose);
    final repo = workspace.selectedRepo!;
    await workspace.updateRepoClaudePrompts(repo, [
      ClaudePrompt(name: 'Verify it', prompt: 'x', kind: AgentKind.verify),
    ]);
    await pumpSidebar(tester, agents: agents);
    expect(find.text('Verify'), findsOneWidget);

    await workspace.updateDisabledAgentTypes(workspace.selectedRepo!, [
      AgentKind.verify,
    ]);
    await tester.pump();
    expect(find.text('Verify'), findsNothing);
  });

  testWidgets('sessions under a page are newest first', (tester) async {
    await pumpSidebar(tester);

    // Both are under Worktrees (no Jira page); spike was started last.
    for (final path in [withIssue, withoutIssue]) {
      expect(workspace.metadataFor(path)?.session?.startedAt, isNotNull);
    }
    expect(
      tester.getTopLeft(find.text('spike')).dy,
      lessThan(
        tester.getTopLeft(find.text('udlaan-sker-til-en-kontakt-au2-5788')).dy,
      ),
    );
  });

  testWidgets('right-clicking a session offers to remove its shortcut', (
    tester,
  ) async {
    await pumpSidebar(tester);

    await tester.tap(find.text('spike'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    expect(find.text('Show'), findsOneWidget);
    // Not running, so there is nothing to stop.
    expect(find.text('Stop session'), findsNothing);

    await tester.tap(find.text('Remove shortcut'));
    await tester.pumpAndSettle();

    expect(
      [for (final m in workspace.metadata.sessionsFor(repoPath)) m.path],
      [withIssue],
    );
  });

  testWidgets("a session counts its issue's documents and lists them", (
    tester,
  ) async {
    late DocumentsController documents;
    await tester.runAsync(() async {
      documents = DocumentsController(
        store: DocumentStore(
          testDatabase(),
          directory: () async => '${tempDir.path}/documents',
        ),
      );
      await documents.save(
        DocumentDetails(
          repoName: workspace.selectedRepo!.name,
          title: 'Afklaring: udlån',
          issueKeys: ['AU2-5788'],
        ),
        DocumentFormat.markdown,
        utf8.encode('# Afklaring'),
      );
    });
    addTearDown(documents.dispose);
    await pumpSidebar(tester, documents: documents);

    // Under the session with the issue, not under the one without.
    expect(find.byType(DocumentsBadge), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(DocumentsBadge),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.text('udlaan-sker-til-en-kontakt-au2-5788'),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    expect(find.text('Afklaring: udlån'), findsOneWidget);
  });

  testWidgets("a build agent stands for its worktree's shortcut while listed", (
    tester,
  ) async {
    late AgentsController agents;
    // Made with real async, so its pending writes complete.
    await tester.runAsync(() async {
      agents = AgentsController(store: AgentRunStore(testDatabase()));
      final run = await agents.createForLaunch(
        kind: AgentKind.build,
        repoName: workspace.selectedRepo!.name,
        title: 'Factory: udlån',
        worktreePath: withIssue,
      );
      await agents.report(run.id, const AgentReport(state: AgentState.done));
      await agents.flush();
      terminal.fakeSessions.add(
        TerminalSession(
          title: 'Claude',
          workingDirectory: withIssue,
          repoPath: repoPath,
          isClaude: true,
          agentId: run.id,
        ),
      );
    });
    addTearDown(agents.dispose);
    await pumpSidebar(tester, agents: agents);

    // Done, but its terminal is still open: listed once, as the agent.
    expect(find.text('Factory: udlån'), findsOneWidget);
    expect(find.text('udlaan-sker-til-en-kontakt-au2-5788'), findsNothing);

    // Once its terminal is closed, the shortcut takes its place.
    terminal.fakeSessions.clear();
    terminal.changed();
    await tester.pump();
    expect(find.text('Factory: udlån'), findsNothing);
    expect(find.text('udlaan-sker-til-en-kontakt-au2-5788'), findsOneWidget);
  });

  test("stopping a build agent drops its worktree's shortcut too", () async {
    final agents = AgentsController(store: AgentRunStore(testDatabase()));
    addTearDown(agents.dispose);
    final launcher = AgentLauncher(
      terminal: terminal,
      agents: agents,
      workspace: workspace,
      settings: settings,
      claudeActivity: ClaudeSessionActivity(),
    );
    final run = await agents.createForLaunch(
      kind: AgentKind.build,
      repoName: workspace.selectedRepo!.name,
      worktreePath: withIssue,
    );
    terminal.fakeSessions.add(
      TerminalSession(
        title: 'Claude',
        workingDirectory: withIssue,
        repoPath: repoPath,
        isClaude: true,
        agentId: run.id,
      ),
    );

    await launcher.stop(run);

    expect(agents.runById(run.id)!.state, AgentState.stopped);
    expect(terminal.fakeSessions, isEmpty);
    expect(
      [for (final m in workspace.metadata.sessionsFor(repoPath)) m.path],
      [withoutIssue],
    );
  });

  test('stopping a verify agent leaves the shortcut in its checkout', () async {
    final agents = AgentsController(store: AgentRunStore(testDatabase()));
    addTearDown(agents.dispose);
    final launcher = AgentLauncher(
      terminal: terminal,
      agents: agents,
      workspace: workspace,
      settings: settings,
      claudeActivity: ClaudeSessionActivity(),
    );
    final run = await agents.createForLaunch(
      kind: AgentKind.verify,
      repoName: workspace.selectedRepo!.name,
      worktreePath: withIssue,
    );

    await launcher.stop(run);

    expect(
      [for (final m in workspace.metadata.sessionsFor(repoPath)) m.path],
      [withIssue, withoutIssue],
    );
  });

  testWidgets('tapping a page shows it', (tester) async {
    await workspace.updateJiraProjectKey(workspace.selectedRepo!, 'AU2');
    await pumpSidebar(tester);
    expect(workspace.repoPageKey, worktreesPageKey);

    await tester.tap(find.text('Jira'));
    await tester.pump();

    expect(workspace.repoPageKey, jiraPageKey);
  });

  group('sessionPageKey', () {
    final repo = RepoConfig(
      name: 'r',
      path: '/r',
      claudePrompts: [
        ClaudePrompt(name: 'Implement', prompt: 'Implement {issue}'),
        ClaudePrompt(
          name: 'Verify',
          prompt: 'Verify {issue}',
          kind: AgentKind.verify,
        ),
      ],
    );
    const byPath = {
      '/w/pr': WorktreeMetadata(
        path: '/w/pr',
        repoPath: '/r',
        prAuthor: 'kim',
        jiraIssue: 'AU2-1',
        session: RememberedSession(promptId: issueContextPromptId),
      ),
      '/w/issue': WorktreeMetadata(
        path: '/w/issue',
        repoPath: '/r',
        jiraIssue: 'AU2-2',
        session: RememberedSession(promptId: 'Implement'),
      ),
      '/w/verified': WorktreeMetadata(
        path: '/w/verified',
        repoPath: '/r',
        session: RememberedSession(promptId: 'Verify'),
      ),
      '/w/from-pr-tab': WorktreeMetadata(
        path: '/w/from-pr-tab',
        repoPath: '/r',
        session: RememberedSession(promptId: prContextPromptId),
      ),
    };

    /// The worktree at [path]: one of [byPath], or one with nothing known.
    WorktreeMetadata at(String path) =>
        byPath[path] ?? WorktreeMetadata(path: path, repoPath: '/r');
    final all = {
      worktreesPageKey,
      prsPageKey,
      jiraPageKey,
      agentPageKey(AgentKind.verify),
      agentPageKey(AgentKind.review),
    };
    final t0 = DateTime(2026, 10, 1);
    AgentRun run(String id, AgentKind kind, String path, DateTime at) =>
        AgentRun(
          id: id,
          kind: kind,
          repoName: 'r',
          worktreePath: path,
          startedAt: at,
          updatedAt: at,
        );

    test('goes by the prompt it was started with first', () {
      expect(
        sessionPageKey(repo, at('/w/verified'), all),
        agentPageKey(AgentKind.verify),
      );
      expect(sessionPageKey(repo, at('/w/from-pr-tab'), all), prsPageKey);
      // The issue context wins over the worktree being a PR's.
      expect(sessionPageKey(repo, at('/w/pr'), all), jiraPageKey);
    });

    test('then by the newest agent in the worktree', () {
      final runs = [
        run('a', AgentKind.verify, '/w/other', t0),
        run(
          'b',
          AgentKind.review,
          '/w/other',
          t0.add(const Duration(hours: 1)),
        ),
      ];
      expect(
        sessionPageKey(repo, at('/w/other'), all, runs: runs),
        agentPageKey(AgentKind.review),
      );
      // A prompt without a kind says nothing; the agent decides.
      expect(
        sessionPageKey(
          repo,
          at('/w/issue'),
          all,
          runs: [run('c', AgentKind.verify, '/w/issue', t0)],
        ),
        agentPageKey(AgentKind.verify),
      );
    });

    test('puts GitHub issue sessions and worktrees under Issues', () {
      const gh = WorktreeMetadata(
        path: '/w/gh',
        repoPath: '/r',
        githubIssue: 482,
      );
      const ghPrompt = WorktreeMetadata(
        path: '/w/gh-prompt',
        repoPath: '/r',
        session: RememberedSession(promptId: githubIssueContextPromptId),
      );
      final issue = at('/w/issue').copyWith(githubIssue: 7);
      final pages = {...all, githubIssuesPageKey};
      expect(sessionPageKey(repo, ghPrompt, pages), githubIssuesPageKey);
      expect(sessionPageKey(repo, gh, pages), githubIssuesPageKey);
      // A Jira issue goes first.
      expect(sessionPageKey(repo, issue, pages), jiraPageKey);
      // Without the Issues page, the worktrees page.
      expect(sessionPageKey(repo, gh, all), worktreesPageKey);
    });

    test('then by where the worktree came from', () {
      expect(sessionPageKey(repo, at('/w/issue'), all), jiraPageKey);
      expect(sessionPageKey(repo, at('/w/other'), all), worktreesPageKey);
      // Without a page for it, the next rule decides.
      expect(
        sessionPageKey(repo, at('/w/verified'), {worktreesPageKey}),
        worktreesPageKey,
      );
      expect(
        sessionPageKey(repo, at('/w/pr'), {worktreesPageKey, prsPageKey}),
        prsPageKey,
      );
    });
  });

  group('sessionsByPage', () {
    final repo = RepoConfig(name: 'r', path: '/r');
    final pages = {worktreesPageKey, agentPageKey(AgentKind.build)};
    WorktreeMetadata remembered(String path, [DateTime? at]) =>
        WorktreeMetadata(
          path: path,
          repoPath: '/r',
          session: RememberedSession(startedAt: at),
        );
    AgentRun build(String id, AgentState state) => AgentRun(
      id: id,
      kind: AgentKind.build,
      repoName: 'r',
      worktreePath: '/w/a',
      state: state,
      startedAt: DateTime(2026, 10, 19, 12),
      updatedAt: DateTime(2026, 10, 19, 12),
    );

    test('a listed build agent stands for its worktree\'s shortcut', () {
      final sessions = sessionsByPage(
        repo,
        agentTypes: defaultAgentTypes,
        pageKeys: pages,
        runs: [build('a1', AgentState.running)],
        isOpen: (_) => false,
        remembered: [
          remembered('/w/a', DateTime(2026, 10, 19, 9)),
          remembered('/w/old'),
          remembered('/w/b', DateTime(2026, 10, 19, 10)),
        ],
      );

      expect(
        [for (final s in sessions[agentPageKey(AgentKind.build)]!) s.run?.id],
        ['a1'],
      );
      // Newest first; shortcuts from before start times last.
      expect(
        [for (final s in sessions[worktreesPageKey]!) s.path],
        ['/w/b', '/w/old'],
      );
    });

    test(
      'a finished agent with its terminal closed gives the shortcut back',
      () {
        final sessions = sessionsByPage(
          repo,
          agentTypes: defaultAgentTypes,
          pageKeys: pages,
          runs: [build('a1', AgentState.done)],
          isOpen: (_) => false,
          remembered: [remembered('/w/a', DateTime(2026, 10, 19, 9))],
        );

        // Under the agent's page still (the newest agent in the worktree), but
        // as the shortcut rather than the run.
        final listed = sessions[agentPageKey(AgentKind.build)]!.single;
        expect(listed.run, isNull);
        expect(listed.path, '/w/a');
      },
    );
  });

  group('sessionsForIssue', () {
    final repo = RepoConfig(name: 'r', path: '/r');
    WorktreeMetadata worktree(String path, String? issue, [DateTime? at]) =>
        WorktreeMetadata(
          path: path,
          repoPath: '/r',
          jiraIssue: issue,
          session: at == null ? null : RememberedSession(startedAt: at),
        );
    AgentRun run(
      String id, {
      AgentKind kind = AgentKind.refine,
      List<String> issueKeys = const [],
      String? worktreePath,
      String repoName = 'r',
      bool archived = false,
      int hour = 12,
    }) => AgentRun(
      id: id,
      kind: kind,
      repoName: repoName,
      issueKeys: issueKeys,
      worktreePath: worktreePath,
      state: AgentState.done,
      archived: archived,
      startedAt: DateTime(2026, 10, 19, hour),
      updatedAt: DateTime(2026, 10, 19, hour),
    );

    test(
      "lists the issue's runs and its worktrees' sessions, newest first",
      () {
        final sessions = sessionsForIssue(
          repo,
          'AU2-1',
          agentTypes: defaultAgentTypes,
          runs: [
            run('by-key', issueKeys: ['AU2-1'], hour: 9),
            run('in-worktree', worktreePath: '/w/a', hour: 11),
            run('other-issue', issueKeys: ['AU2-2']),
            run('archived', issueKeys: ['AU2-1'], archived: true),
            run('other-repo', issueKeys: ['AU2-1'], repoName: 'x'),
          ],
          worktrees: [
            worktree('/w/a', 'AU2-1', DateTime(2026, 10, 19, 10)),
            worktree('/w/b', 'AU2-2', DateTime(2026, 10, 19, 10)),
            worktree('/w/c', 'AU2-1'),
          ],
        );

        expect(
          [for (final s in sessions) s.run?.id ?? s.path],
          ['in-worktree', '/w/a', 'by-key'],
        );
      },
    );

    test("a build agent stands for its worktree's session", () {
      final sessions = sessionsForIssue(
        repo,
        'AU2-1',
        agentTypes: defaultAgentTypes,
        runs: [run('b1', kind: AgentKind.build, worktreePath: '/w/a')],
        worktrees: [worktree('/w/a', 'AU2-1', DateTime(2026, 10, 19, 10))],
      );

      expect([for (final s in sessions) s.run?.id], ['b1']);
    });
  });
}
