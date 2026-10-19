import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tree_launcher/core/storage/config_file.dart';
import 'package:tree_launcher/features/settings/data/app_settings_store.dart';
import 'package:tree_launcher/features/settings/domain/app_settings.dart';
import 'package:tree_launcher/features/workspace/data/repo_config_store.dart';
import 'package:tree_launcher/features/workspace/domain/repo_config.dart';
import 'package:tree_launcher/core/database/ui_state_store.dart';
import 'package:tree_launcher/features/jira/data/jira_tag_store.dart';

import 'fake_config_stores.dart';
import 'test_database.dart';

void main() {
  late Directory dir;
  late String path;
  late ConfigFile file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('config_file');
    path = p.join(dir.path, 'config.json');
    file = ConfigFile(path: path);
  });

  tearDown(() => dir.delete(recursive: true));

  test('a missing file reads as empty', () async {
    expect(await file.read(), {'repos': [], 'settings': {}});
  });

  test('update writes the file and leaves no temporary file', () async {
    await file.update((config) => config['a'] = 1);

    expect(jsonDecode(await File(path).readAsString()), {
      'repos': [],
      'settings': {},
      'a': 1,
    });
    expect(dir.listSync().map((e) => p.basename(e.path)), ['config.json']);
  });

  test('overlapping updates all land', () async {
    await Future.wait([
      for (var i = 0; i < 20; i++) file.update((config) => config['k$i'] = i),
    ]);

    final config = await file.read();
    for (var i = 0; i < 20; i++) {
      expect(config['k$i'], i);
    }
  });

  test('unawaited saves of different sections keep each other', () async {
    final db = testDatabase();
    final uiState = UiStateStore(db);
    final repos = RepoConfigStore(
      configFile: file,
      tokenStore: MemoryGithubTokenStore(),
      uiState: uiState,
    );
    final settings = AppSettingsStore(
      configFile: file,
      tagStore: JiraTagStore(db),
      uiState: uiState,
    );

    // Like WorkspaceController, which doesn't await saving the selection.
    final saves = [
      repos.save([RepoConfig(name: 'app', path: '/repos/app')]),
      repos.saveLastSelectedRepoPath('/repos/app'),
      settings.save(AppSettings(defaultBranchPrefix: 'feat')),
    ];
    await Future.wait(saves);

    expect((await repos.load()).single.path, '/repos/app');
    expect(await repos.loadLastSelectedRepoPath(), '/repos/app');
    expect((await settings.load()).defaultBranchPrefix, 'feat');
  });

  test('a reader never sees a half-written file', () async {
    // A second instance has its own lock, like a second app (a debug build)
    // on the same file, so its reads interleave with the writes.
    final other = ConfigFile(path: path);
    final big = List.generate(2000, (i) => 'entry $i ' * 4);
    var writing = true;
    final writes = () async {
      for (var i = 0; i < 30; i++) {
        await file.update((config) => config['big'] = [i, ...big]);
      }
      writing = false;
    }();

    var reads = 0;
    while (writing) {
      await other.read();
      reads++;
    }
    await writes;

    expect(reads, greaterThan(0));
    expect(((await other.read())['big'] as List).first, 29);
  });

  test('a change that throws writes nothing and frees the lock', () async {
    await file.update((config) => config['a'] = 1);

    await expectLater(
      file.update((config) {
        config['a'] = 2;
        throw StateError('nope');
      }),
      throwsStateError,
    );
    await file.update((config) => config['b'] = 3);

    expect(await file.read(), containsPair('a', 1));
    expect(await file.read(), containsPair('b', 3));
  });

  test('a corrupt file throws instead of being overwritten', () async {
    await File(path).writeAsString('{"repos": [');

    await expectLater(
      file.update((config) => config['a'] = 1),
      throwsFormatException,
    );
    expect(await File(path).readAsString(), '{"repos": [');
  });
}
