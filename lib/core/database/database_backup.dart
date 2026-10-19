import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'package:tree_launcher/core/database/app_database.dart';

/// Keeps one copy of the database per day (`tree_launcher-2026-10-19.db`) in
/// [directory], made with `VACUUM INTO`, and deletes all but the newest
/// [keep].
class DatabaseBackup {
  DatabaseBackup(
    this._db,
    this.directory, {
    this.keep = 7,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final String directory;
  final int keep;
  final DateTime Function() _clock;

  static final _name = RegExp(r'^tree_launcher-\d{4}-\d{2}-\d{2}\.db$');

  /// Backs up now if today has no backup, then checks every hour, so an app
  /// left running for days still gets its daily copy.
  Timer start() {
    unawaited(runIfDue());
    return Timer.periodic(const Duration(hours: 1), (_) => runIfDue());
  }

  /// Makes today's backup if there is none yet, and prunes old ones. Never
  /// throws.
  Future<void> runIfDue() async {
    try {
      await Directory(directory).create(recursive: true);
      final now = _clock();
      String two(int n) => n.toString().padLeft(2, '0');
      final target = File(
        p.join(
          directory,
          'tree_launcher-${now.year}-${two(now.month)}-${two(now.day)}.db',
        ),
      );
      if (!await target.exists()) {
        // Into a temporary file first, so an interrupted backup isn't taken
        // for today's.
        final tmp = File('${target.path}.tmp');
        if (await tmp.exists()) await tmp.delete();
        await _db.customStatement('VACUUM INTO ?', [tmp.path]);
        await tmp.rename(target.path);
      }
      await _prune();
    } catch (e) {
      debugPrint('DatabaseBackup failed: $e');
    }
  }

  Future<void> _prune() async {
    final backups = [
      await for (final entity in Directory(directory).list())
        if (entity is File && _name.hasMatch(p.basename(entity.path))) entity,
    ]..sort((a, b) => b.path.compareTo(a.path));
    for (final old in backups.skip(keep)) {
      await old.delete();
    }
  }
}
