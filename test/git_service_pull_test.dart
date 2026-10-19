import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tree_launcher/features/workspace/data/git_service.dart';

/// These tests drive real `git` against temporary repos, so they only run when
/// a git binary is available.
void main() {
  const git = '/usr/bin/git';
  final hasGit = File(git).existsSync();

  Future<ProcessResult> run(
    List<String> args, {
    required String cwd,
  }) async {
    final result = await Process.run(git, args, workingDirectory: cwd);
    if (result.exitCode != 0) {
      throw Exception('git ${args.join(' ')} failed: ${result.stderr}');
    }
    return result;
  }

  Future<void> commitFile(
    String repo,
    String name,
    String content,
    String message,
  ) async {
    File(p.join(repo, name)).writeAsStringSync(content);
    await run(['add', '.'], cwd: repo);
    await run(['commit', '-m', message], cwd: repo);
  }

  /// Creates a "remote" repo with one commit plus a clone that tracks it, and
  /// returns (sourcePath, clonePath). The clone's branch has a real upstream.
  Future<(String, String)> initSourceAndClone(Directory root) async {
    final source = Directory(p.join(root.path, 'source'))..createSync();
    await run(['init'], cwd: source.path);
    await run(['config', 'user.email', 'test@example.com'], cwd: source.path);
    await run(['config', 'user.name', 'Test'], cwd: source.path);
    await commitFile(source.path, 'README.md', 'hi', 'init');

    final clonePath = p.join(root.path, 'clone');
    await run(['clone', source.path, clonePath], cwd: root.path);
    await run(['config', 'user.email', 'test@example.com'], cwd: clonePath);
    await run(['config', 'user.name', 'Test'], cwd: clonePath);
    return (source.path, clonePath);
  }

  late Directory tempRoot;
  late GitService service;

  setUp(() {
    tempRoot = Directory.systemTemp.createTempSync('tl_pull_test');
    service = GitService();
  });

  tearDown(() {
    if (tempRoot.existsSync()) {
      tempRoot.deleteSync(recursive: true);
    }
  });

  test('fast-forwards when the upstream has new commits', () async {
    if (!hasGit) {
      markTestSkipped('git not available');
      return;
    }
    final (source, clone) = await initSourceAndClone(tempRoot);
    await commitFile(source, 'feature.txt', 'new', 'add feature');

    final result = await service.pullCurrentBranch(clone);

    expect(result.updated, isTrue);
    expect(result.commits, 1);
    expect(File(p.join(clone, 'feature.txt')).existsSync(), isTrue);
  });

  test('reports already up to date when nothing to pull', () async {
    if (!hasGit) {
      markTestSkipped('git not available');
      return;
    }
    final (_, clone) = await initSourceAndClone(tempRoot);

    final result = await service.pullCurrentBranch(clone);

    expect(result.updated, isFalse);
    expect(result.commits, 0);
  });

  test('throws on uncommitted changes', () async {
    if (!hasGit) {
      markTestSkipped('git not available');
      return;
    }
    final (source, clone) = await initSourceAndClone(tempRoot);
    await commitFile(source, 'feature.txt', 'new', 'add feature');
    // Dirty the working tree in the clone.
    File(p.join(clone, 'README.md')).writeAsStringSync('local edit');

    expect(
      () => service.pullCurrentBranch(clone),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('uncommitted changes'),
        ),
      ),
    );
  });

  test('throws when the branch has diverged', () async {
    if (!hasGit) {
      markTestSkipped('git not available');
      return;
    }
    final (source, clone) = await initSourceAndClone(tempRoot);
    // Commit on both sides so neither is a fast-forward of the other.
    await commitFile(source, 'remote.txt', 'r', 'remote commit');
    await commitFile(clone, 'local.txt', 'l', 'local commit');

    expect(
      () => service.pullCurrentBranch(clone),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('diverged'),
        ),
      ),
    );
  });

  test('throws when the branch has no upstream', () async {
    if (!hasGit) {
      markTestSkipped('git not available');
      return;
    }
    final repo = Directory(p.join(tempRoot.path, 'standalone'))..createSync();
    await run(['init'], cwd: repo.path);
    await run(['config', 'user.email', 'test@example.com'], cwd: repo.path);
    await run(['config', 'user.name', 'Test'], cwd: repo.path);
    await commitFile(repo.path, 'README.md', 'hi', 'init');

    expect(
      () => service.pullCurrentBranch(repo.path),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('no upstream'),
        ),
      ),
    );
  });
}
