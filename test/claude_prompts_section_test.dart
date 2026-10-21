import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/activity/data/worktree_event_store.dart';
import 'package:tree_launcher/features/agents/domain/claude_prompt.dart';
import 'package:tree_launcher/features/workspace/data/git_service.dart';
import 'package:tree_launcher/features/workspace/domain/worktree.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/repo_settings/claude_prompts_section.dart';

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
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => '/tmp',
      );

  late WorkspaceController workspace;

  setUp(() async {
    workspace = WorkspaceController(
      gitService: _FakeGitService(),
      repoConfigStore: FakeRepoConfigStore(),
      eventStore: WorktreeEventStore(testDatabase()),
      metadataStore: MemoryWorktreeMetadataStore(),
    );
    await workspace.addRepo('/tmp/demo');
    await workspace.updateRepoClaudePrompts(workspace.selectedRepo!, [
      ClaudePrompt(name: 'Alpha', prompt: 'a'),
      ClaudePrompt(name: 'Beta', prompt: 'b'),
      ClaudePrompt(name: 'Gamma', prompt: 'c'),
    ]);
  });

  tearDown(() => workspace.dispose());

  testWidgets('dragging a prompt saves the new order', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: workspace,
        child: MaterialApp(
          theme: AppTheme.current,
          home: const Scaffold(body: RepoClaudePromptsSection()),
        ),
      ),
    );

    final handles = find.byIcon(Icons.drag_indicator_rounded);
    expect(handles, findsNWidgets(3));
    final gammaHandle = tester.getCenter(handles.at(2));
    final alphaHandle = tester.getCenter(handles.at(0));
    final gesture = await tester.startGesture(gammaHandle);
    await tester.pump();
    // Up past the first prompt, in steps like a real drag.
    final target = alphaHandle - const Offset(0, 30);
    for (var step = 1; step <= 10; step++) {
      await gesture.moveTo(Offset.lerp(gammaHandle, target, step / 10)!);
      await tester.pump(const Duration(milliseconds: 50));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    // Past the section's save delay.
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      [for (final p in workspace.selectedRepo!.claudePrompts) p.name],
      ['Gamma', 'Alpha', 'Beta'],
    );
  });
}
