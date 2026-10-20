import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:tree_launcher/features/session_panel/data/worktree_file_system.dart';
import 'package:tree_launcher/features/session_panel/domain/file_entry.dart';
import 'package:tree_launcher/features/session_panel/domain/file_filter.dart';
import 'package:tree_launcher/features/session_panel/presentation/controllers/session_panel_controller.dart';
import 'package:tree_launcher/features/session_panel/presentation/controllers/worktree_files_controller.dart';
import 'package:tree_launcher/features/session_panel/presentation/widgets/worktree_files_tab.dart';
import 'package:tree_launcher/features/workspace/data/git_service.dart';

const _root = '/w';

FileEntry _dir(String relative) =>
    FileEntry(path: '$_root/$relative', isDirectory: true);
FileEntry _file(String relative) =>
    FileEntry(path: '$_root/$relative', isDirectory: false);

/// The worktree `/w`, held in memory.
final _all = [
  _dir('lib'),
  _dir('lib/widgets'),
  _file('lib/main.dart'),
  _file('lib/widgets/spec_view.dart'),
  _dir('.factory'),
  _file('.factory/spec.md'),
  _file('.factory/plan.md'),
  _dir('docs'),
  _dir('docs/specs'),
  _file('docs/specs/a.md'),
  _file('README.md'),
];

/// Lists and walks [_all]; changes come from [events].
class _MemoryFileSystem extends WorktreeFileSystem {
  _MemoryFileSystem();

  final events = StreamController<String>.broadcast();
  int walks = 0;

  @override
  Future<List<FileEntry>> list(String directory) async => [
    for (final entry in _all)
      if (p.dirname(entry.path) == directory) entry,
  ]..sort(compareEntries);

  @override
  Future<WalkResult> walk(
    String root, {
    Set<String> include = const {},
    int limit = WorktreeFileSystem.walkLimit,
  }) async {
    walks++;
    return WalkResult(_all, truncated: false);
  }

  @override
  Stream<String> watch(String root) => events.stream;
}

class _FakeGit extends GitService {
  @override
  Future<Set<String>> ignoredPaths(String worktreePath) async => {'.factory/'};
}

/// The entry named [name] in the tree (not the filter box).
Finder inTree(String name) => find.descendant(
  of: find.byType(ListView),
  matching: find.text(name, findRichText: true),
);

List<String> _lines(List<FilteredEntry> hits) => [
  for (final hit in hits)
    '${'  ' * hit.depth}${hit.entry.name}${hit.isMatch ? ' *' : ''}',
];

