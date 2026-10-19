import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'package:tree_launcher/core/database/app_database.dart';

/// A JSON or JSON-lines file from before the database, which [LegacyImporter]
/// merges into it.
abstract class LegacyImport {
  /// The file's name in the data directory.
  String get fileName;

  /// Merges [content] into the database without duplicating what is already
  /// there, so a file imported twice (or rewritten by an older build after
  /// the first import) changes nothing it shouldn't. Runs in a transaction.
  Future<void> merge(String content);
}

/// Folds the pre-database files into the database at startup. Each file that
/// exists is merged in its own transaction, then renamed to `*.migrated`
/// (never deleted, never overwriting an earlier `*.migrated`). A file whose
/// import fails is left as it is and tried again at the next start.
class LegacyImporter {
  LegacyImporter(this._db, this._directory, this._imports);

  final AppDatabase _db;
  final String _directory;

  /// Run in order, so runs are imported before their events.
  final List<LegacyImport> _imports;

  Future<void> run() async {
    for (final import in _imports) {
      final file = File(p.join(_directory, import.fileName));
      try {
        if (!await file.exists()) continue;
        final content = await file.readAsString();
        await _db.transaction(() => import.merge(content));
        final target = await _migratedPath(file.path);
        await file.rename(target);
        debugPrint('Imported ${import.fileName}, kept as $target');
      } catch (e) {
        debugPrint('Import of ${import.fileName} failed: $e');
      }
    }
  }

  static Future<String> _migratedPath(String path) async {
    final plain = '$path.migrated';
    if (!await File(plain).exists()) return plain;
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp =
        '${now.year}${two(now.month)}${two(now.day)}-'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
    var candidate = '$plain-$stamp';
    for (var i = 2; await File(candidate).exists(); i++) {
      candidate = '$plain-$stamp-$i';
    }
    return candidate;
  }
}

/// The non-empty lines of a JSON-lines file, parsed. Malformed lines are
/// skipped and logged, as the file stores did, except that when two appends
/// interleaved (a cut-off record followed by a complete one on the same
/// line), the complete one is kept.
List<Map<String, dynamic>> parseJsonLines(String content, String fileName) {
  final result = <Map<String, dynamic>>[];
  for (final line in const LineSplitter().convert(content)) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) result.add(decoded);
    } catch (e) {
      final trailing = _trailingRecord(trimmed);
      if (trailing != null) {
        result.add(trailing);
        debugPrint('$fileName: kept the complete record after a cut-off one');
      } else {
        debugPrint('$fileName: skipping malformed line: $e');
      }
    }
  }
  return result;
}

/// The first object that parses from a later `{` to the end of [line].
Map<String, dynamic>? _trailingRecord(String line) {
  for (var i = line.indexOf('{', 1); i != -1; i = line.indexOf('{', i + 1)) {
    try {
      final decoded = jsonDecode(line.substring(i));
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // Not where the next record starts.
    }
  }
  return null;
}
