import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

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

  /// Folders [walk] doesn't go into unless asked to: dependencies and build
  /// output, large and rarely what is searched for.
  static const skippedFolders = {
    'node_modules',
    'bin',
    'obj',
    'build',
    '.dart_tool',
    '.build',
    'Pods',
    '.gradle',
    '.vs',
  };

  /// The most entries [walk] collects.
  static const walkLimit = 50000;

  /// Every entry under [root], for the filter, read on a background
  /// isolate. Folders in [skippedFolders] are listed but not gone into,
  /// unless their path is in [include]; links aren't followed. Stops after
  /// [limit] entries. A folder that can't be read is left out.
  Future<WalkResult> walk(
    String root, {
    Set<String> include = const {},
    int limit = walkLimit,
  }) => Isolate.run(() => _walk(root, include, limit));

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

/// What [WorktreeFileSystem.walk] found.
class WalkResult {
  const WalkResult(this.entries, {required this.truncated});

  final List<FileEntry> entries;

  /// Whether it stopped at its limit before seeing everything.
  final bool truncated;
}

WalkResult _walk(String root, Set<String> include, int limit) {
  final entries = <FileEntry>[];
  final pending = [root];
  while (pending.isNotEmpty) {
    final directory = pending.removeLast();
    final List<FileSystemEntity> listed;
    try {
      listed = Directory(directory).listSync(followLinks: false);
    } on FileSystemException {
      continue;
    }
    for (final entity in listed) {
      final name = p.basename(entity.path);
      if (isHiddenEntry(name)) continue;
      final isDirectory = entity is Directory;
      entries.add(FileEntry(path: entity.path, isDirectory: isDirectory));
      if (entries.length >= limit) return WalkResult(entries, truncated: true);
      if (isDirectory &&
          (!WorktreeFileSystem.skippedFolders.contains(name) ||
              include.contains(entity.path))) {
        pending.add(entity.path);
      }
    }
  }
  return WalkResult(entries, truncated: false);
}