void main() {
  group('matchesFilter', () {
    test('matches names, ignoring case', () {
      expect(matchesFilter('lib/widgets/spec_view.dart', 'SPEC'), isTrue);
      expect(matchesFilter('lib/widgets/spec_view.dart', 'widgets'), isFalse);
      expect(matchesFilter('lib/widgets', 'widgets'), isTrue);
      expect(matchesFilter('lib/main.dart', '   '), isFalse);
    });

    test('matches paths when the filter has a slash', () {
      expect(matchesFilter('lib/widgets/spec_view.dart', 'widgets/'), isTrue);
      expect(matchesFilter('.factory/spec.md', '.factory/sp'), isTrue);
      expect(matchesFilter('docs/specs/a.md', 'lib/'), isFalse);
    });
  });

  test('filterTree shows matches under their folders, sorted', () {
    expect(_lines(filterTree(_root, _all, 'spec')), [
      '.factory',
      '  spec.md *',
      'docs',
      '  specs *',
      'lib',
      '  widgets',
      '    spec_view.dart *',
    ]);
  });

  test('filterTree shows what is in a matching folder only when it '
      'matches', () {
    expect(_lines(filterTree(_root, _all, 'a')), [
      '.factory *',
      '  plan.md *',
      'docs',
      '  specs',
      '    a.md *',
      'lib',
      '  widgets',
      '    spec_view.dart *',
      '  main.dart *',
      'README.md *',
    ]);
    expect(filterTree(_root, _all, 'nothing'), isEmpty);
  });

  group('WorktreeFileSystem.walk', () {
    late Directory root;

    setUp(() => root = Directory.systemTemp.createTempSync('tl_walk_test'));
    tearDown(() => root.deleteSync(recursive: true));

    void write(String relative) => File(p.join(root.path, relative))
      ..createSync(recursive: true)
      ..writeAsStringSync('x');

    List<String> relative(WalkResult result) =>
        [for (final e in result.entries) p.relative(e.path, from: root.path)]
          ..sort();

    test('lists everything but .git, and stays out of dependency folders '
        'unless included', () async {
      write('.git/HEAD');
      write('.factory/spec.md');
      write('node_modules/pkg/index.js');
      write('src/app.ts');

      final walked = await const WorktreeFileSystem().walk(root.path);
      expect(relative(walked), [
        '.factory',
        '.factory/spec.md',
        'node_modules',
        'src',
        'src/app.ts',
      ]);
      expect(walked.truncated, isFalse);

      final included = await const WorktreeFileSystem().walk(
        root.path,
        include: {p.join(root.path, 'node_modules')},
      );
      expect(relative(included), contains('node_modules/pkg/index.js'));
    });

    test('stops at its limit', () async {
      for (var i = 0; i < 10; i++) {
        write('f$i.txt');
      }

      final walked = await const WorktreeFileSystem().walk(root.path, limit: 4);

      expect(walked.entries, hasLength(4));
      expect(walked.truncated, isTrue);
    });
  });

  group('WorktreeFilesController filter', () {
    late _MemoryFileSystem fs;
    late WorktreeFilesController files;

    setUp(() {
      fs = _MemoryFileSystem();
      files = WorktreeFilesController(
        root: _root,
        git: _FakeGit(),
        fileSystem: fs,
        debounce: Duration.zero,
      );
    });

    tearDown(() => files.dispose());

    List<String> visible() => [
      for (final row in files.rows) '${'  ' * row.depth}${row.entry.name}',
    ];

    test('walks once, filters the rows, and gives the tree back as it '
        'was', () async {
      files.attach();
      await pumpEventQueue();
      final before = visible();

      files.setFilter('plan');
      expect(files.isWalking, isTrue);
      await pumpEventQueue();
      expect(visible(), ['.factory', '  plan.md']);
      expect(files.matchCount, 1);
      expect(files.rows.first.ignored, isTrue);

      files.setFilter('main');
      await pumpEventQueue();
      expect(visible(), ['lib', '  main.dart']);
      expect(fs.walks, 1);

      files.setFilter('');
      expect(visible(), before);
    });

    test('reveal ends the filter and opens the folders on the way', () async {
      files.attach();
      await pumpEventQueue();
      files.setFilter('spec_view');
      await pumpEventQueue();

      await files.reveal('/w/lib/widgets/spec_view.dart', isDirectory: false);

      expect(files.isFiltering, isFalse);
      expect(files.isExpanded('/w/lib'), isTrue);
      expect(files.isExpanded('/w/lib/widgets'), isTrue);
      expect(visible(), contains('    spec_view.dart'));
    });

    test('walks again after a change on disk', () async {
      files.attach();
      await pumpEventQueue();
      files.setFilter('spec');
      await pumpEventQueue();

      fs.events.add('/w/lib/new_spec.dart');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await pumpEventQueue();

      expect(fs.walks, 2);
    });
  });

  testWidgets('the Files tab filters as you type, and Escape clears it', (
    tester,
  ) async {
    final panel = SessionPanelController(
      git: _FakeGit(),
      fileSystem: _MemoryFileSystem(),
    );
    addTearDown(panel.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: panel,
        child: const MaterialApp(
          home: Scaffold(body: WorktreeFilesTab(worktree: _root)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    // .factory opens by itself.
    expect(inTree('spec.md'), findsOneWidget);
    expect(inTree('a.md'), findsNothing);

    await tester.enterText(find.byType(TextField), 'a.md');
    await tester.pump();
    await tester.pump();
    expect(find.text('1 match'), findsOneWidget);
    expect(inTree('a.md'), findsOneWidget);
    expect(inTree('README.md'), findsNothing);

    // A folder in the matches shows it in the whole tree.
    await tester.tap(inTree('specs'));
    await tester.pump();
    await tester.pump();
    expect(find.text('1 match'), findsNothing);
    expect(inTree('README.md'), findsOneWidget);
    expect(inTree('a.md'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'readme');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('No matches'), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });
}
