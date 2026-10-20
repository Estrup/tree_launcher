import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'package:tree_launcher/features/session_panel/domain/file_content.dart';
import 'package:tree_launcher/features/session_panel/domain/file_entry.dart';

/// Reads a worktree's folders for the file tree and its files for the
/// viewer, and watches it for changes. Everything on disk shows, gitignored
/// or not, except what [isHiddenEntry] leaves out.
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

  /// The largest file [readText] reads.
  static const maxTextBytes = 2 * 1024 * 1024;

  /// How much of a file [readText] looks at to tell whether it is binary.
  static const _sniffBytes = 8 * 1024;

  /// The file at [path] as text, unless it is over [maxTextBytes] or has a
  /// NUL byte in its first 8 KB. Throws when it can't be read.
  Future<FileContent> readText(String path) async {
    final file = File(path);
    final size = await file.length();
    if (size > maxTextBytes) return TooLargeFileContent(size);
    final bytes = await file.readAsBytes();
    final sniff = bytes.length < _sniffBytes ? bytes.length : _sniffBytes;
    for (var i = 0; i < sniff; i++) {
      if (bytes[i] == 0) return const BinaryFileContent();
    }
    return TextFileContent(utf8.decode(bytes, allowMalformed: true));
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
