import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tree_launcher/features/workspace/data/git_service.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_status.dart';

void main() {
  group('WorktreeStatus.parse', () {
    test('reads the branch headers and counts the changes', () {
      final status = WorktreeStatus.parse(
        [
          '# branch.oid 0123456789abcdef0123456789abcdef01234567',
          '# branch.head feature/au2-1',
          '# branch.upstream origin/feature/au2-1',
          '# branch.ab +2 -1',
          '1 M. N... 100644 100644 100644 aaa bbb lib/a.dart',
          '1 .M N... 100644 100644 100644 aaa bbb lib/b.dart',
          '1 MM N... 100644 100644 100644 aaa bbb lib/c.dart',
          '2 R. N... 100644 100644 100644 aaa bbb R100 lib/d.dart\tlib/e.dart',
          'u UU N... 100644 100644 100644 100644 aaa bbb ccc lib/f.dart',
          '? notes.md',
          '? .factory/spec.md',
          '! build/',
        ].join('\n'),
      );

      expect(status.branch, 'feature/au2-1');
      expect(status.shortCommit, '01234567');
      expect(status.upstream, 'origin/feature/au2-1');
      expect(status.aheadOfUpstream, 2);
      expect(status.behindUpstream, 1);
      expect(status.staged, 3);
      expect(status.modified, 2);
      expect(status.conflicted, 1);
      expect(status.untracked, 2);
      expect(status.changedFiles, 8);
    });

    test('knows a detached HEAD, a first commit and no upstream', () {
      final status = WorktreeStatus.parse(
        '# branch.oid (initial)\n# branch.head (detached)\n',
      );

      expect(status.branch, isNull);
      expect(status.commit, isNull);
      expect(status.upstream, isNull);
      expect(status.changedFiles, 0);
    });
  });

  group('GitService.worktreeStatus', () {
    const git = '/usr/bin/git';
    final hasGit = File(git).existsSync();
    late Directory root;

    Future<void> run(List<String> args, String cwd) async {
      final result = await Process.run(git, args, workingDirectory: cwd);
      if (result.exitCode != 0) {
        throw Exception('git ${args.join(' ')} failed: ${result.stderr}');
      }
    }

    Future<void> commit(String repo, String name, String message) async {
      File(p.join(repo, name)).writeAsStringSync(message);
      await run(['add', '.'], repo);
      await run(['commit', '-m', message], repo);
    }

    setUp(() => root = Directory.systemTemp.createTempSync('tl_status_test'));
    tearDown(() => root.deleteSync(recursive: true));

    test(
      'compares the branch with its base and reads the changes',
      () async {
        final repo = root.path;
        await run(['init', '-b', 'develop'], repo);
        await run(['config', 'user.email', 'test@example.com'], repo);
        await run(['config', 'user.name', 'Test'], repo);
        await commit(repo, 'a.txt', 'base');
        await run(['checkout', '-b', 'feature'], repo);
        await commit(repo, 'b.txt', 'one');
        await commit(repo, 'c.txt', 'two');
        await run(['checkout', 'develop'], repo);
        await commit(repo, 'd.txt', 'on develop');
        await run(['checkout', 'feature'], repo);
        File(p.join(repo, 'a.txt')).writeAsStringSync('changed');
        File(p.join(repo, 'new.txt')).writeAsStringSync('new');

        final status = await GitService().worktreeStatus(
          repo,
          baseBranch: 'develop',
        );

        expect(status.branch, 'feature');
        expect(status.subject, 'two');
        expect(status.base, 'develop');
        expect(status.aheadOfBase, 2);
        expect(status.behindBase, 1);
        expect(status.modified, 1);
        expect(status.untracked, 1);
        expect(status.upstream, isNull);
      },
      skip: hasGit ? false : 'needs /usr/bin/git',
    );

    test(
      'leaves the base comparison out when the base is not found',
      () async {
        final repo = root.path;
        await run(['init', '-b', 'main'], repo);
        await run(['config', 'user.email', 'test@example.com'], repo);
        await run(['config', 'user.name', 'Test'], repo);
        await commit(repo, 'a.txt', 'base');

        final status = await GitService().worktreeStatus(
          repo,
          baseBranch: 'develop',
        );

        expect(status.branch, 'main');
        expect(status.base, isNull);
        expect(status.aheadOfBase, isNull);
      },
      skip: hasGit ? false : 'needs /usr/bin/git',
    );
  });
}
