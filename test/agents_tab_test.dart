import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/features/activity/data/worktree_event_store.dart';
import 'package:tree_launcher/features/agents/data/agent_run_store.dart';
import 'package:tree_launcher/features/agents/domain/agent_kind.dart';
import 'package:tree_launcher/features/agents/domain/agent_run.dart';
import 'package:tree_launcher/features/agents/presentation/controllers/agents_controller.dart';
import 'package:tree_launcher/features/agents/presentation/widgets/agents_tab.dart';
import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';
import 'package:tree_launcher/features/terminal/presentation/controllers/terminal_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:tree_launcher/models/claude_prompt.dart';
import 'package:tree_launcher/models/worktree.dart';
import 'package:tree_launcher/services/git_service.dart';

import 'fake_config_stores.dart';
import 'test_database.dart';

class _FakeGitService extends GitService {
  @override
  Future<WorktreeListResult> getWorktrees(String repoPath) async =>
      WorktreeListResult(worktrees: const [], isBareLayout: false);

  @override
  Future<bool> isGitRepo(String path) async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late WorkspaceController workspace;
  late SettingsController settings;
  late TerminalController terminal;
  late AgentsController agents;

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('agents_tab_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          pathProviderChannel,
          (call) async => tempDir.path,
        );
    workspace = WorkspaceController(
      gitService: _FakeGitService(),
      repoConfigStore: FakeRepoConfigStore(),
      eventStore: WorktreeEventStore(testDatabase()),
    );
    settings = SettingsController(store: FakeAppSettingsStore());
    terminal = TerminalController();
    agents = AgentsController(
      store: AgentRunStore(testDatabase()),
    );
    await workspace.addRepo('/tmp/au2office');
    await workspace.updateRepoClaudePrompts(workspace.selectedRepo!, [
      ClaudePrompt(
        name: 'Factory track: feature',
        prompt: '/factory track feature {issue}',
        kind: AgentKind.build,
      ),
      ClaudePrompt(name: 'Fix issue', prompt: 'Fix {issue}'),
    ]);
  });

  tearDown(() async {
    await agents.flush();
    agents.dispose();
    terminal.dispose();
    settings.dispose();
    workspace.dispose();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<AgentRun> run(String title, {AgentKind kind = AgentKind.build}) =>
      agents.createForLaunch(
        kind: kind,
        repoName: workspace.selectedRepo!.name,
        promptName: 'Factory track: feature',
        title: title,
        worktreePath: '/tmp/wt-$title',
      );

  Future<void> pumpTab(WidgetTester tester, AgentKind kind) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WorkspaceController>.value(value: workspace),
          ChangeNotifierProvider<SettingsController>.value(value: settings),
          ChangeNotifierProvider<TerminalController>.value(value: terminal),
          ChangeNotifierProvider<AgentsController>.value(value: agents),
        ],
        child: MaterialApp(
          home: Scaffold(body: AgentsTab(kind: kind)),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('lists the agents waiting for you first', (tester) async {
    late AgentRun waiting;
    await tester.runAsync(() async {
      final running = await run('running-one');
      waiting = await run('waiting-one');
      final done = await run('done-one');
      await agents.report(
        running.id,
        const AgentReport(
          stages: ['spec', 'plan', 'implement'],
          stage: 'implement',
          progressDone: 4,
          progressTotal: 7,
          message: 'trin 4/7 ✓',
        ),
      );
      await agents.report(
        waiting.id,
        const AgentReport(state: AgentState.waiting, message: 'Gate 1'),
      );
      await agents.report(done.id, const AgentReport(state: AgentState.done));
    });
    await pumpTab(tester, AgentKind.build);

    expect(find.text('running-one'), findsOneWidget);
    expect(find.text('done-one'), findsNothing);
    expect(find.text('Waiting for you'), findsOneWidget);
    expect(find.text('implement 4/7'), findsOneWidget);
    expect(find.text('trin 4/7 ✓'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('waiting-one')).dy,
      lessThan(tester.getTopLeft(find.text('running-one')).dy),
    );
    expect(find.text('New build agent'), findsOneWidget);

    await tester.tap(find.text('Finished'));
    await tester.pump();
    expect(find.text('done-one'), findsOneWidget);
    expect(find.text('running-one'), findsNothing);
  });

  testWidgets('explains how to get started without prompts', (tester) async {
    await pumpTab(tester, AgentKind.docs);

    expect(find.text('No active docs agents'), findsOneWidget);
    expect(find.textContaining('Give a prompt the Docs kind'), findsOneWidget);
  });

  test('shows a tab for a kind with prompts or runs', () async {
    final repo = workspace.selectedRepo!;
    bool shows(AgentKind kind) =>
        showsAgentTab(repo.name, repo.claudePrompts, agents, kind);

    expect(shows(AgentKind.build), isTrue);
    expect(shows(AgentKind.verify), isFalse);

    await run('self-registered', kind: AgentKind.verify);
    expect(shows(AgentKind.verify), isTrue);
  });
}
