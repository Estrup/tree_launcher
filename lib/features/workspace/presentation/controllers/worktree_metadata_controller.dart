import 'package:flutter/foundation.dart';

import 'package:tree_launcher/features/workspace/data/worktree_metadata_store.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_metadata.dart';

/// Every worktree's metadata, for all repos, in memory: the sidebar and the
/// terminal show other repos' worktrees too, so it is all loaded at startup
/// (a few dozen rows).
///
/// Changes apply here at once, so two in flight (say, two agents creating
/// worktrees) can't lose each other's update, and are written to the
/// [WorktreeMetadataStore] in the order they were made.
class WorktreeMetadataController extends ChangeNotifier {
  WorktreeMetadataController({required WorktreeMetadataStore store})
    : _store = store;

  final WorktreeMetadataStore _store;

  /// By worktree path, in the order first written.
  final Map<String, WorktreeMetadata> _byPath = {};

  /// The last queued write, or null when none is pending. Not a completed
  /// future when idle: one made outside a widget test's fake async would
  /// never run what is chained on it inside.
  Future<void>? _saving;

  /// Loads the saved metadata, replacing what is in memory.
  Future<void> load() async {
    final entries = await _store.loadAll();
    _byPath
      ..clear()
      ..addEntries([for (final e in entries) MapEntry(e.path, e)]);
    notifyListeners();
  }

  /// Waits for pending writes (for tests).
  Future<void> flush() => _saving ?? Future.value();

  /// Runs [write] after the writes queued before it.
  Future<void> _enqueue(Future<void> Function() write) {
    final previous = _saving;
    late final Future<void> next;
    next = (previous == null ? write() : previous.then((_) => write()))
        .whenComplete(() {
          if (identical(_saving, next)) _saving = null;
        });
    return _saving = next;
  }

  /// [path]'s metadata, or null when there is none.
  WorktreeMetadata? operator [](String path) => _byPath[path];

  /// The metadata of [repoPath]'s worktrees, in the order first written.
  Iterable<WorktreeMetadata> forRepo(String repoPath) =>
      _byPath.values.where((m) => m.repoPath == repoPath);

  /// [repoPath]'s worktrees with a remembered Claude session, in the order
  /// the sessions were first remembered.
  List<WorktreeMetadata> sessionsFor(String repoPath) => [
    for (final m in forRepo(repoPath))
      if (m.session != null) m,
  ];

  /// Every Jira issue a worktree is for, in any repo.
  Set<String> get jiraIssueKeys => {
    for (final m in _byPath.values) ?m.jiraIssue,
  };

  /// Applies [change] to the metadata of [path] (a worktree of the repo at
  /// [repoPath]; empty when there is none yet) and saves the result.
  Future<void> update(
    String repoPath,
    String path,
    WorktreeMetadata Function(WorktreeMetadata current) change,
  ) => updateAll(repoPath, [path], change);

  /// [update] for several worktrees at once, saved together.
  Future<void> updateAll(
    String repoPath,
    Iterable<String> paths,
    WorktreeMetadata Function(WorktreeMetadata current) change,
  ) {
    final changed = <WorktreeMetadata>[];
    for (final path in paths) {
      final current =
          _byPath[path] ?? WorktreeMetadata(path: path, repoPath: repoPath);
      final next = change(current);
      if (next == current) continue;
      if (next.isEmpty) {
        _byPath.remove(path);
      } else {
        _byPath[path] = next;
      }
      changed.add(next);
    }
    if (changed.isEmpty) return flush();
    notifyListeners();
    return _enqueue(() => _store.saveAll(changed));
  }

  /// Forgets everything about [paths], e.g. after their worktrees were
  /// deleted.
  Future<void> forget(Iterable<String> paths) {
    final gone = [
      for (final path in paths)
        if (_byPath.remove(path) != null) path,
    ];
    if (gone.isEmpty) return flush();
    notifyListeners();
    return _enqueue(() => _store.delete(gone));
  }

  /// Forgets [repoPath]'s worktrees that aren't in [livePaths], the
  /// worktrees git lists for it now.
  Future<void> reconcile(String repoPath, Set<String> livePaths) => forget([
    for (final m in forRepo(repoPath))
      if (!livePaths.contains(m.path)) m.path,
  ]);
}
