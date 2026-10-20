import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tree_launcher/features/session_panel/data/worktree_file_system.dart';
import 'package:tree_launcher/features/session_panel/domain/file_entry.dart';
import 'package:tree_launcher/features/session_panel/presentation/controllers/worktree_files_controller.dart';
import 'package:tree_launcher/features/workspace/data/git_service.dart';

/// Lists the real disk; changes come from [events] instead of a watcher.
class _ControlledFileSystem extends WorktreeFileSystem {
  final events = StreamController<String>.broadcast();
  int watching = 0;

  @override
  Stream<String> watch(String root) {
    watching++;
    return events.stream;
  }
}

class _FakeGit extends GitService {
  _FakeGit(this.ignored);

  Set<String> ignored;

  @override
  Future<Set<String>> ignoredPaths(String worktreePath) async => ignored;
}

void main() {
  group('isIgnoredPath', () {
    const ignored = {'build/', '.factory/', 'lib/generated.g.dart'};

    test('matches ignored files, folders and what is in them', () {
      expect(isIgnoredPath('build', ignored), isTrue);
      expect(isIgnoredPath('build/app/x.o', ignored), isTrue);
      expect(isIgnoredPath('.factory/spec.md', ignored), isTrue);
      expect(isIgnoredPath('lib/generated.g.dart', ignored), isTrue);
    });

    test('leaves the rest alone', () {
      expect(isIgnoredPath('lib', ignored), isFalse);
      expect(isIgnoredPath('lib/main.dart', ignored), isFalse);
      expect(isIgnoredPath('builder/x', ignored), isFalse);
      expect(isIgnoredPath('anything', const {}), isFalse);
    });
  });

  test('compareEntries puts folders first, then by name ignoring case', () {
    final entries = [
      const FileEntry(path: '/r/b.txt', isDirectory: false),
      const FileEntry(path: '/r/Zoo', isDirectory: true),
      const FileEntry(path: '/r/A.txt', isDirectory: false),
      const FileEntry(path: '/r/.factory', isDirectory: true),
    ]..sort(compareEntries);

    expect(entries.map((e) => e.name), ['.factory', 'Zoo', 'A.txt', 'b.txt']);
  });

  group('WorktreeFilesController', () {
    late Directory root;
    late _ControlledFileSystem fs;
    late _FakeGit git;
    late WorktreeFilesController files;

    void write(String relative, [String content = '']) {
      File(p.join(root.path, relative))
        ..createSync(recursive: true)
        ..writeAsStringSync(content);
    }

    List<String> visible() => [
      for (final row in files.rows)
        '${'  ' * row.depth}${row.entry.name}${row.entry.isDirectory ? '/' : ''}'
            '${row.ignored ? ' (ignored)' : ''}',
    ];

    Future<void> settle() async {
      for (var i = 0; i < 5; i++) {
        await pumpEventQueue();
      }
    }

    setUp(() {
      root = Directory.systemTemp.createTempSync('tl_files_test');
      write('.git', 'gitdir: /elsewhere');
      write('.DS_Store');
      write('README.md');
      write('lib/main.dart');
      write('.factory/spec.md');
      write('build/app.o');
      fs = _ControlledFileSystem();
      git = _FakeGit({'build/', '.factory/'});
      files = WorktreeFilesController(
        root: root.path,
        git: git,
        fileSystem: fs,
        debounce: Duration.zero,
      );
    });

    tearDown(() {
      files.dispose();
      root.deleteSync(recursive: true);
    });

    test('shows everything but .git, dims ignored entries and opens '
        '.factory', () async {
      expect(files.isLoading, isTrue);
      files.attach();
      await settle();

      expect(files.isLoading, isFalse);
      expect(visible(), [
        '.factory/ (ignored)',
        '  spec.md (ignored)',
        'build/ (ignored)',
        'lib/',
        'README.md',
      ]);
    });

    test('reads a folder when it is opened and keeps it when closed', () async {
      files.attach();
      await settle();

      await files.toggle(p.join(root.path, 'lib'));
      expect(visible(), contains('  main.dart'));

      files.collapseAll();
      expect(visible(), isNot(contains('  main.dart')));
      expect(files.isExpanded(p.join(root.path, 'lib')), isFalse);
    });

    test('reads changed folders again and reports the changes', () async {
      files.attach();
      await settle();
      await files.expand(p.join(root.path, 'lib'));
      final reported = <Set<String>>[];
      final sub = files.changes.listen(reported.add);

      write('lib/new.dart');
      fs.events.add(p.join(root.path, 'lib/new.dart'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await settle();

      expect(visible(), contains('  new.dart'));
      expect(reported, [
        {p.join(root.path, 'lib/new.dart')},
      ]);
      await sub.cancel();
    });

    test('forgets an open folder that is deleted', () async {
      files.attach();
      await settle();
      await files.expand(p.join(root.path, 'lib'));

      Directory(p.join(root.path, 'lib')).deleteSync(recursive: true);
      fs.events.add(p.join(root.path, 'lib'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await settle();

      expect(visible(), isNot(contains('lib/')));
      expect(files.isExpanded(p.join(root.path, 'lib')), isFalse);
    });

    test('watches only while attached, and catches up when attached '
        'again', () async {
      files.attach();
      await settle();
      files.detach();

      write('later.txt');
      files.attach();
      await settle();

      expect(fs.watching, 2);
      expect(visible(), contains('later.txt'));
    });

    test('shows why the worktree cannot be read', () async {
      final missing = WorktreeFilesController(
        root: p.join(root.path, 'missing'),
        git: git,
        fileSystem: fs,
      );
      missing.attach();
      await settle();

      expect(missing.error, isNotNull);
      expect(missing.isLoading, isFalse);
      missing.dispose();
    });
  });

  group('GitService.ignoredPaths', () {
    const gitBinary = '/usr/bin/git';
    final hasGit = File(gitBinary).existsSync();

    test(
      'lists ignored files and whole ignored folders',
      () async {
        final repo = Directory.systemTemp.createTempSync('tl_ignored_test');
        addTearDown(() => repo.deleteSync(recursive: true));
        await Process.run(gitBinary, ['init'], workingDirectory: repo.path);
        void write(String relative) => File(p.join(repo.path, relative))
          ..createSync(recursive: true)
          ..writeAsStringSync('x');
        write('.gitignore');
        File(
          p.join(repo.path, '.gitignore'),
        ).writeAsStringSync('build/\n*.log\n.factory/\n');
        write('build/a/b.o');
        write('debug.log');
        write('.factory/spec.md');
        write('lib/main.dart');

        final ignored = await GitService().ignoredPaths(repo.path);

        expect(ignored, {'build/', 'debug.log', '.factory/'});
      },
      skip: hasGit ? false : 'needs /usr/bin/git',
    );
  });
}
