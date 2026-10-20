import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/features/session_panel/data/worktree_file_system.dart';
import 'package:tree_launcher/features/session_panel/domain/file_entry.dart';
import 'package:tree_launcher/features/session_panel/presentation/controllers/session_panel_controller.dart';
import 'package:tree_launcher/features/session_panel/presentation/widgets/worktree_files_tab.dart';
import 'package:tree_launcher/features/workspace/data/git_service.dart';

/// A worktree held in memory, since real file reads don't complete under a
/// widget test's fake async.
class _MemoryFileSystem extends WorktreeFileSystem {
  const _MemoryFileSystem(this.folders);

  /// Each folder's entries, by folder path.
  final Map<String, List<FileEntry>> folders;

  @override
  Future<List<FileEntry>> list(String directory) async =>
      [...?folders[directory]]..sort(compareEntries);

  @override
  Stream<String> watch(String root) => const Stream.empty();
}

class _FakeGit extends GitService {
  @override
  Future<Set<String>> ignoredPaths(String worktreePath) async => {'build/'};
}

void main() {
  const root = '/w';
  late SessionPanelController panel;

  setUp(() {
    panel = SessionPanelController(
      git: _FakeGit(),
      fileSystem: const _MemoryFileSystem({
        root: [
          FileEntry(path: '/w/lib', isDirectory: true),
          FileEntry(path: '/w/build', isDirectory: true),
          FileEntry(path: '/w/README.md', isDirectory: false),
        ],
        '/w/lib': [FileEntry(path: '/w/lib/main.dart', isDirectory: false)],
      }),
    );
  });

  tearDown(() => panel.dispose());

  testWidgets('opens folders in place and files in a tab', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: panel,
        child: const MaterialApp(
          home: Scaffold(body: WorktreeFilesTab(worktree: root)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('lib'), findsOneWidget);
    expect(find.text('build'), findsOneWidget);
    expect(find.text('README.md'), findsOneWidget);
    expect(find.text('main.dart'), findsNothing);

    await tester.tap(find.text('lib'));
    await tester.pump();
    await tester.pump();
    expect(find.text('main.dart'), findsOneWidget);

    await tester.tap(find.text('main.dart'));
    await tester.pump();
    expect(
      panel.selectedFor(root),
      const SessionPanelTab.file('/w/lib/main.dart'),
    );
  });
}
