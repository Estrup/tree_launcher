import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/features/activity/data/worktree_event_store.dart';
import 'package:tree_launcher/features/jira/data/jira_issue_cache.dart';
import 'package:tree_launcher/features/jira/presentation/controllers/jira_titles_controller.dart';
import 'package:tree_launcher/features/settings/domain/app_settings.dart';
import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';
import 'package:tree_launcher/features/terminal/presentation/controllers/terminal_controller.dart';
import 'package:tree_launcher/features/workspace/data/git_service.dart';
import 'package:tree_launcher/features/agents/domain/agent_kind.dart';
import 'package:tree_launcher/features/agents/domain/agent_run.dart';
import 'package:tree_launcher/features/workspace/domain/claude_prompt.dart';
import 'package:tree_launcher/features/workspace/domain/repo_config.dart';
import 'package:tree_launcher/features/workspace/domain/worktree.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/repo_pages.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/repo_sidebar.dart';
import 'package:tree_launcher/services/config_service.dart';

class _FakeConfigService extends ConfigService {
  List<RepoConfig> savedRepos = const [];

  @override
  Future<List<RepoConfig>> loadRepos() async => savedRepos;

  @override
  Future<void> saveRepos(List<RepoConfig> repos) async {
    savedRepos = List<RepoConfig>.from(repos);
  }

  @override
  Future<AppSettings> loadSettings() async => AppSettings();

  @override
  Future<void> saveSettings(AppSettings settings) async {}
}

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
  _FakeJiraTitles(String cacheDir)
    : super(cache: JiraIssueCache(directoryPath: cacheDir));

  @override
  String? titleFor(String issueKey) =>
      issueKey == 'AU2-5788' ? 'Udlån sker til en kontakt' : null;

  @override
  Future<void> ensureTitles(Iterable<String> issueKeys) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late WorkspaceController workspace;
  late SettingsController settings;
  late TerminalController terminal;

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
    final configService = _FakeConfigService();
    workspace = WorkspaceController(
      gitService: _FakeGitService(),
      configService: configService,
      eventStore: WorktreeEventStore(directoryPath: tempDir.path),
    );
    settings = SettingsController(configService: configService);
    terminal = TerminalController();
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

  Future<void> pumpSidebar(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WorkspaceController>.value(value: workspace),
          ChangeNotifierProvider<SettingsController>.value(value: settings),
          ChangeNotifierProvider<TerminalController>.value(value: terminal),
          ChangeNotifierProvider<JiraTitlesController>(
            create: (_) => _FakeJiraTitles(tempDir.path),
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
    expect(find.text('Activity'), findsOneWidget);
    // The issue's session goes under Jira, the other under Worktrees.
    expect(top('spike'), greaterThan(top('Worktrees')));
    expect(top('spike'), lessThan(top('Jira')));
    final issueSession = top('udlaan-sker-til-en-kontakt-au2-5788');
    expect(issueSession, greaterThan(top('Jira')));
    expect(issueSession, lessThan(top('Activity')));
  });

  testWidgets('sessions under a page are newest first', (tester) async {
    await pumpSidebar(tester);

    // Both are under Worktrees (no Jira page); spike was started last.
    expect(
      workspace.selectedRepo!.claudeSessionStarts.keys,
      containsAll([withIssue, withoutIssue]),
    );
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

    expect(workspace.selectedRepo!.claudeSessions, [withIssue]);
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
      prAuthors: const {'/w/pr': 'kim'},
      jiraIssues: const {'/w/pr': 'AU2-1', '/w/issue': 'AU2-2'},
      claudeSessionPrompts: const {
        '/w/verified': 'Verify',
        '/w/from-pr-tab': prContextPromptId,
        '/w/issue': 'Implement',
        '/w/pr': issueContextPromptId,
      },
    );
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
        sessionPageKey(repo, '/w/verified', all),
        agentPageKey(AgentKind.verify),
      );
      expect(sessionPageKey(repo, '/w/from-pr-tab', all), prsPageKey);
      // The issue context wins over the worktree being a PR's.
      expect(sessionPageKey(repo, '/w/pr', all), jiraPageKey);
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
        sessionPageKey(repo, '/w/other', all, runs: runs),
        agentPageKey(AgentKind.review),
      );
      // A prompt without a kind says nothing; the agent decides.
      expect(
        sessionPageKey(
          repo,
          '/w/issue',
          all,
          runs: [run('c', AgentKind.verify, '/w/issue', t0)],
        ),
        agentPageKey(AgentKind.verify),
      );
    });

    test('then by where the worktree came from', () {
      expect(sessionPageKey(repo, '/w/issue', all), jiraPageKey);
      expect(sessionPageKey(repo, '/w/other', all), worktreesPageKey);
      // Without a page for it, the next rule decides.
      expect(
        sessionPageKey(repo, '/w/verified', {worktreesPageKey}),
        worktreesPageKey,
      );
      expect(
        sessionPageKey(repo, '/w/pr', {worktreesPageKey, prsPageKey}),
        prsPageKey,
      );
    });
  });
}
