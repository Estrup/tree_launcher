import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tree_launcher/core/storage/config_file.dart';
import 'package:tree_launcher/features/activity/data/worktree_event_store.dart';
import 'package:tree_launcher/features/workspace/data/git_service.dart';
import 'package:tree_launcher/features/workspace/data/repo_config_store.dart';
import 'package:tree_launcher/features/workspace/data/worktree_metadata_legacy_import.dart';
import 'package:tree_launcher/features/workspace/data/worktree_metadata_store.dart';
import 'package:tree_launcher/features/workspace/domain/repo_config.dart';
import 'package:tree_launcher/features/workspace/domain/worktree.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_metadata.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/worktree_metadata_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';

import 'fake_config_stores.dart';
import 'test_database.dart';

/// Lists [live] as the repo's worktrees, and creates worktrees under /w.
/// A create waits for [gate] when it is set, so tests can overlap two.
class _FakeGit extends GitService {
  _FakeGit(this.live);

  List<String> live;
  Completer<void>? gate;

  @override
  Future<WorktreeListResult> getWorktrees(String repoPath) async =>
      WorktreeListResult(
        worktrees: [
          for (final path in live)
            Worktree(
              path: path,
              branch: p.basename(path),
              name: p.basename(path),
              isMain: false,
              commitHash: 'abc',
            ),
        ],
        isBareLayout: false,
      );

  @override
  Future<bool> isGitRepo(String path) async => true;

  @override
  Future<String> addWorktree(
    String repoPath,
    String name, {
    String? baseBranch,
    String? newBranch,
    bool useNestedWorktrees = false,
  }) async {
    await gate?.future;
    final path = '/w/$name';
    live = [...live, path];
    return path;
  }

  @override
  Future<void> removeWorktree(String repoPath, String worktreePath) async {
    live = [
      for (final path in live)
        if (path != worktreePath) path,
    ];
  }

  @override
  Future<String> writeKickoffPrompt({
    required String repoPath,
    required String worktreePath,
    required String content,
  }) async => '$worktreePath/.tree-launcher/kickoff-prompt.md';
}

