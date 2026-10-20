import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'package:tree_launcher/features/session_panel/domain/file_entry.dart';

/// Reads a worktree's folders for the file tree, and watches it for
/// changes. Everything on disk shows, gitignored or not, except what
/// [isHiddenEntry] leaves out.
class WorktreeFileSystem {
  const WorktreeFileSystem();

  /// The entries of the folder at [directory], sorted by [compareEntries].
  /// A link counts as what it points to. Throws when the folder can't be
  /// read.
  Future<List<FileEntry>> list(String directory) async {
    final entries = <FileEntry>[];
    await for (final entity in Directory(directory).list(followLinks: false)) {
      final name = p.basename(entity.path);
      if (isHiddenEntry(name)) continue;
      final isDirectory = entity is Link
          ? await FileSystemEntity.isDirectory(entity.path)
          : entity is Directory;
      entries.add(FileEntry(path: entity.path, isDirectory: isDirectory));
    }
    return entries..sort(compareEntries);
  }

  /// The paths that change under [root], as they happen (both ends of a
  /// move). Ends quietly when the folder can't be watched.
  Stream<String> watch(String root) {
    try {
      return Directory(root)
          .watch(recursive: true)
          .expand(
            (event) => [
              event.path,
              if (event is FileSystemMoveEvent && event.destination != null)
                event.destination!,
            ],
          )
          .handleError((Object e) => debugPrint('Watching $root failed: $e'));
    } catch (e) {
      debugPrint('Watching $root failed: $e');
      return const Stream.empty();
    }
  }
}
