import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'package:tree_launcher/core/errors/user_message.dart';
import 'package:tree_launcher/features/session_panel/data/worktree_file_system.dart';
import 'package:tree_launcher/features/session_panel/domain/file_entry.dart';
import 'package:tree_launcher/features/session_panel/domain/file_filter.dart';
import 'package:tree_launcher/features/workspace/data/git_service.dart';

/// One line of the file tree: an entry at a depth.
class FileTreeRow {
  const FileTreeRow({
    required this.entry,
    required this.depth,
    required this.expanded,
    required this.ignored,
    this.loading = false,
    this.isMatch = false,
  });

  final FileEntry entry;

  /// 0 for the worktree's own entries.
  final int depth;

  /// Whether this folder is open (false for files).
  final bool expanded;

  /// Whether git ignores it.
  final bool ignored;

  /// Whether this open folder's entries are still being read.
  final bool loading;

  /// While filtering: whether it matches the filter itself.
  final bool isMatch;
}

/// The file tree of one worktree: every file on disk, gitignored ones
/// dimmed. A folder is read when it is first opened. While the tree is
/// [attach]ed it watches the worktree and reads changed folders again,
/// [debounce] after the last change.
class WorktreeFilesController extends ChangeNotifier {
  WorktreeFilesController({
    required this.root,
    required GitService git,
    WorktreeFileSystem fileSystem = const WorktreeFileSystem(),
    this.debounce = const Duration(milliseconds: 300),
  }) : _git = git,
       _fs = fileSystem;

  /// The worktree's path.
  final String root;
  final GitService _git;
  final WorktreeFileSystem _fs;
  final Duration debounce;

  /// Folders opened the first time the tree shows, when they exist: the
  /// factory's and Claude's working files.
  static const pinnedFolders = ['.factory', '.claude'];

  /// The entries of each folder read so far, by folder path.
  final Map<String, List<FileEntry>> _children = {};
  final Map<String, String> _errors = {};
  final Set<String> _loading = {};
  final Set<String> _expanded = {};
  Set<String> _ignored = const {};

  int _attached = 0;
  bool _started = false;
  StreamSubscription<String>? _watch;
  Timer? _debounceTimer;
  final Set<String> _changed = {};
  final _changes = StreamController<Set<String>>.broadcast();
  List<FileTreeRow>? _rows;
  bool _disposed = false;

  String _filter = '';

  /// Everything under the worktree, walked for the filter; null until
  /// walked, and again after a change on disk.
  WalkResult? _walked;
  Future<void>? _walking;

  /// The paths that changed on disk, in batches, while attached.
  Stream<Set<String>> get changes => _changes.stream;

  /// Why the worktree's own folder couldn't be read; null when it could.
  String? get error => _errors[root];

  /// Whether the worktree's own folder is still being read the first time.
  bool get isLoading => !_children.containsKey(root) && _errors[root] == null;

  /// The visible lines: the worktree's entries and those of open folders,
  /// or while [isFiltering], the matches under their folders.
  List<FileTreeRow> get rows =>
      _rows ??= isFiltering ? _buildFilteredRows() : _buildRows();

  /// The filter typed; empty when not filtering.
  String get filter => _filter;

  bool get isFiltering => _filter.trim().isNotEmpty;

  /// Whether the worktree is still being walked for the filter.
  bool get isWalking => isFiltering && _walked == null;

  /// Whether the walk for the filter stopped at its limit, so some files
  /// may be missing from the matches.
  bool get isFilterTruncated => isFiltering && (_walked?.truncated ?? false);

  /// How many entries match the filter.
  int get matchCount => isFiltering ? rows.where((r) => r.isMatch).length : 0;

  /// Filters the tree by [query] (see `matchesFilter`); empty shows the
  /// whole tree again, as it was. The worktree is walked the first time.
  void setFilter(String query) {
    if (query == _filter) return;
    _filter = query;
    if (isFiltering) _walkIfNeeded();
    _changedRows();
  }

  /// Ends filtering and shows [path] in the tree, its folders open, and
  /// it too when it is a folder.
  Future<void> reveal(String path, {required bool isDirectory}) async {
    _filter = '';
    _changedRows();
    final folders = <String>[];
    var folder = isDirectory ? path : p.dirname(path);
    while (p.isWithin(root, folder)) {
      folders.add(folder);
      folder = p.dirname(folder);
    }
    for (final folder in folders.reversed) {
      await expand(folder);
    }
  }

  void _walkIfNeeded() {
    if (_walked != null || _walking != null) return;
    _walking = () async {
      try {
        _walked = await _fs.walk(root, include: {..._expanded});
      } catch (e) {
        debugPrint('Walking $root failed: $e');
        _walked = const WalkResult([], truncated: false);
      } finally {
        _walking = null;
        _changedRows();
      }
    }();
  }

  bool isExpanded(String directory) => _expanded.contains(directory);

  /// Whether git ignores the entry at [path].
  bool isIgnored(String path) => isIgnoredPath(_relative(path), _ignored);

