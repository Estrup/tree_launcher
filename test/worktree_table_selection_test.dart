import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/features/activity/data/worktree_event_store.dart';
import 'package:tree_launcher/features/github_prs/presentation/controllers/github_prs_controller.dart';
import 'package:tree_launcher/features/settings/domain/app_settings.dart';
import 'package:tree_launcher/features/workspace/data/git_service.dart';
import 'package:tree_launcher/features/workspace/domain/repo_config.dart';
import 'package:tree_launcher/features/workspace/domain/worktree.dart';
import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/worktree_table.dart';
import 'package:tree_launcher/services/config_service.dart';

Worktree _wt(String name, {bool isMain = false}) => Worktree(
  path: '/tmp/repo/$name',
  branch: name,
  name: name,
  isMain: isMain,
  commitHash: 'abc123',
);

Finder _checkboxes() => find.byWidgetPredicate(
  (w) => w.runtimeType.toString() == '_SelectCheckbox',
);

class _FakeConfigService extends ConfigService {
  List<RepoConfig> savedRepos = const [];
  AppSettings savedSettings = AppSettings();

  @override
  Future<List<RepoConfig>> loadRepos() async => savedRepos;

  @override
  Future<void> saveRepos(List<RepoConfig> repos) async {
    savedRepos = List<RepoConfig>.from(repos);
  }

  @override
  Future<AppSettings> loadSettings() async => savedSettings;

  @override
  Future<void> saveSettings(AppSettings settings) async {
    savedSettings = settings;
  }
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
    final configService = _FakeConfigService();
    workspace = WorkspaceController(
      gitService: _FakeGitService(),
      configService: configService,
      eventStore: WorktreeEventStore(directoryPath: tempDir.path),
    );
    settings = SettingsController(configService: configService);
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

  Future<void> pumpApp(WidgetTester tester, List<Worktree> worktrees) async {
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
        ],
        child: MaterialApp(
          home: Scaffold(body: WorktreeTable(worktrees: worktrees)),
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

    expect(
      workspace.selectedRepo!.hiddenWorktrees,
      containsAll(['/tmp/repo/one', '/tmp/repo/two', '/tmp/repo/three']),
    );
    // Selection cleared even though the rows were not rebuilt away.
    expect(find.text('Hide'), findsNothing);
  });
}
