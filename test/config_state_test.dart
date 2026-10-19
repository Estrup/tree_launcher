import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tree_launcher/app/migrations/config_state_import.dart';
import 'package:tree_launcher/core/database/app_database.dart';
import 'package:tree_launcher/core/database/ui_state_store.dart';
import 'package:tree_launcher/core/storage/config_file.dart';
import 'package:tree_launcher/features/jira/data/jira_tag_store.dart';
import 'package:tree_launcher/features/jira/domain/jira_tag.dart';
import 'package:tree_launcher/features/settings/data/app_settings_store.dart';
import 'package:tree_launcher/features/settings/domain/app_settings.dart';
import 'package:tree_launcher/features/workspace/data/repo_config_store.dart';
import 'package:tree_launcher/features/workspace/domain/repo_config.dart';

import 'fake_config_stores.dart';
import 'test_database.dart';

const _blocked = JiraTag(id: 'b', name: 'Blocked', color: 'red');
const _demo = JiraTag(id: 'd', name: 'Demo', color: 'blue');

void main() {
  group('UiStateStore', () {
    late AppDatabase db;
    late UiStateStore store;

    setUp(() {
      db = testDatabase();
      store = UiStateStore(db);
    });

    test('keeps JSON values per scope; null removes a key', () async {
      await store.write('app', {'model': 'opus', 'existing': true});
      await store.write('repo:/r', {'base': 'develop'});
      await store.write('app', {'model': null});

      final fresh = UiStateStore(db);
      expect(await fresh.read('app'), {'existing': true});
      expect(await fresh.read('repo:/r'), {'base': 'develop'});
      expect(await fresh.read('repo:/none'), isEmpty);
    });

    test('writeIfAbsent leaves the values already there', () async {
      await store.write('app', {'model': 'opus'});
      await store.writeIfAbsent('app', {'model': 'haiku', 'effort': 'max'});
      expect(await UiStateStore(db).read('app'), {
        'model': 'opus',
        'effort': 'max',
      });
    });

    test('drops the scopes of repos that are gone', () async {
      await store.write(UiStateStore.repoScope('/a'), {'base': 'main'});
      await store.write(UiStateStore.repoScope('/b'), {'base': 'develop'});
      await store.write('app', {'model': 'opus'});

      await store.keepRepoScopes(['/a']);

      final fresh = UiStateStore(db);
      expect(await fresh.read(UiStateStore.repoScope('/a')), {'base': 'main'});
      expect(await fresh.read(UiStateStore.repoScope('/b')), isEmpty);
      expect(await fresh.read('app'), {'model': 'opus'});
    });
  });

  group('JiraTagStore', () {
    test('keeps the tags in order and each issue\'s tags', () async {
      final db = testDatabase();
      await JiraTagStore(db).save(
        [_demo, _blocked],
        {
          'AU2-1': ['b', 'd'],
          'AU2-2': ['d', 'gone'],
        },
      );

      final loaded = await JiraTagStore(db).load();
      expect([for (final tag in loaded.tags) tag.name], ['Demo', 'Blocked']);
      expect(loaded.byIssue, {
        'AU2-1': ['b', 'd'],
        'AU2-2': ['d'],
      });
    });

    test('a deleted tag leaves every issue', () async {
      final db = testDatabase();
      final store = JiraTagStore(db);
      await store.save(
        [_blocked, _demo],
        {
          'AU2-1': ['b'],
          'AU2-2': ['b', 'd'],
        },
      );
      await store.save(
        [_demo],
        {
          'AU2-1': ['b'],
          'AU2-2': ['b', 'd'],
        },
      );

      expect((await JiraTagStore(db).load()).byIssue, {
        'AU2-2': ['d'],
      });
    });
  });

  group('the config stores', () {
    late Directory dir;
    late String path;
    late ConfigFile file;
    late AppDatabase db;
    late UiStateStore uiState;
    late AppSettingsStore settings;
    late RepoConfigStore repos;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('config_state');
      path = p.join(dir.path, 'config.json');
      file = ConfigFile(path: path);
      db = testDatabase();
      uiState = UiStateStore(db);
      settings = AppSettingsStore(
        configFile: file,
        tagStore: JiraTagStore(db),
        uiState: uiState,
      );
      repos = RepoConfigStore(
        configFile: file,
        tokenStore: MemoryGithubTokenStore(),
        uiState: uiState,
      );
    });

    tearDown(() => dir.delete(recursive: true));

    Future<Map<String, dynamic>> fileJson() async =>
        jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;

    test('keep tags and remembered choices out of the file', () async {
      await settings.save(
        AppSettings(
          defaultBranchPrefix: 'sen',
          claudeModel: 'opus',
          claudeEffort: 'max',
          claudePrompt: 'Verify',
          claudeUseExistingWorktree: true,
          jiraTags: const [_blocked],
          jiraTagsByIssue: const {
            'AU2-1': ['b'],
          },
        ),
      );
      await repos.save([
        RepoConfig(
          name: 'app',
          path: '/repos/app',
          lastBaseBranch: 'develop',
          jiraFixVersionId: '29501',
          githubMilestoneNumber: 3,
          agentWorkingDirectory: '/repos/app-main',
        ),
      ]);
      await repos.saveLastSelectedRepoPath('/repos/app');

      final json = await fileJson();
      expect(json['settings'], isNot(contains('claudeModel')));
      expect(json['settings'], isNot(contains('jiraTags')));
      expect(json['settings']['defaultBranchPrefix'], 'sen');
      expect(json, isNot(contains('lastSelectedRepoPath')));
      final repo = (json['repos'] as List).single as Map;
      expect(repo, isNot(contains('lastBaseBranch')));
      expect(repo, isNot(contains('jiraFixVersionId')));

      final loaded = await settings.load();
      expect(loaded.defaultBranchPrefix, 'sen');
      expect(loaded.claudeModel, 'opus');
      expect(loaded.claudeEffort, 'max');
      expect(loaded.claudePrompt, 'Verify');
      expect(loaded.claudeUseExistingWorktree, isTrue);
      expect(loaded.tagsFor('AU2-1').single.name, 'Blocked');
      final repoLoaded = (await repos.load()).single;
      expect(repoLoaded.lastBaseBranch, 'develop');
      expect(repoLoaded.jiraFixVersionId, '29501');
      expect(repoLoaded.githubMilestoneNumber, 3);
      expect(repoLoaded.agentWorkingDirectory, '/repos/app-main');
      expect(await repos.loadLastSelectedRepoPath(), '/repos/app');
    });

    test('a tag or a remembered choice leaves the file untouched', () async {
      final base = AppSettings(defaultBranchPrefix: 'sen');
      await settings.save(base);
      final before = await File(path).lastModified();
      final bytes = await File(path).readAsString();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await settings.save(
        base.copyWith(
          claudeModel: 'opus',
          jiraTags: const [_demo],
          jiraTagsByIssue: const {
            'AU2-9': ['d'],
          },
        ),
      );
      await repos.saveLastSelectedRepoPath('/repos/app');

      expect(await File(path).readAsString(), bytes);
      expect(await File(path).lastModified(), before);
      expect((await settings.load()).tagsFor('AU2-9').single.name, 'Demo');
    });

    test('a removed repo takes its remembered choices along', () async {
      await repos.save([
        RepoConfig(name: 'a', path: '/a', lastBaseBranch: 'main'),
        RepoConfig(name: 'b', path: '/b', lastBaseBranch: 'develop'),
      ]);
      await repos.save([
        RepoConfig(name: 'a', path: '/a', lastBaseBranch: 'main'),
      ]);
      expect(await uiState.read(UiStateStore.repoScope('/b')), isEmpty);
    });
  });

  group('ConfigStateImport', () {
    late Directory dir;
    late String path;
    late ConfigFile file;
    late AppDatabase db;
    late UiStateStore uiState;
    late JiraTagStore tags;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('config_state_import');
      path = p.join(dir.path, 'config.json');
      file = ConfigFile(path: path);
      db = testDatabase();
      uiState = UiStateStore(db);
      tags = JiraTagStore(db);
      await File(path).writeAsString(
        jsonEncode({
          'lastSelectedRepoPath': '/repos/app',
          'settings': {
            'themeName': 'muted',
            'claudeModel': 'opus',
            'claudeUseExistingWorktree': true,
            'jiraTags': [_blocked.toJson(), _demo.toJson()],
            'jiraTagsByIssue': {
              'AU2-1': ['d'],
            },
          },
          'repos': [
            {
              'name': 'app',
              'path': '/repos/app',
              'lastBaseBranch': 'develop',
              'githubMilestoneNumber': 3,
            },
          ],
        }),
      );
    });

    tearDown(() => dir.delete(recursive: true));

    ConfigStateImport import() =>
        ConfigStateImport(configFile: file, tagStore: tags, uiState: uiState);

    AppSettingsStore settingsStore() => AppSettingsStore(
      configFile: file,
      tagStore: JiraTagStore(db),
      uiState: UiStateStore(db),
    );

    RepoConfigStore repoStore() => RepoConfigStore(
      configFile: file,
      tokenStore: MemoryGithubTokenStore(),
      uiState: UiStateStore(db),
    );

    test('the stores use the file until the import has run', () async {
      final loaded = await settingsStore().load();
      expect(loaded.claudeModel, 'opus');
      expect(loaded.tagsFor('AU2-1').single.name, 'Demo');
      expect((await repoStore().load()).single.lastBaseBranch, 'develop');
      expect(await repoStore().loadLastSelectedRepoPath(), '/repos/app');

      // A save before the import keeps the keys in the file.
      await settingsStore().save(loaded.copyWith(themeName: 'paper'));
      final json = jsonDecode(await File(path).readAsString()) as Map;
      expect(json['settings']['claudeModel'], 'opus');
      expect(json['settings']['jiraTags'], hasLength(2));
    });

    test('moves the values into the database and drops the keys', () async {
      await import().run();

      final json = jsonDecode(await File(path).readAsString()) as Map;
      expect(json, isNot(contains('lastSelectedRepoPath')));
      expect(json['settings'], {'themeName': 'muted'});
      expect((json['repos'] as List).single, {
        'name': 'app',
        'path': '/repos/app',
      });

      final loaded = await settingsStore().load();
      expect(loaded.claudeModel, 'opus');
      expect(loaded.claudeUseExistingWorktree, isTrue);
      expect(
        [for (final tag in loaded.jiraTags) tag.name],
        ['Blocked', 'Demo'],
      );
      expect(loaded.tagsFor('AU2-1').single.name, 'Demo');
      final repo = (await repoStore().load()).single;
      expect(repo.lastBaseBranch, 'develop');
      expect(repo.githubMilestoneNumber, 3);
      expect(await repoStore().loadLastSelectedRepoPath(), '/repos/app');

      // Nothing left to move.
      await import().run();
      expect(jsonDecode(await File(path).readAsString()), json);
    });

    test('what the database already has wins', () async {
      await uiState.write('app', {'claudeModel': 'haiku'});
      await tags.save([_demo], const {});

      await import().run();

      final loaded = await settingsStore().load();
      expect(loaded.claudeModel, 'haiku');
      expect([for (final tag in loaded.jiraTags) tag.name], ['Demo']);
    });
  });
}
