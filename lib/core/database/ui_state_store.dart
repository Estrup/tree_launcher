import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:tree_launcher/core/database/app_database.dart';

/// Small remembered choices in the `ui_state` table, each a JSON value under
/// a key and a scope: [appScope], or [repoScope] for one repo's.
///
/// Keeps what it has read or written in memory, so writing values that
/// haven't changed (every settings save writes them all) touches nothing.
class UiStateStore {
  UiStateStore(this._db);

  final AppDatabase _db;

  static const appScope = 'app';

  /// The scope of the repo at [repoPath].
  static String repoScope(String repoPath) => 'repo:$repoPath';

  /// What is saved, as encoded JSON, by scope and key; null until read.
  Map<String, Map<String, String>>? _known;

  Future<Map<String, Map<String, String>>> _all() async {
    final known = _known;
    if (known != null) return known;
    final rows = await _db.select(_db.uiState).get();
    final all = <String, Map<String, String>>{};
    for (final row in rows) {
      (all[row.scope] ??= {})[row.key] = row.value;
    }
    return _known = all;
  }

  /// The values saved in [scope], decoded.
  Future<Map<String, Object?>> read(String scope) async => {
    for (final MapEntry(:key, :value)
        in ((await _all())[scope] ?? const {}).entries)
      key: jsonDecode(value),
  };

  /// Saves [values] in [scope]; a null value removes its key. Keys not in
  /// [values] are left alone.
  Future<void> write(String scope, Map<String, Object?> values) async {
    final saved = (await _all())[scope] ?? const <String, String>{};
    final changed = <String, String?>{
      for (final MapEntry(:key, :value) in values.entries)
        if ((value == null ? null : jsonEncode(value)) != saved[key])
          key: value == null ? null : jsonEncode(value),
    };
    if (changed.isEmpty) return;
    await _db.batch((batch) {
      for (final MapEntry(:key, :value) in changed.entries) {
        if (value == null) {
          batch.deleteWhere(
            _db.uiState,
            (t) => t.scope.equals(scope) & t.key.equals(key),
          );
        } else {
          batch.insert(
            _db.uiState,
            UiStateCompanion.insert(scope: scope, key: key, value: value),
            mode: InsertMode.insertOrReplace,
          );
        }
      }
    });
    final scoped = _known![scope] ??= {};
    for (final MapEntry(:key, :value) in changed.entries) {
      if (value == null) {
        scoped.remove(key);
      } else {
        scoped[key] = value;
      }
    }
  }

  /// Saves the non-null [values] in [scope] whose key has no value yet:
  /// for imports, which must not overwrite what is already here.
  Future<void> writeIfAbsent(String scope, Map<String, Object?> values) async {
    final saved = (await _all())[scope] ?? const <String, String>{};
    await write(scope, {
      for (final MapEntry(:key, :value) in values.entries)
        if (value != null && !saved.containsKey(key)) key: value,
    });
  }

  /// Removes the repo scopes of repos not in [repoPaths].
  Future<void> keepRepoScopes(Iterable<String> repoPaths) async {
    final keep = {for (final path in repoPaths) repoScope(path)};
    final gone = [
      for (final scope in (await _all()).keys)
        if (scope.startsWith('repo:') && !keep.contains(scope)) scope,
    ];
    if (gone.isEmpty) return;
    await (_db.delete(_db.uiState)..where((t) => t.scope.isIn(gone))).go();
    gone.forEach(_known!.remove);
  }
}
