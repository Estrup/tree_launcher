import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:tree_launcher/features/session_panel/data/worktree_file_system.dart';
import 'package:tree_launcher/features/session_panel/domain/file_content.dart';
import 'package:tree_launcher/features/session_panel/domain/file_entry.dart';
import 'package:tree_launcher/features/session_panel/presentation/controllers/session_panel_controller.dart';
import 'package:tree_launcher/features/session_panel/presentation/widgets/file_tab_view.dart';
import 'package:tree_launcher/features/workspace/data/git_service.dart';

/// Files held in memory, since real file reads don't complete under a
/// widget test's fake async. Changes come from [events].
class _MemoryFileSystem extends WorktreeFileSystem {
  _MemoryFileSystem(this.files);

  final Map<String, FileContent> files;
  final events = StreamController<String>.broadcast();

  @override
  Future<List<FileEntry>> list(String directory) async => const [];

  @override
  Future<FileContent> readText(String path) async =>
      files[path] ?? (throw FileSystemException('The file is gone', path));

  @override
  Stream<String> watch(String root) => events.stream;
}

class _FakeGit extends GitService {
  @override
  Future<Set<String>> ignoredPaths(String worktreePath) async => const {};
}

void main() {
  group('WorktreeFileSystem.readText', () {
    late Directory dir;
    const fs = WorktreeFileSystem();

    setUp(() => dir = Directory.systemTemp.createTempSync('tl_read_test'));
    tearDown(() => dir.deleteSync(recursive: true));

    String write(String name, List<int> bytes) {
      final path = p.join(dir.path, name);
      File(path).writeAsBytesSync(bytes);
      return path;
    }

    test('reads text, and tells binary and too large files apart', () async {
      final text = write('a.txt', utf8.encode('æ\r\nb\n'));
      final binary = write('b.bin', [0x89, 0x50, 0x00, 0x47]);
      final large = write(
        'c.log',
        List.filled(WorktreeFileSystem.maxTextBytes + 1, 0x61),
      );

      final content = await fs.readText(text);
      expect(content, isA<TextFileContent>());
      expect((content as TextFileContent).lines, ['æ', 'b']);
      expect(await fs.readText(binary), isA<BinaryFileContent>());
      expect(
        (await fs.readText(large) as TooLargeFileContent).sizeBytes,
        WorktreeFileSystem.maxTextBytes + 1,
      );
    });

    test('keeps a file without a final line break whole', () {
      expect(const TextFileContent('a\nb').lines, ['a', 'b']);
      expect(const TextFileContent('').lines, ['']);
      expect(const TextFileContent('a\n\n').lines, ['a', '']);
    });
  });

  test('FileViewKind picks the view by extension', () {
    expect(FileViewKind.forPath('/w/.factory/spec.md'), FileViewKind.markdown);
    expect(FileViewKind.forPath('/w/report.HTML'), FileViewKind.html);
    expect(FileViewKind.forPath('/w/a.pdf'), FileViewKind.pdf);
    expect(FileViewKind.forPath('/w/shot.png'), FileViewKind.image);
    expect(FileViewKind.forPath('/w/lib/main.dart'), FileViewKind.text);
    expect(FileViewKind.forPath('/w/Makefile'), FileViewKind.text);
  });

  group('FileTabView', () {
    const root = '/w';
    late _MemoryFileSystem fs;
    late SessionPanelController panel;

    setUp(() {
      fs = _MemoryFileSystem({
        '/w/lib/main.dart': const TextFileContent('void main() {\n}\n'),
        '/w/shot.bin': const BinaryFileContent(),
        '/w/.factory/spec.md': const TextFileContent('# Spec\n'),
      });
      panel = SessionPanelController(git: _FakeGit(), fileSystem: fs);
    });

    tearDown(() => panel.dispose());

    Future<void> pump(WidgetTester tester, String path) async {
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: panel,
          child: MaterialApp(
            home: Scaffold(
              body: FileTabView(worktree: root, path: path),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('shows text with line numbers and its relative path', (
      tester,
    ) async {
      await pump(tester, '/w/lib/main.dart');

      expect(find.text('lib/main.dart'), findsOneWidget);
      expect(find.text('void main() {'), findsOneWidget);
      expect(find.text('}'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('shows the file again when it changes on disk', (tester) async {
      await pump(tester, '/w/lib/main.dart');

      fs.files['/w/lib/main.dart'] = const TextFileContent('changed\n');
      fs.events.add('/w/lib/main.dart');
      // Past the file tree's debounce.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      expect(find.text('changed'), findsOneWidget);
      expect(find.text('void main() {'), findsNothing);
    });

    testWidgets('says why a binary file is not shown', (tester) async {
      await pump(tester, '/w/shot.bin');

      expect(find.text('Not a text file.'), findsOneWidget);
    });

    testWidgets('renders Markdown, with its source a toggle away', (
      tester,
    ) async {
      await pump(tester, '/w/.factory/spec.md');
      // No web view under test: the viewer says so.
      expect(find.text('# Spec'), findsNothing);

      await tester.tap(find.byTooltip('Show source'));
      await tester.pump();
      await tester.pump();
      expect(find.text('# Spec'), findsOneWidget);

      await tester.tap(find.byTooltip('Show rendered'));
      await tester.pump();
      expect(find.text('# Spec'), findsNothing);
    });

    testWidgets('says when the file is gone', (tester) async {
      await pump(tester, '/w/missing.txt');
      await tester.pump();

      expect(find.textContaining('The file is gone'), findsOneWidget);
    });
  });
}
