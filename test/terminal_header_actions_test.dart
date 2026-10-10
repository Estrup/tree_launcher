import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/features/activity/data/worktree_event_store.dart';
import 'package:tree_launcher/features/github_prs/presentation/controllers/github_prs_controller.dart';
import 'package:tree_launcher/features/settings/domain/app_settings.dart';
import 'package:tree_launcher/features/terminal/domain/terminal_session.dart';
import 'package:tree_launcher/features/terminal/presentation/widgets/terminal_header_actions.dart';
import 'package:tree_launcher/features/workspace/data/git_service.dart';
import 'package:tree_launcher/features/workspace/domain/repo_config.dart';
import 'package:tree_launcher/features/workspace/domain/worktree.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late WorkspaceController workspace;
  late GithubPrsController prs;

  final tempDir = Directory.systemTemp.createTempSync('terminal_header_test');
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        pathProviderChannel,
        (call) async => tempDir.path,
      );

  setUp(() async {
    workspace = WorkspaceController(
      gitService: _FakeGitService(),
      configService: _FakeConfigService(),
      eventStore: WorktreeEventStore(directoryPath: tempDir.path),
    );
    prs = GithubPrsController();
    await workspace.addRepo('/tmp/repo');
    await workspace.updateJiraIssue('/tmp/repo-au2-1', 'AU2-1');
  });

  tearDown(() {
    prs.dispose();
    workspace.dispose();
  });

  Future<void> pump(WidgetTester tester, TerminalSession session) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WorkspaceController>.value(value: workspace),
          ChangeNotifierProvider<GithubPrsController>.value(value: prs),
        ],
        child: MaterialApp(
          home: Scaffold(body: TerminalHeaderActions(session: session)),
        ),
      ),
    );
  }

  testWidgets("shows a Claude session's Jira issue and Desktop button", (
    tester,
  ) async {
    await pump(
      tester,
      TerminalSession(
        title: 'Claude: repo-au2-1',
        workingDirectory: '/tmp/repo-au2-1',
        repoPath: '/tmp/repo',
        isClaude: true,
      ),
    );

    expect(find.text('AU2-1'), findsOneWidget);
    expect(find.text('Desktop'), findsOneWidget);
  });

  testWidgets('a plain terminal gets no Desktop button', (tester) async {
    await pump(
      tester,
      TerminalSession(
        title: 'repo-other',
        workingDirectory: '/tmp/repo-other',
        repoPath: '/tmp/repo',
      ),
    );

    expect(find.text('Desktop'), findsNothing);
    expect(find.textContaining('AU2-'), findsNothing);
  });
}