void main() {
  group('WorktreeMetadataStore', () {
    late WorktreeMetadataStore store;

    setUp(() => store = WorktreeMetadataStore(testDatabase()));

    test(
      'saves, replaces and deletes rows, in the order first written',
      () async {
        await store.saveAll([
          WorktreeMetadata(
            path: '/w/b',
            repoPath: '/r',
            jiraIssue: 'AU2-2',
            session: RememberedSession(
              promptId: 'Verify',
              startedAt: DateTime(2026, 10, 19, 9, 30),
            ),
          ),
          const WorktreeMetadata(path: '/w/a', repoPath: '/r', hidden: true),
        ]);
        await store.saveAll([
          const WorktreeMetadata(
            path: '/w/b',
            repoPath: '/r',
            jiraIssue: 'AU2-3',
            githubIssue: 12,
            prAuthor: 'kim',
            baseBranch: 'develop',
            kickoffPromptPath: '/w/b/k.md',
            snoozed: true,
          ),
        ]);

        final rows = await store.loadAll();
        expect([for (final m in rows) m.path], ['/w/b', '/w/a']);
        expect(rows.first.jiraIssue, 'AU2-3');
        expect(rows.first.githubIssue, 12);
        expect(rows.first.session, isNull);
        expect(rows.first.snoozed, isTrue);
        expect(rows.last.hidden, isTrue);

        // An empty entry deletes its row.
        await store.saveAll([
          const WorktreeMetadata(path: '/w/a', repoPath: '/r'),
        ]);
        await store.delete(['/w/b']);
        expect(await store.loadAll(), isEmpty);
      },
    );

    test('keeps a session start time to the microsecond', () async {
      final start = DateTime(2026, 10, 19, 9, 30, 1, 2, 3);
      await store.saveAll([
        WorktreeMetadata(
          path: '/w/a',
          repoPath: '/r',
          session: RememberedSession(startedAt: start),
        ),
      ]);
      expect((await store.loadAll()).single.session!.startedAt, start);
    });

    test('a legacy import keeps the rows already there', () async {
      await store.saveAll([
        const WorktreeMetadata(
          path: '/w/a',
          repoPath: '/r',
          jiraIssue: 'NEW-1',
        ),
      ]);
      await store.importLegacy([
        const WorktreeMetadata(
          path: '/w/a',
          repoPath: '/r',
          jiraIssue: 'OLD-1',
        ),
        const WorktreeMetadata(
          path: '/w/b',
          repoPath: '/r',
          jiraIssue: 'OLD-2',
        ),
      ]);
      final rows = await store.loadAll();
      expect(
        {for (final m in rows) m.path: m.jiraIssue},
        {'/w/a': 'NEW-1', '/w/b': 'OLD-2'},
      );
    });
  });

  group('WorktreeMetadataController', () {
    late WorktreeMetadataStore store;
    late WorktreeMetadataController metadata;

    setUp(() async {
      store = WorktreeMetadataStore(testDatabase());
      metadata = WorktreeMetadataController(store: store);
      addTearDown(metadata.dispose);
      await metadata.load();
    });

    test('applies changes at once and saves them in order', () async {
      var notified = 0;
      metadata.addListener(() => notified++);

      final first = metadata.update(
        '/r',
        '/w/a',
        (m) => m.copyWith(jiraIssue: 'AU2-1'),
      );
      final second = metadata.update(
        '/r',
        '/w/a',
        (m) => m.copyWith(baseBranch: 'develop'),
      );
      // Both apply before either is saved.
      expect(metadata['/w/a']!.jiraIssue, 'AU2-1');
      expect(metadata['/w/a']!.baseBranch, 'develop');
      await Future.wait([first, second]);

      final saved = (await store.loadAll()).single;
      expect(saved.jiraIssue, 'AU2-1');
      expect(saved.baseBranch, 'develop');
      expect(notified, 2);
    });

    test('a change to nothing new neither notifies nor saves', () async {
      await metadata.update('/r', '/w/a', (m) => m.copyWith(hidden: true));
      var notified = 0;
      metadata.addListener(() => notified++);

      await metadata.update('/r', '/w/a', (m) => m.copyWith(hidden: true));
      await metadata.update('/r', '/w/new', (m) => m);

      expect(notified, 0);
      expect(metadata['/w/new'], isNull);
    });

    test('drops an entry once nothing is left to keep', () async {
      await metadata.update('/r', '/w/a', (m) => m.copyWith(hidden: true));
      await metadata.update('/r', '/w/a', (m) => m.copyWith(hidden: false));
      expect(metadata['/w/a'], isNull);
      expect(await store.loadAll(), isEmpty);
    });

    test(
      'reconcile forgets only that repo\'s worktrees that are gone',
      () async {
        await metadata.updateAll('/r', [
          '/w/live',
          '/w/gone',
        ], (m) => m.copyWith(baseBranch: 'develop'));
        await metadata.update(
          '/other',
          '/x/kept',
          (m) => m.copyWith(hidden: true),
        );

        await metadata.reconcile('/r', {'/w/live'});

        expect(
          [for (final m in await store.loadAll()) m.path],
          ['/w/live', '/x/kept'],
        );
        expect(metadata.forRepo('/r').map((m) => m.path), ['/w/live']);
      },
    );

    test('lists sessions and Jira issues across repos', () async {
      await metadata.update(
        '/r',
        '/w/a',
        (m) => m.copyWith(
          jiraIssue: 'AU2-1',
          session: const RememberedSession(promptId: 'Verify'),
        ),
      );
      await metadata.update('/r', '/w/b', (m) => m.copyWith(hidden: true));
      await metadata.update(
        '/other',
        '/x/c',
        (m) => m.copyWith(jiraIssue: 'AU2-9'),
      );

      expect(metadata.sessionsFor('/r').map((m) => m.path), ['/w/a']);
      expect(metadata.jiraIssueKeys, {'AU2-1', 'AU2-9'});
    });
  });

  group('WorkspaceController worktree metadata', () {
    late _FakeGit git;
    late WorktreeMetadataStore store;
    late WorkspaceController workspace;

    setUp(() async {
      git = _FakeGit(['/w/main', '/w/old']);
      store = WorktreeMetadataStore(testDatabase());
      await store.saveAll([
        const WorktreeMetadata(
          path: '/w/old',
          repoPath: '/repos/demo',
          jiraIssue: 'AU2-1',
          hidden: true,
        ),
        const WorktreeMetadata(
          path: '/w/stale',
          repoPath: '/repos/demo',
          baseBranch: 'develop',
        ),
      ]);
      workspace = WorkspaceController(
        gitService: git,
        repoConfigStore: FakeRepoConfigStore([
          RepoConfig(name: 'demo', path: '/repos/demo'),
        ]),
        eventStore: WorktreeEventStore(testDatabase()),
        metadataStore: store,
      );
      addTearDown(workspace.dispose);
      await workspace.loadRepos();
    });

    test('applies the metadata to the listed worktrees', () {
      final old = workspace.worktrees.firstWhere((w) => w.path == '/w/old');
      expect(old.jiraIssue, 'AU2-1');
      expect(old.isHidden, isTrue);
    });

    test('clearing a Jira issue shows at once', () async {
      await workspace.updateJiraIssue('/w/old', null);
      final old = workspace.worktrees.firstWhere((w) => w.path == '/w/old');
      expect(old.jiraIssue, isNull);
      expect(old.isHidden, isTrue);
    });

    test('a refresh forgets the worktrees that are gone', () async {
      await workspace.refreshWorktrees();
      expect([for (final m in await store.loadAll()) m.path], ['/w/old']);
    });

    test('deleting a worktree forgets it in one go', () async {
      final old = workspace.worktrees.firstWhere((w) => w.path == '/w/old');
      await workspace.deleteWorktree(old);
      expect(workspace.metadataFor('/w/old'), isNull);
      expect([
        for (final m in await store.loadAll()) m.path,
      ], isNot(contains('/w/old')));
    });

    test('two worktrees created at once keep both their metadata', () async {
      git.gate = Completer<void>();
      final a = workspace.createWorktree(
        repoName: 'demo',
        worktreeName: 'a',
        baseBranch: 'develop',
        newBranch: 'sen/a',
        jiraIssue: 'AU2-10',
        kickoffPrompt: '# Plan A',
      );
      final b = workspace.createWorktree(
        repoName: 'demo',
        worktreeName: 'b',
        baseBranch: 'main',
        newBranch: 'sen/b',
        jiraIssue: 'AU2-11',
      );
      git.gate!.complete();
      final created = await Future.wait([a, b]);

      expect(
        created.first.kickoffPromptPath,
        '/w/a/.tree-launcher/kickoff-prompt.md',
      );
      final saved = {for (final m in await store.loadAll()) m.path: m};
      expect(saved['/w/a']!.jiraIssue, 'AU2-10');
      expect(saved['/w/a']!.baseBranch, 'develop');
      expect(saved['/w/b']!.jiraIssue, 'AU2-11');
      expect(saved['/w/b']!.baseBranch, 'main');
    });
  });

  group('moving the metadata out of config.json', () {
    late Directory dir;
    late String path;
    late ConfigFile file;
    late WorktreeMetadataStore store;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('worktree_metadata_import');
      path = p.join(dir.path, 'config.json');
      file = ConfigFile(path: path);
      store = WorktreeMetadataStore(testDatabase());
    });

    tearDown(() => dir.delete(recursive: true));

    Future<void> writeConfig(List<Map<String, dynamic>> repos) =>
        File(path).writeAsString(jsonEncode({'repos': repos, 'settings': {}}));

    Map<String, dynamic> legacyRepo() => {
      'name': 'demo',
      'path': '/repos/demo',
      'jiraIssues': {'/w/a': 'AU2-1', '/w/gone': 'AU2-2', '/w/bad': 7},
      'githubIssues': {'/w/a': 12, '/w/b': 'nope'},
      'baseBranches': {'/w/a': 'develop', '/w/gone': 'main'},
      'prAuthors': {'/w/b': 'kim'},
      'kickoffPrompts': {'/w/b': '/w/b/k.md'},
      'hiddenWorktrees': ['/w/b', 42],
      'snoozedWorktrees': ['/w/a'],
      'claudeSessions': ['/w/b', '/w/a', '/w/b', null],
      'claudeSessionPrompts': {'/w/a': 'Verify'},
      'claudeSessionStarts': {'/w/a': '2026-10-19T09:30:00.000'},
    };

    test('reads every kind of per-worktree key, skipping bad values', () {
      final entries = {
        for (final m in legacyWorktreeMetadata(legacyRepo())) m.path: m,
      };
      // Sessions first, in the order remembered.
      expect(entries.keys.take(2), ['/w/b', '/w/a']);
      final a = entries['/w/a']!;
      expect(a.repoPath, '/repos/demo');
      expect(a.jiraIssue, 'AU2-1');
      expect(a.githubIssue, 12);
      expect(a.baseBranch, 'develop');
      expect(a.snoozed, isTrue);
      expect(a.session!.promptId, 'Verify');
      expect(a.session!.startedAt, DateTime(2026, 10, 19, 9, 30));
      final b = entries['/w/b']!;
      expect(b.githubIssue, isNull);
      expect(b.prAuthor, 'kim');
      expect(b.kickoffPromptPath, '/w/b/k.md');
      expect(b.hidden, isTrue);
      expect(b.session!.startedAt, isNull);
      expect(entries['/w/bad'], isNull);
    });

    test('imports the worktrees that still exist and drops the keys', () async {
      await writeConfig([legacyRepo()]);

      await WorktreeMetadataLegacyImport(
        configFile: file,
        store: store,
        exists: (path) => path != '/w/gone',
      ).run();

      expect([for (final m in await store.loadAll()) m.path], ['/w/b', '/w/a']);
      final repo = ((await file.read())['repos'] as List).single as Map;
      expect(repo.keys, unorderedEquals(['name', 'path']));

      // Nothing left to move: a second run changes nothing.
      await store.delete(['/w/a']);
      await WorktreeMetadataLegacyImport(configFile: file, store: store).run();
      expect([for (final m in await store.loadAll()) m.path], ['/w/b']);
    });

    test('leaves the file alone when the import fails', () async {
      await writeConfig([legacyRepo()]);
      final before = await File(path).readAsString();

      await WorktreeMetadataLegacyImport(
        configFile: file,
        store: _FailingStore(),
        exists: (_) => true,
      ).run();

      expect(await File(path).readAsString(), before);
    });

    test('a repo save keeps the keys until they have been moved', () async {
      await writeConfig([legacyRepo()]);
      final repos = RepoConfigStore(
        configFile: file,
        tokenStore: MemoryGithubTokenStore(),
      );

      await repos.save([(await repos.load()).single.copyWith(name: 'renamed')]);

      final repo = ((await file.read())['repos'] as List).single as Map;
      expect(repo['name'], 'renamed');
      expect(repo['jiraIssues'], {
        '/w/a': 'AU2-1',
        '/w/gone': 'AU2-2',
        '/w/bad': 7,
      });
      expect(repo['claudeSessions'], ['/w/b', '/w/a', '/w/b', null]);
    });
  });
}

/// A store whose import always fails, like a database that can't be written.
class _FailingStore implements WorktreeMetadataStore {
  @override
  Future<void> importLegacy(Iterable<WorktreeMetadata> entries) =>
      Future.error(StateError('disk full'));

  @override
  Future<List<WorktreeMetadata>> loadAll() async => const [];

  @override
  Future<void> saveAll(Iterable<WorktreeMetadata> entries) async {}

  @override
  Future<void> delete(Iterable<String> paths) async {}
}
