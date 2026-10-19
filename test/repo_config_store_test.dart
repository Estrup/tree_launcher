import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tree_launcher/core/storage/config_file.dart';
import 'package:tree_launcher/features/github_prs/domain/github_config.dart';
import 'package:tree_launcher/features/workspace/data/repo_config_store.dart';
import 'package:tree_launcher/features/workspace/domain/repo_config.dart';

import 'fake_config_stores.dart';

RepoConfig _repo(String name, {String? token}) => RepoConfig(
  name: name,
  path: '/repos/$name',
  githubConfig: token == null
      ? null
      : GithubConfig(owner: 'acme', repo: name, token: token),
);

void main() {
  late Directory dir;
  late String path;
  late ConfigFile file;
  late MemoryGithubTokenStore tokens;
  late RepoConfigStore store;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('repo_config_store');
    path = p.join(dir.path, 'config.json');
    file = ConfigFile(path: path);
    tokens = MemoryGithubTokenStore();
    store = RepoConfigStore(configFile: file, tokenStore: tokens);
  });

  tearDown(() => dir.delete(recursive: true));

  /// The saved `githubConfig` of each repo, straight from the file.
  Future<List<Object?>> githubJson() async {
    final config = jsonDecode(await File(path).readAsString()) as Map;
    return [for (final repo in config['repos'] as List) repo['githubConfig']];
  }

  test('keeps the token out of config.json and loads it back', () async {
    await store.save([_repo('app', token: 'ghp_secret'), _repo('docs')]);

    expect(await File(path).readAsString(), isNot(contains('ghp_secret')));
    expect(await githubJson(), [
      {
        'owner': 'acme',
        'repo': 'app',
        // Older builds need the key.
        'token': '',
        'prRefreshIntervalMinutes': 5,
        'issuesEnabled': false,
      },
      null,
    ]);
    expect(tokens.tokens, {'/repos/app': 'ghp_secret'});

    final fresh = RepoConfigStore(configFile: file, tokenStore: tokens);
    final repos = await fresh.load();
    expect(repos.first.githubConfig!.token, 'ghp_secret');
    expect(repos.first.githubConfig!.isConfigured, isTrue);
    expect(repos.last.githubConfig, isNull);
  });

  test('moves a token saved in config.json to the token store', () async {
    // How older versions saved it.
    await file.update((config) {
      config['repos'] = [_repo('app', token: 'ghp_old').toJson()];
    });

    final repos = await store.load();

    expect(repos.single.githubConfig!.token, 'ghp_old');
    expect(tokens.tokens, {'/repos/app': 'ghp_old'});
    expect(await File(path).readAsString(), isNot(contains('ghp_old')));
    expect((await githubJson()).single, containsPair('token', ''));
  });

  test('keeps the token in config.json when the token store fails', () async {
    tokens.failWith = Exception('Keychain locked');
    await file.update((config) {
      config['repos'] = [_repo('app', token: 'ghp_old').toJson()];
    });

    expect((await store.load()).single.githubConfig!.token, 'ghp_old');
    expect(await File(path).readAsString(), contains('ghp_old'));

    await store.save([_repo('app', token: 'ghp_new')]);
    expect(await File(path).readAsString(), contains('ghp_new'));

    // Moved once the store works again.
    tokens.failWith = null;
    expect((await store.load()).single.githubConfig!.token, 'ghp_new');
    expect(tokens.tokens, {'/repos/app': 'ghp_new'});
    expect(await File(path).readAsString(), isNot(contains('ghp_new')));
  });

  test('touches the token store only when a token changes', () async {
    tokens.tokens['/repos/app'] = 'ghp_secret';
    await file.update((config) {
      config['repos'] = [_repo('app', token: '').toJson(), _repo('docs')];
    });

    final repos = await store.load();
    await store.load();
    expect(tokens.reads, 1);

    await store.save(repos);
    await store.save(repos);
    expect(tokens.writes, 0);
    expect(tokens.deletes, 0);

    await store.save([_repo('app', token: 'ghp_rotated'), _repo('docs')]);
    expect(tokens.writes, 1);
    expect(tokens.tokens, {'/repos/app': 'ghp_rotated'});
  });

  test('removes the token with the GitHub config or the repo', () async {
    await store.save([_repo('app', token: 'ghp_a'), _repo('web', token: 'b')]);

    await store.save([_repo('app'), _repo('web', token: 'b')]);
    expect(tokens.tokens, {'/repos/web': 'b'});

    await store.save([_repo('app')]);
    expect(tokens.tokens, isEmpty);
  });

  test('saves land in the order they were made', () async {
    tokens.writeDelay = const Duration(milliseconds: 50);
    // The first save writes the token store (slow); the second has no token
    // to write, so it would otherwise finish first.
    final first = store.save([_repo('app', token: 'ghp_a')]);
    final second = store.save([_repo('app'), _repo('docs')]);
    await Future.wait([first, second]);

    expect((await store.load()).map((r) => r.name), ['app', 'docs']);
    expect(tokens.tokens, isEmpty);
  });
}
