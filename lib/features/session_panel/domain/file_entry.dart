import 'package:path/path.dart' as p;

/// A file or folder in a worktree's file tree.
class FileEntry {
  const FileEntry({required this.path, required this.isDirectory});

  /// Its absolute path.
  final String path;
  final bool isDirectory;

  String get name => p.basename(path);

  @override
  bool operator ==(Object other) =>
      other is FileEntry &&
      other.path == path &&
      other.isDirectory == isDirectory;

  @override
  int get hashCode => Object.hash(path, isDirectory);
}

/// Entries the tree never shows: git's own data and Finder's.
bool isHiddenEntry(String name) => name == '.git' || name == '.DS_Store';

/// Folders first, then by name, ignoring case.
int compareEntries(FileEntry a, FileEntry b) {
  if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
  final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
  return byName != 0 ? byName : a.name.compareTo(b.name);
}

/// Whether [relativePath] (relative to the worktree, `/`-separated) is
/// gitignored, given [ignored] as `GitService.ignoredPaths` returns it:
/// ignored files as they are and ignored folders ending in `/`.
bool isIgnoredPath(String relativePath, Set<String> ignored) {
  if (ignored.isEmpty) return false;
  if (ignored.contains(relativePath) || ignored.contains('$relativePath/')) {
    return true;
  }
  // Inside an ignored folder.
  var end = relativePath.indexOf('/');
  while (end != -1) {
    if (ignored.contains(relativePath.substring(0, end + 1))) return true;
    end = relativePath.indexOf('/', end + 1);
  }
  return false;
}
