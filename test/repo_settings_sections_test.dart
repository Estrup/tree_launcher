import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/activity/data/worktree_event_store.dart';
import 'package:tree_launcher/features/workspace/data/git_service.dart';
import 'package:tree_launcher/features/workspace/domain/repo_config.dart';
import 'package:tree_launcher/features/workspace/domain/worktree.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/repo_settings/general_section.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/repo_settings/github_section.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/repo_settings/jira_section.dart';

import 'fake_config_stores.dart';
import 'test_database.dart';

class _FakeGit extends GitService {
  @override
  Future<WorktreeListResult> getWorktrees(String repoPath) async =>
      WorktreeListResult(worktrees: const [], isBareLayout: false);
}

void main() {
  late FakeRepoConfigStore store;
  late WorkspaceController workspace;

  setUp(() async {
    store = FakeRepoConfigStore([
      RepoConfig(name: 'demo', path: '/repos/demo', jiraProjectKey: 'AU2'),
    ]);
    workspace = WorkspaceController(
      gitService: _FakeGit(),
      repoConfigStore: store,
      eventStore: WorktreeEventStore(testDatabase()),
      metadataStore: MemoryWorktreeMetadataStore(),
    );
    await workspace.loadRepos();
  });

  tearDown(() => workspace.dispose());

  Future<void> pump(WidgetTester tester, Widget section) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: workspace,
        child: MaterialApp(
          theme: AppTheme.current,
          home: Scaffold(body: section),
        ),
      ),
    );
  }

  Finder field(String hint) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.hintText == hint,
  );

  testWidgets('shows the selected repo and saves a rename after a pause', (
    tester,
  ) async {
    await pump(tester, const RepoGeneralSection());
    expect(find.text('demo'), findsOneWidget);

    await tester.enterText(field('Repository name'), 'dem');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(field('Repository name'), 'demo-app');
    await tester.pump(const Duration(milliseconds: 400));
    // Still typing: not saved yet.
    expect(store.savedRepos.single.name, 'demo');

    await tester.pump(const Duration(milliseconds: 200));
    expect(store.savedRepos.single.name, 'demo-app');
  });

  testWidgets('a blank name is never saved', (tester) async {
    await pump(tester, const RepoGeneralSection());
    await tester.enterText(field('Repository name'), '  ');
    await tester.pump(const Duration(seconds: 1));
    expect(store.savedRepos.single.name, 'demo');
  });

  testWidgets('an invalid Jira key drops the pending save', (tester) async {
    await pump(tester, const RepoJiraSection());
    expect(find.text('AU2'), findsOneWidget);

    await tester.enterText(field('e.g. AU2'), 'OA');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(field('e.g. AU2'), 'oa-1');
    await tester.pump(const Duration(seconds: 1));
    expect(store.savedRepos.single.jiraProjectKey, 'AU2');
    expect(find.text('Use the project key, e.g. AU2'), findsOneWidget);

    await tester.enterText(field('e.g. AU2'), 'OA');
    await tester.pump(const Duration(milliseconds: 500));
    expect(store.savedRepos.single.jiraProjectKey, 'OA');
  });

  testWidgets('a pasted GitHub URL fills owner and repo', (tester) async {
    await pump(tester, const RepoGithubSection());

    await tester.enterText(
      field('owner (or paste full GitHub URL)'),
      'https://github.com/acme/app',
    );
    await tester.pump(const Duration(milliseconds: 400));

    final github = store.savedRepos.single.githubConfig!;
    expect(github.owner, 'acme');
    expect(github.repo, 'app');
  });
}
