import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/app/dependencies.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/core/storage/config_file.dart';
import 'package:tree_launcher/features/github_prs/domain/github_config.dart';
import 'package:tree_launcher/features/jira/data/jira_api_service.dart';
import 'package:tree_launcher/features/jira/domain/jira_version.dart';
import 'package:tree_launcher/features/settings/presentation/widgets/settings_dialog.dart';
import 'package:tree_launcher/features/workspace/data/git_service.dart';
import 'package:tree_launcher/features/workspace/domain/repo_config.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/repo_settings_view.dart';

import 'fake_config_stores.dart';
import 'test_database.dart';

/// Jira with no versions, so the Jira section never calls the real one.
class _NoJira extends JiraApiService {
  @override
  Future<List<JiraVersion>> fetchVersions(String projectKey) async => const [];
}

/// Git without processes for the branch lists, which a widget test's fake
/// clock never lets finish.
class _NoBranchesGit extends GitService {
  @override
  Future<List<String>> listBranches(String repoPath) async => const [];
}

/// Opens every section of the settings dialog and of the repo settings,
/// which were split into many files, so a section that fails to build
/// fails here.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => '/tmp',
      );

  late AppDependencies dependencies;

  setUp(() async {
    dependencies = AppDependencies(
      database: testDatabase(),
      gitService: _NoBranchesGit(),
      configFile: ConfigFile(path: '/tmp/tree_launcher_smoke_config.json'),
      repoConfigStore: FakeRepoConfigStore([
        RepoConfig(
          name: 'demo',
          path: '/repos/demo',
          jiraProjectKey: 'AU2',
          githubConfig: GithubConfig(owner: 'acme', repo: 'app', token: 't'),
        ),
      ]),
      appSettingsStore: FakeAppSettingsStore(),
    );
    await dependencies.workspace.loadRepos();
  });

  /// Shows [home] with the app's providers, opens each of [sections] by
  /// its navigation label, and fails on any exception but an overflow: the
  /// test font draws every character as a full square, so labels overflow
  /// here that fit in the app.
  Future<void> openEach(
    WidgetTester tester,
    Widget home,
    List<String> sections,
  ) async {
    tester.view.physicalSize = const Size(1500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final original = FlutterError.onError;
    final errors = <String>[];
    FlutterError.onError = (details) {
      if (!details.exceptionAsString().contains('overflowed')) {
        errors.add(details.exceptionAsString());
      }
    };
    try {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider.value(value: dependencies),
            ChangeNotifierProvider.value(value: dependencies.workspace),
            ChangeNotifierProvider.value(value: dependencies.settings),
            ChangeNotifierProvider.value(value: dependencies.agentApi),
            Provider.value(value: dependencies.configFile),
            Provider<JiraApiService>.value(value: _NoJira()),
          ],
          child: MaterialApp(
            theme: AppTheme.current,
            home: Scaffold(body: home),
          ),
        ),
      );
      for (final section in sections) {
        await tester.tap(find.text(section).first);
        await tester.pump();
        expect(errors, isEmpty, reason: section);
      }
    } finally {
      FlutterError.onError = original;
    }
  }

  testWidgets('every section of the settings dialog opens', (tester) async {
    await openEach(tester, const SettingsDialog(), [
      'Theme',
      'Terminals',
      'Repositories',
      'Jira',
      'Agent API',
      'Help',
    ]);
  });

  testWidgets('every section of the repo settings opens', (tester) async {
    await openEach(tester, const RepoSettingsView(), [
      'General',
      'VS Code Configs',
      'Custom Commands',
      'Claude Prompts',
      'Issue Keys',
      'GitHub',
      'Jira',
    ]);
    // The GitHub section, opened second to last, showed the repo's
    // settings.
    await tester.tap(find.text('GitHub').first);
    await tester.pump();
    expect(find.text('acme'), findsOneWidget);
  });
}
