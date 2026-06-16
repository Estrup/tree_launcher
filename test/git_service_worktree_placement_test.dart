import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tree_launcher/features/workspace/data/git_service.dart';

/// These tests drive real `git` against temporary repos, so they only run when
/// a git binary is available.
void main() {
  const git = '/usr/bin/git';
  final hasGit = File(git).existsSync();

  Future<void> run(
    List<String> args, {
    required String cwd,
  }) async {
    final result = await Process.run(git, args, workingDirectory: cwd);
    if (result.exitCode != 0) {
      throw Exception('git ${args.join(' ')} failed: ${result.stderr}');
    }
  }

  /// Creates a normal repo with one commit and returns its path.
  Future<String> initRepoWithCommit(Directory root) async {
    final repo = Directory(p.join(root.path, 'repo'))..createSync();
    await run(['init'], cwd: repo.path);
    await run(['config', 'user.email', 'test@example.com'], cwd: repo.path);
    await run(['config', 'user.name', 'Test'], cwd: repo.path);
    File(p.join(repo.path, 'README.md')).writeAsStringSync('hi');
    await run(['add', '.'], cwd: repo.path);
    await run(['commit', '-m', 'init'], cwd: repo.path);
    return repo.path;
  }

  late Directory tempRoot;
  late GitService service;

  setUp(() {
    tempRoot = Directory.systemTemp.createTempSync('tl_worktree_test');
    service = GitService();
  });

  tearDown(() {
    if (tempRoot.existsSync()) {
      tempRoot.deleteSync(recursive: true);
    }
  });

  test('default (flag off) places worktree as a sibling', () async {
    if (!hasGit) {
      markTestSkipped('git not available');
      return;
    }
    final repoPath = await initRepoWithCommit(tempRoot);

    final path = await service.addWorktree(
      repoPath,
      'feat-x',
      newBranch: 'feat-x',
    );

    expect(path, p.join(p.dirname(repoPath), 'feat-x'));
    expect(Directory(path).existsSync(), isTrue);
    expect(
      Directory(p.join(repoPath, '.worktrees')).existsSync(),
      isFalse,
    );
  });

  test('flag on (non-bare) nests in .worktrees/ and writes exclude', () async {
    if (!hasGit) {
      markTestSkipped('git not available');
      return;
    }
    final repoPath = await initRepoWithCommit(tempRoot);

    final path = await service.addWorktree(
      repoPath,
      'feat-x',
      newBranch: 'feat-x',
      useNestedWorktrees: true,
    );

    expect(path, p.join(repoPath, '.worktrees', 'feat-x'));
    expect(Directory(path).existsSync(), isTrue);

    final exclude = File(p.join(repoPath, '.git', 'info', 'exclude'));
    expect(exclude.existsSync(), isTrue);
    expect(exclude.readAsStringSync(), contains('.worktrees/'));
  });

  test('exclude entry is idempotent across multiple worktrees', () async {
    if (!hasGit) {
      markTestSkipped('git not available');
      return;
    }
    final repoPath = await initRepoWithCommit(tempRoot);

    await service.addWorktree(repoPath, 'a',
        newBranch: 'a', useNestedWorktrees: true);
    await service.addWorktree(repoPath, 'b',
        newBranch: 'b', useNestedWorktrees: true);

    final exclude = File(p.join(repoPath, '.git', 'info', 'exclude'));
    final count = exclude
        .readAsLinesSync()
        .map((l) => l.trim())
        .where((l) => l == '.worktrees/')
        .length;
    expect(count, 1);
  });

  test('bare repo ignores the flag and uses sibling layout', () async {
    if (!hasGit) {
      markTestSkipped('git not available');
      return;
    }
    // Make a normal repo first so we have something to clone --bare.
    final src = await initRepoWithCommit(tempRoot);
    final barePath = p.join(tempRoot.path, 'bare.git');
    await run(['clone', '--bare', src, barePath], cwd: tempRoot.path);

    final path = await service.addWorktree(
      barePath,
      'feat-x',
      useNestedWorktrees: true,
    );

    expect(path, p.join(p.dirname(barePath), 'feat-x'));
    expect(
      Directory(p.join(barePath, '.worktrees')).existsSync(),
      isFalse,
    );
  });

  test('nested worktree is still discovered by getWorktrees', () async {
    if (!hasGit) {
      markTestSkipped('git not available');
      return;
    }
    final repoPath = await initRepoWithCommit(tempRoot);

    final path = await service.addWorktree(
      repoPath,
      'feat-x',
      newBranch: 'feat-x',
      useNestedWorktrees: true,
    );

    final result = await service.getWorktrees(repoPath);
    // git canonicalizes paths (e.g. /var -> /private/var on macOS), so match on
    // the nested suffix rather than the exact absolute path.
    final suffix = p.join('.worktrees', 'feat-x');
    expect(
      result.worktrees.any((w) => w.path.endsWith(suffix)),
      isTrue,
      reason: 'expected a worktree under $suffix in ${result.worktrees}',
    );
  });
}