  /// Starts showing the tree: reads it the first time and watches the
  /// worktree until as many [detach]es.
  void attach() {
    _attached++;
    if (_attached > 1) return;
    _watch = _fs.watch(root).listen(_onChange);
    if (!_started) {
      _started = true;
      unawaited(_start());
    } else {
      // Changes while detached were missed.
      unawaited(refresh());
    }
  }

  void detach() {
    if (_attached == 0) return;
    _attached--;
    if (_attached > 0) return;
    unawaited(_watch?.cancel());
    _watch = null;
    _debounceTimer?.cancel();
    _changed.clear();
  }

  Future<void> _start() async {
    await Future.wait([_load(root), _loadIgnored()]);
    for (final name in pinnedFolders) {
      final path = p.join(root, name);
      if (_children[root]?.contains(FileEntry(path: path, isDirectory: true)) ??
          false) {
        await expand(path);
      }
    }
  }

  /// Opens or closes the folder at [directory].
  Future<void> toggle(String directory) => _expanded.contains(directory)
      ? Future.sync(() => collapse(directory))
      : expand(directory);

  /// Opens the folder at [directory], reading it when it hasn't been.
  Future<void> expand(String directory) async {
    if (!_expanded.add(directory)) return;
    _changedRows();
    if (!_children.containsKey(directory)) await _load(directory);
  }

  void collapse(String directory) {
    if (_expanded.remove(directory)) _changedRows();
  }

  /// Closes every folder.
  void collapseAll() {
    if (_expanded.isEmpty) return;
    _expanded.clear();
    _changedRows();
  }

  /// Reads every folder read so far, and the ignored paths, again.
  Future<void> refresh() => _reload({..._children.keys});

  Future<void> _reload(Set<String> directories) async {
    await Future.wait([
      for (final directory in directories) _load(directory),
      _loadIgnored(),
    ]);
  }

  Future<void> _load(String directory) async {
    _loading.add(directory);
    _changedRows();
    try {
      final entries = await _fs.list(directory);
      final gone = (_children[directory] ?? const <FileEntry>[])
          .where((e) => e.isDirectory && !entries.contains(e))
          .map((e) => e.path);
      for (final path in gone) {
        _forget(path);
      }
      _children[directory] = entries;
      _errors.remove(directory);
    } catch (e) {
      _children.remove(directory);
      _errors[directory] = userMessage(e);
    } finally {
      _loading.remove(directory);
      _changedRows();
    }
  }

  /// Drops what is known of the folder at [directory] and those in it.
  void _forget(String directory) {
    final prefix = '$directory${p.separator}';
    bool under(String path) => path == directory || path.startsWith(prefix);
    _children.removeWhere((path, _) => under(path));
    _errors.removeWhere((path, _) => under(path));
    _expanded.removeWhere(under);
  }

  Future<void> _loadIgnored() async {
    try {
      _ignored = await _git.ignoredPaths(root);
    } catch (_) {
      // Not a git checkout (or git failed): nothing is dimmed.
      _ignored = const {};
    }
    _changedRows();
  }

  void _onChange(String path) {
    _changed.add(path);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, _flushChanges);
  }

  void _flushChanges() {
    if (_disposed || _changed.isEmpty) return;
    final changed = {..._changed};
    _changed.clear();
    final directories = {
      for (final path in changed)
        if (_children.containsKey(p.dirname(path))) p.dirname(path),
    };
    unawaited(_reload(directories));
    // Walk again for the filter, now or when it is next used.
    _walked = null;
    if (isFiltering) _walkIfNeeded();
    _changes.add(changed);
  }

  List<FileTreeRow> _buildRows() {
    final rows = <FileTreeRow>[];
    void add(String directory, int depth) {
      for (final entry in _children[directory] ?? const <FileEntry>[]) {
        final expanded = entry.isDirectory && _expanded.contains(entry.path);
        rows.add(
          FileTreeRow(
            entry: entry,
            depth: depth,
            expanded: expanded,
            ignored: isIgnored(entry.path),
            loading:
                expanded &&
                _loading.contains(entry.path) &&
                !_children.containsKey(entry.path),
          ),
        );
        if (expanded) add(entry.path, depth + 1);
      }
    }

    add(root, 0);
    return rows;
  }

  List<FileTreeRow> _buildFilteredRows() {
    final walked = _walked;
    if (walked == null) return const [];
    final hits = filterTree(root, walked.entries, _filter);
    return [
      for (var i = 0; i < hits.length; i++)
        FileTreeRow(
          entry: hits[i].entry,
          depth: hits[i].depth,
          // Open when the next line is in it.
          expanded: i + 1 < hits.length && hits[i + 1].depth > hits[i].depth,
          ignored: isIgnored(hits[i].entry.path),
          isMatch: hits[i].isMatch,
        ),
    ];
  }

  String _relative(String path) =>
      p.posix.joinAll(p.split(p.relative(path, from: root)));

  void _changedRows() {
    _rows = null;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    unawaited(_watch?.cancel());
    unawaited(_changes.close());
    super.dispose();
  }
}
