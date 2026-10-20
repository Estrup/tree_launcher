import 'package:path/path.dart' as p;

import 'package:tree_launcher/features/session_panel/domain/file_entry.dart';

/// One line of a filtered tree.
class FilteredEntry {
  const FilteredEntry({
    required this.entry,
    required this.depth,
    required this.isMatch,
  });

  final FileEntry entry;
  final int depth;

  /// Whether it matches the filter itself, rather than holding a match.
  final bool isMatch;
}

/// Whether the entry at [relativePath] (relative to the worktree,
/// `/`-separated) matches [query]: its name contains the query, ignoring
/// case, or with a `/` in the query, its path does.
bool matchesFilter(String relativePath, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return false;
  final subject = q.contains('/')
      ? relativePath.toLowerCase()
      : p.posix.basename(relativePath).toLowerCase();
  return subject.contains(q);
}

/// The entries of [all] (everything under [root]) that match [query], as a
/// tree: each match under the folders that hold it, all open, sorted by
/// [compareEntries]. A matching folder shows without its contents, unless
/// some of them match too.
List<FilteredEntry> filterTree(String root, List<FileEntry> all, String query) {
  // Cheaper than p.relative, which counts with 50,000 entries a keystroke.
  final prefix = root.endsWith('/') ? root : '$root/';
  String relative(String path) => path.startsWith(prefix)
      ? path.substring(prefix.length)
      : p.posix.joinAll(p.split(p.relative(path, from: root)));

  final matches = <String>{};
  final shown = <String, FileEntry>{};
  for (final entry in all) {
    if (!matchesFilter(relative(entry.path), query)) continue;
    matches.add(entry.path);
    shown[entry.path] = entry;
    // The folders that hold it, up to the worktree. A folder already shown
    // has its own folders shown too.
    var parent = p.dirname(entry.path);
    while (parent != root && p.isWithin(root, parent)) {
      if (shown.containsKey(parent)) break;
      shown[parent] = FileEntry(path: parent, isDirectory: true);
      parent = p.dirname(parent);
    }
  }

  final children = <String, List<FileEntry>>{};
  for (final entry in shown.values) {
    (children[p.dirname(entry.path)] ??= []).add(entry);
  }

  final result = <FilteredEntry>[];
  void add(String directory, int depth) {
    final entries = children[directory];
    if (entries == null) return;
    entries.sort(compareEntries);
    for (final entry in entries) {
      result.add(
        FilteredEntry(
          entry: entry,
          depth: depth,
          isMatch: matches.contains(entry.path),
        ),
      );
      if (entry.isDirectory) add(entry.path, depth + 1);
    }
  }

  add(root, 0);
  return result;
}
