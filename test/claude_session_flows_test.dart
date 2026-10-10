import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/activity/data/worktree_event_store.dart';
import 'package:tree_launcher/features/github_prs/domain/github_config.dart';
import 'package:tree_launcher/features/github_prs/domain/pull_request.dart';
import 'package:tree_launcher/features/github_prs/presentation/controllers/github_prs_controller.dart';
import 'package:tree_launcher/features/github_prs/presentation/widgets/github_prs_tab.dart';
import 'package:tree_launcher/features/jira/data/jira_api_service.dart';
import 'package:tree_launcher/features/jira/domain/jira_issue.dart';
import 'package:tree_launcher/features/jira/domain/jira_user.dart';
import 'package:tree_launcher/features/jira/domain/jira_version.dart';
import 'package:tree_launcher/features/jira/presentation/controllers/jira_issues_controller.dart';
import 'package:tree_launcher/features/jira/presentation/widgets/jira_issues_tab.dart';
import 'package:tree_launcher/features/settings/domain/app_settings.dart';
import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';
import 'package:tree_launcher/features/terminal/presentation/controllers/terminal_controller.dart';
import 'package:tree_launcher/features/workspace/data/git_service.dart';
import 'package:tree_launcher/features/workspace/domain/claude_prompt.dart';
import 'package:tree_launcher/features/workspace/domain/repo_config.dart';
import 'package:tree_launcher/features/workspace/domain/worktree.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_naming.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/repo_sidebar.dart';
import 'package:tree_launcher/services/config_service.dart';

const _discordArgs = '--channels plugin:discord@claude-plugins-official';

/// Flags for the dialog's default model and effort.
const _launchFlags = '--model opus --effort high';
const _repoPath = '/tmp/au2';
const _existingPath = '/tmp/au2-wt';
const _existingBranch = 'feature/vaerksted-kontakt-au2-5928';

class _FakeJiraService extends JiraApiService {
  @override
  Future<JiraUser> fetchMyself() async =>
      const JiraUser(name: 'me', displayName: 'Me Myself');

  @override
  Future<List<JiraVersion>> fetchVersions(String projectKey) async => const [
    JiraVersion(id: '29501', name: 'au2office 2.41.3'),
  ];

