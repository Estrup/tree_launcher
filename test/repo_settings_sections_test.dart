import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/activity/data/worktree_event_store.dart';
import 'package:tree_launcher/features/jira/data/jira_api_service.dart';
import 'package:tree_launcher/features/jira/domain/jira_version.dart';
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

  @override
  Future<List<String>> listBranches(String repoPath) async => [
    'develop',
    'releases/2.41',
  ];
}

class _FakeJira extends JiraApiService {
  @override
  Future<List<JiraVersion>> fetchVersions(String projectKey) async => const [
    JiraVersion(id: '1', name: '2.40', released: true),
    JiraVersion(id: '2', name: '2.41'),
    JiraVersion(id: '3', name: '2.42'),
  ];
}

void main() {
  late FakeRepoConfigStore store;
  late WorkspaceController workspace;

  setUp(() async {
    store = FakeRepoConfigStore([
      RepoConfig(
        name: 'demo',
        path: '/repos/demo',
        jiraProjectKey: 'AU2',
        jiraVersionBranches: {'2': 'releases/2.41'},
      ),
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
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: workspace),
          Provider<JiraApiService>.value(value: _FakeJira()),
        ],
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

  testWidgets('lists the mapped fixVersions and removes a mapping', (
    tester,
  ) async {
    await pump(tester, const RepoJiraSection());
    await tester.pump();

    expect(find.text('2.41'), findsOneWidget);
    expect(find.text('releases/2.41'), findsOneWidget);
    expect(find.text('2.42'), findsNothing);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    expect(store.savedRepos.single.jiraVersionBranches, isEmpty);
    expect(find.text('No fixVersion has a default branch.'), findsOneWidget);
  });

  testWidgets('maps another fixVersion from the add row', (tester) async {
    await pump(tester, const RepoJiraSection());
    await tester.pump();

    await tester.tap(find.text('Add Mapping'));
    await tester.pump();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    // Neither the mapped 2.41 nor the released 2.40 is offered.
    expect(find.text('2.41'), findsOneWidget);
    expect(find.text('2.40'), findsNothing);
    await tester.tap(find.text('2.42').last);
    await tester.pumpAndSettle();

    // Typing searches the branches without saving anything.
    await tester.tap(find.byType(TextField).last);
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, 'dev');
    await tester.pump();
    expect(find.text('develop'), findsOneWidget);
    expect(store.savedRepos.single.jiraVersionBranches, {'2': 'releases/2.41'});

    await tester.tap(find.text('develop').last);
    await tester.pump(const Duration(milliseconds: 300));

    expect(store.savedRepos.single.jiraVersionBranches, {
      '2': 'releases/2.41',
      '3': 'develop',
    });
    // Every unreleased version has a branch now.
    expect(find.text('Add Mapping'), findsNothing);
  });

  testWidgets('adds a trigger on the first unreleased fixVersion', (
    tester,
  ) async {
    await pump(tester, const RepoJiraSection());
    await tester.pump();
    expect(find.text('No triggers.'), findsOneWidget);

    await tester.tap(find.text('Add Trigger'));
    await tester.pump();
    final trigger = store.savedRepos.single.jiraTriggers.single;
    expect(trigger.fixVersionId, '2');
    expect(trigger.enabled, isTrue);
    expect(
      find.text('Pick a saved prompt to turn the trigger on.'),
      findsOneWidget,
    );

    await tester.enterText(field('e.g. QA Rejected'), 'QA');
    await tester.pump(const Duration(milliseconds: 600));
    expect(store.savedRepos.single.jiraTriggers.single.status, 'QA');
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