  @override
  Future<List<JiraIssue>> searchIssues(String jql) async => const [
    JiraIssue(
      key: 'AU2-5928',
      summary: 'Værksted kontakt',
      status: 'Review',
      statusCategory: 'indeterminate',
      issueType: 'Story',
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

class _FakeConfigService extends ConfigService {
  _FakeConfigService(this.savedRepos);

  List<RepoConfig> savedRepos;

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

  @override
  Future<String?> loadLastSelectedRepoPath() async => null;

  @override
  Future<void> saveLastSelectedRepoPath(String? path) async {}
}

class _FakeGitService extends GitService {
  final created = <String>[];
  final createdFrom = <({String? baseBranch, String? newBranch})>[];

  @override
  Future<WorktreeListResult> getWorktrees(String repoPath) async =>
      WorktreeListResult(
        worktrees: [
          Worktree(
            path: _existingPath,
            branch: _existingBranch,
            name: 'au2-wt',
            isMain: false,
            commitHash: 'abc123',
          ),
          for (final path in created)
            Worktree(
              path: path,
              branch: 'feature/new',
              name: path.split('/').last,
              isMain: false,
              commitHash: 'def456',
            ),
        ],
        isBareLayout: false,
      );

  @override
  Future<List<String>> listBranches(String repoPath) async => const ['develop'];

  @override
  Future<String> addWorktree(
    String repoPath,
    String name, {
    String? baseBranch,
    String? newBranch,
    bool useNestedWorktrees = false,
  }) async {
    final path = '/tmp/$name';
    created.add(path);
    createdFrom.add((baseBranch: baseBranch, newBranch: newBranch));
    return path;
  }
}

/// Serves fixed pull requests instead of calling GitHub.
class _FakePrs extends GithubPrsController {
  @override
  List<GithubPullRequest> get pullRequests => [
    GithubPullRequest(
      number: 7,
      title: 'Værksted kontakt (AU2-5928)',
      htmlUrl: 'https://github.com/o/r/pull/7',
      createdAt: DateTime(2026, 10, 1),
      author: 'kim',
      headBranch: _existingBranch,
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

/// Records Claude launches instead of spawning a shell.
class _RecordingTerminal extends TerminalController {
  final launched = <({String dir, String repo, String command})>[];
  final running = <String>{};
  final focused = <String>[];

  @override
  void openClaudeSession(
    String title,
    String workingDirectory,
    String repoPath,
    String command,
  ) {
    launched.add((dir: workingDirectory, repo: repoPath, command: command));
  }

  @override
  bool focusClaudeSession(String workingDirectory) {
    if (!running.contains(workingDirectory)) return false;
    focused.add(workingDirectory);
    return true;
  }
}

void main() {
  final tempDir = Directory.systemTemp.createTempSync('jira_claude_test');
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => tempDir.path,
      );

  late _FakeConfigService config;
  late WorkspaceController workspace;
  late SettingsController settings;
  late JiraIssuesController jira;
  late _FakePrs prs;
  late _RecordingTerminal terminal;
  late _FakeGitService git;

  setUp(() async {
    config = _FakeConfigService([
      RepoConfig(
        name: 'au2office',
        path: _repoPath,
        jiraProjectKey: 'AU2',
        githubConfig: GithubConfig(owner: 'o', repo: 'r', token: 't'),
        jiraIssues: const {_existingPath: 'AU2-5928'},
        baseBranches: const {_existingPath: 'develop'},
        claudePrompts: [
          ClaudePrompt(
            name: 'Implement',
            prompt: 'Implement {issue} in {worktree}',
          ),
        ],
      ),
    ]);
    git = _FakeGitService();
    workspace = WorkspaceController(
      gitService: git,
      configService: config,
      eventStore: WorktreeEventStore(directoryPath: tempDir.path),
    );
    settings = SettingsController(configService: config);
    terminal = _RecordingTerminal();
    jira = JiraIssuesController(service: _FakeJiraService());
    prs = _FakePrs();
    await workspace.loadRepos();
  });

  tearDown(() {
    prs.dispose();
    jira.dispose();
    terminal.dispose();
    settings.dispose();
    workspace.dispose();
  });

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Inside the test zone so the issue fetch completes under fake async.
    jira.syncToRepo(workspace.selectedRepo);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WorkspaceController>.value(value: workspace),
          ChangeNotifierProvider<SettingsController>.value(value: settings),
          ChangeNotifierProvider<JiraIssuesController>.value(value: jira),
          ChangeNotifierProvider<GithubPrsController>.value(value: prs),
          ChangeNotifierProvider<TerminalController>.value(value: terminal),
        ],
        child: MaterialApp(
          theme: AppTheme.current,
          home: Scaffold(body: child),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('reuses the issue worktree and starts Claude with the picked '
      'prompt', (tester) async {
    await pump(tester, const JiraIssuesTab());

    await tester.tap(find.byTooltip('Claude session for AU2-5928…'));
    await tester.pumpAndSettle();

    expect(find.text('Start Claude Session'), findsOneWidget);
    expect(find.text('WORKTREE NAME'), findsNothing);
    expect(find.text('au2-wt'), findsOneWidget);
    expect(
      find.text(
        'Runs claude $_discordArgs $_launchFlags in the built-in terminal.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Implement'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    expect(find.text('Start Claude Session'), findsNothing);
    expect(terminal.launched.single.dir, _existingPath);
    expect(terminal.launched.single.repo, _repoPath);
    expect(
      terminal.launched.single.command,
      "claude $_discordArgs $_launchFlags -- 'Implement AU2-5928 in au2-wt'",
    );
    expect(workspace.selectedRepo!.claudeSessions, [_existingPath]);
  });

  testWidgets('creates a worktree for an issue without one', (tester) async {
    await pump(tester, const JiraIssuesTab());

    await tester.tap(find.byTooltip('Claude session for AU2-5905…'));
    await tester.pumpAndSettle();

    expect(find.text('Start Claude Session'), findsOneWidget);
    expect(find.text('WORKTREE NAME'), findsOneWidget);
    expect(find.text('CLAUDE PROMPT'), findsOneWidget);

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    const created = '/tmp/arbejdskort-vaelger-forkert-konto-au2-5905';
    expect(terminal.launched.single.dir, created);
    expect(
      terminal.launched.single.command,
      "claude $_discordArgs $_launchFlags -- 'Context: Working on issue AU2-5905 where the "
      "base branch is develop.'",
    );
    expect(workspace.selectedRepo!.jiraIssues[created], 'AU2-5905');
    expect(workspace.selectedRepo!.claudeSessions, [created]);
  });

  testWidgets('starts on the picked model and effort and remembers them', (
    tester,
  ) async {
    await pump(tester, const JiraIssuesTab());

    await tester.tap(find.byTooltip('Claude session for AU2-5928…'));
    await tester.pumpAndSettle();

    expect(find.text('MODEL'), findsOneWidget);
    expect(find.text('Default'), findsNothing);
    expect(find.text('Haiku'), findsNothing);
    expect(find.text('EFFORT'), findsOneWidget);
    await tester.tap(find.text('Fable'));
    await tester.tap(find.text('Max'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Runs claude $_discordArgs --model fable --effort max in the '
        'built-in terminal.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    expect(
      terminal.launched.single.command,
      "claude $_discordArgs --model fable --effort max -- 'Context: Working "
      "on issue AU2-5928 where the base branch is develop.'",
    );
    expect(settings.settings.claudeModel, 'fable');
    expect(settings.settings.claudeEffort, 'max');
  });

  testWidgets('turning the active prompt toggle off starts without a prompt', (
    tester,
  ) async {
    await pump(tester, const JiraIssuesTab());

    await tester.tap(find.byTooltip('Claude session for AU2-5928…'));
    await tester.pumpAndSettle();

    // Picking another prompt switches the single active toggle to it...
    await tester.tap(find.text('Implement'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

    // ...and tapping the active one turns it off, leaving none active.
    await tester.tap(find.text('Implement'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
    expect(
      find.text('No prompt — Claude starts without a first message.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    expect(
      terminal.launched.single.command,
      'claude $_discordArgs $_launchFlags',
    );
  });

  testWidgets('shows the running session instead of asking again', (
    tester,
  ) async {
    terminal.running.add(_existingPath);
    await pump(tester, const JiraIssuesTab());

    await tester.tap(find.byTooltip('Claude session for AU2-5928…'));
    await tester.pumpAndSettle();

    expect(find.text('Start Claude Session'), findsNothing);
    expect(terminal.focused, [_existingPath]);
    expect(terminal.launched, isEmpty);
  });

  testWidgets('lists remembered sessions under the repo and removes them', (
    tester,
  ) async {
    await workspace.rememberClaudeSession(_repoPath, _existingPath);
    await pump(tester, RepoSidebar(onAddRepo: () {}, onOpenSettings: () {}));

    final shortcut = find.text('au2-wt');
    expect(shortcut, findsOneWidget);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    await gesture.moveTo(tester.getCenter(shortcut));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove shortcut'));
    await gesture.removePointer();
    await tester.pumpAndSettle();

    expect(find.text('au2-wt'), findsNothing);
    expect(config.savedRepos.single.claudeSessions, isEmpty);
  });

  testWidgets('starts Claude on a PR branch with the PR context', (
    tester,
  ) async {
    await pump(tester, const GithubPrsTab());

    await tester.tap(find.byTooltip('Claude session for #42…'));
    await tester.pumpAndSettle();

    // Checks out the PR's own branch rather than branching off it.
    expect(find.text('Start Claude Session'), findsOneWidget);
    expect(find.text('feature/au2-6001-fix-konto'), findsWidgets);
    expect(find.text('NEW BRANCH'), findsNothing);
    expect(find.text('PR context'), findsOneWidget);

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    final created =
        '/tmp/${worktreeNameForPrBranch('feature/au2-6001-fix-konto', jiraKey: 'AU2-6001')}';
    expect(git.createdFrom.single.baseBranch, 'feature/au2-6001-fix-konto');
    expect(git.createdFrom.single.newBranch, isNull);
    expect(terminal.launched.single.dir, created);
    expect(
      terminal.launched.single.command,
      "claude $_discordArgs $_launchFlags -- 'Context: Working on pull request #42 \"Fix "
      "konto (AU2-6001)\" (feature/au2-6001-fix-konto into develop) for issue "
      "AU2-6001.'",
    );
    final repo = workspace.selectedRepo!;
    expect(repo.prAuthors[created], 'jane');
    expect(repo.jiraIssues[created], 'AU2-6001');
    expect(repo.claudeSessions, [created]);
    // A PR branch doesn't become the default base for new worktrees.
    expect(repo.lastBaseBranch, isNull);
  });

  testWidgets('reuses the worktree that has the PR branch checked out', (
    tester,
  ) async {
    await pump(tester, const GithubPrsTab());

    await tester.tap(find.byTooltip('Claude session for #7…'));
    await tester.pumpAndSettle();

    expect(find.text('WORKTREE NAME'), findsNothing);
    expect(find.text('au2-wt'), findsOneWidget);

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    expect(git.created, isEmpty);
    expect(terminal.launched.single.dir, _existingPath);
    expect(
      terminal.launched.single.command,
      contains('pull request #7 "Værksted kontakt (AU2-5928)"'),
    );
  });

}
