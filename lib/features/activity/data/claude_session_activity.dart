import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'package:tree_launcher/core/database/app_database.dart';

/// Derives "activity" for a worktree from Claude Code desktop's own session
/// transcripts. Claude stores per-project sessions under
/// `~/.claude/projects/<dash-encoded-path>/*.jsonl`; each worktree maps to its
/// own folder, and every transcript line carries a `"timestamp"` for the event
/// it records. We read those per-line timestamps to know which days work
/// happened there (a single session can span days, so the file mtime alone
/// would undercount). This works retroactively — no polling, no bookkeeping in
/// this app — and is a natural fit since the user works primarily in Claude.
///
/// With a [database], [activeDaysFor] keeps what it read from each transcript
/// in the `claude_transcripts` table, so a transcript is only read again once
/// its size or mtime changes, and then only from where the last read ended.
class ClaudeSessionActivity {
  ClaudeSessionActivity({
    String? homeDir,
    String? claudeProjectsDir,
    AppDatabase? database,
  }) : _homeDir = homeDir ?? Platform.environment['HOME'],
       _claudeProjectsDirOverride = claudeProjectsDir,
       _db = database;

  final String? _homeDir;
  final String? _claudeProjectsDirOverride;
  final AppDatabase? _db;

  String? get _projectsRoot =>
      _claudeProjectsDirOverride ??
      (_homeDir == null ? null : p.join(_homeDir, '.claude', 'projects'));

  /// Encodes a worktree path the way Claude Code names its project directory:
  /// every character that is not a letter, digit, or hyphen becomes a hyphen.
  /// e.g. `/Users/me/Projects/tree_launcher/main` ->
  ///      `-Users-me-Projects-tree-launcher-main`, and a trailing `/.bare`
  /// segment becomes `--bare`.
  static String encodeProjectDir(String worktreePath) {
    return worktreePath.replaceAll(RegExp(r'[^A-Za-z0-9-]'), '-');
  }

  /// Absolute path to the Claude project directory for [worktreePath], or null
  /// if the home directory could not be resolved.
  String? projectDirFor(String worktreePath) {
    final root = _projectsRoot;
    if (root == null) return null;
    return p.join(root, encodeProjectDir(worktreePath));
  }

  /// Whether Claude has any session transcript for [worktreePath], i.e.
  /// whether `claude --continue` there has a conversation to pick up.
  Future<bool> hasSessions(String worktreePath) async {
    final dirPath = projectDirFor(worktreePath);
    if (dirPath == null) return false;
    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) return false;
      return await dir
          .list(followLinks: false)
          .any((entity) => entity is File && entity.path.endsWith('.jsonl'));
    } catch (e) {
      debugPrint('ClaudeSessionActivity.hasSessions failed: $e');
      return false;
    }
  }

  /// Matches the `"timestamp":"<iso8601>"` field that Claude writes on every
  /// transcript line. We scan for these rather than relying on the file mtime,
  /// because a single session can span several days and the mtime only reflects
  /// the last one — which would silently drop the earlier active days.
  static final RegExp _timestampField = RegExp(r'"timestamp"\s*:\s*"([^"]+)"');

  /// Every real activity moment (local time) recorded in [worktreePath]'s
  /// Claude transcripts, sorted ascending. Reads the per-line timestamps inside
  /// each `.jsonl`; if a file has none parseable, it falls back to that file's
  /// modification time so the day isn't lost entirely.
  Future<List<DateTime>> sessionTimestampsFor(String worktreePath) async {
    final dirPath = projectDirFor(worktreePath);
    if (dirPath == null) return [];
    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) return [];
      final times = <DateTime>[];
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File || !entity.path.endsWith('.jsonl')) continue;
        times.addAll(await _timestampsInFile(entity));
      }
      times.sort();
      return times;
    } catch (e) {
      debugPrint('ClaudeSessionActivity.sessionTimestampsFor failed: $e');
      return [];
    }
  }

  Future<List<DateTime>> _timestampsInFile(File file) async {
    try {
      final content = await file.readAsString();
      final times = <DateTime>[];
      for (final match in _timestampField.allMatches(content)) {
        final parsed = DateTime.tryParse(match.group(1)!);
        if (parsed != null) times.add(parsed.toLocal());
      }
      if (times.isEmpty) {
        // No parseable timestamps — fall back to the file mtime.
        times.add((await file.stat()).modified);
      }
      return times;
    } catch (e) {
      debugPrint('ClaudeSessionActivity: failed reading ${file.path}: $e');
      return [];
    }
  }

  /// The distinct calendar days (local time, normalized to midnight) on which
  /// Claude was active in [worktreePath], sorted ascending.
  ///
  /// [since] says which days the caller is interested in: a transcript last
  /// modified before it can't add one, so with an index it isn't read again
  /// even if it changed (its days may then be stale for earlier dates).
  Future<List<DateTime>> activeDaysFor(
    String worktreePath, {
    DateTime? since,
  }) async {
    final db = _db;
    if (db != null) return _indexedActiveDaysFor(db, worktreePath, since);
    final stamps = await sessionTimestampsFor(worktreePath);
    final days = <DateTime>{
      for (final t in stamps) DateTime(t.year, t.month, t.day),
    };
    final sorted = days.toList()..sort();
    return sorted;
  }

  Future<List<DateTime>> _indexedActiveDaysFor(
    AppDatabase db,
    String worktreePath,
    DateTime? since,
  ) async {
    final dirPath = projectDirFor(worktreePath);
    if (dirPath == null) return [];
    try {
      final dir = Directory(dirPath);
      final stats = <String, FileStat>{};
      if (await dir.exists()) {
        await for (final entity in dir.list(followLinks: false)) {
          if (entity is! File || !entity.path.endsWith('.jsonl')) continue;
          stats[entity.path] = await entity.stat();
        }
      }
      final table = db.claudeTranscripts;
      final rows = {
        for (final row in await (db.select(
          table,
        )..where((t) => t.projectDir.equals(dirPath))).get())
          row.path: row,
      };

      final requests = <_ScanRequest>[];
      final days = <String, Set<String>>{
        for (final row in rows.values)
          row.path: {...(jsonDecode(row.activeDays) as List).cast<String>()},
      };
      for (final MapEntry(key: path, value: stat) in stats.entries) {
        final row = rows[path];
        final mtime = stat.modified.microsecondsSinceEpoch;
        if (row != null && row.size == stat.size && row.mtime == mtime) {
          continue;
        }
        if (row != null && since != null && stat.modified.isBefore(since)) {
          continue;
        }
        // Transcripts are append-only: a grown file is read from where the
        // last read ended, anything else from the start.
        final grown = row != null && stat.size >= row.size;
        requests.add(
          _ScanRequest(
            path: path,
            start: grown ? row.scannedBytes : 0,
            end: stat.size,
          ),
        );
        if (!grown) days[path] = {};
      }

      if (requests.isNotEmpty) {
        final results = await Isolate.run(_scanJob(requests));
        await db.batch((batch) {
          for (final result in results) {
            final stat = stats[result.path]!;
            final fileDays = days.putIfAbsent(result.path, () => {})
              ..addAll(result.days);
            batch.insert(
              table,
              ClaudeTranscriptsCompanion.insert(
                path: result.path,
                projectDir: dirPath,
                size: stat.size,
                mtime: stat.modified.microsecondsSinceEpoch,
                scannedBytes: result.scannedBytes,
                activeDays: jsonEncode(fileDays.toList()..sort()),
              ),
              mode: InsertMode.insertOrReplace,
            );
          }
        });
      }
      final gone = rows.keys.where((path) => !stats.containsKey(path));
      if (gone.isNotEmpty) {
        await (db.delete(table)..where((t) => t.path.isIn(gone))).go();
      }

      final result = <DateTime>{};
      for (final MapEntry(key: path, value: stat) in stats.entries) {
        final fileDays = days[path] ?? const <String>{};
        if (fileDays.isEmpty) {
          // No parseable timestamps — fall back to the file mtime.
          final m = stat.modified;
          result.add(DateTime(m.year, m.month, m.day));
        }
        for (final day in fileDays) {
          final [y, m, d] = day.split('-').map(int.parse).toList();
          result.add(DateTime(y, m, d));
        }
      }
      return result.toList()..sort();
    } catch (e) {
      debugPrint('ClaudeSessionActivity.activeDaysFor failed: $e');
      return [];
    }
  }

  /// The most recent moment Claude was active in [worktreePath], or null.
  Future<DateTime?> lastActiveFor(String worktreePath) async {
    final stamps = await sessionTimestampsFor(worktreePath);
    if (stamps.isEmpty) return null;
    return stamps.last;
  }
}

/// A byte range of a transcript to read: [start] is the end of the last
/// complete line already read.
class _ScanRequest {
  const _ScanRequest({
    required this.path,
    required this.start,
    required this.end,
  });

  final String path;
  final int start;
  final int end;
}

class _ScanResult {
  const _ScanResult(this.path, this.scannedBytes, this.days);

  final String path;

  /// Where the last complete line read ends.
  final int scannedBytes;

  /// Local days (`2026-10-19`) of the timestamps found.
  final Set<String> days;
}

/// [_scanTranscripts] as a closure that captures only [requests], so it can
/// be sent to another isolate.
Future<List<_ScanResult>> Function() _scanJob(List<_ScanRequest> requests) =>
    () => _scanTranscripts(requests);

/// Reads the requested ranges (in a background isolate) and collects the
/// local day of every `"timestamp": "…"` field on each complete line. A
/// trailing line without its newline yet is left for the next read.
Future<List<_ScanResult>> _scanTranscripts(List<_ScanRequest> requests) async {
  final results = <_ScanResult>[];
  for (final request in requests) {
    final days = <String>{};
    var scanned = request.start;
    try {
      var offset = request.start;
      final pending = BytesBuilder(copy: false);
      await for (final chunk in File(
        request.path,
      ).openRead(request.start, request.end)) {
        final bytes = chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
        var lineStart = 0;
        for (var i = 0; i < bytes.length; i++) {
          if (bytes[i] != 0x0A) continue;
          final part = Uint8List.sublistView(bytes, lineStart, i);
          if (pending.isEmpty) {
            _collectDays(part, days);
          } else {
            pending.add(part);
            _collectDays(pending.takeBytes(), days);
          }
          lineStart = i + 1;
          scanned = offset + lineStart;
        }
        if (lineStart < bytes.length) {
          pending.add(Uint8List.sublistView(bytes, lineStart));
        }
        offset += bytes.length;
      }
    } catch (_) {
      // Keep what was read; the rest is read next time.
    }
    results.add(_ScanResult(request.path, scanned, days));
  }
  return results;
}

/// `"timestamp"` in ASCII.
const _timestampKey = [
  0x22,
  0x74,
  0x69,
  0x6D,
  0x65,
  0x73,
  0x74,
  0x61,
  0x6D,
  0x70,
  0x22,
];

/// Adds the local day of each `"timestamp"\s*:\s*"<iso8601>"` field in
/// [line]: the same fields [ClaudeSessionActivity] matches with a regex,
/// found on the bytes so the file needn't be decoded.
void _collectDays(Uint8List line, Set<String> days) {
  final last = line.length - _timestampKey.length;
  outer:
  for (var i = 0; i <= last; i++) {
    for (var k = 0; k < _timestampKey.length; k++) {
      if (line[i + k] != _timestampKey[k]) continue outer;
    }
    var j = i + _timestampKey.length;
    while (j < line.length && _isSpace(line[j])) {
      j++;
    }
    if (j >= line.length || line[j] != 0x3A) continue; // ':'
    j++;
    while (j < line.length && _isSpace(line[j])) {
      j++;
    }
    if (j >= line.length || line[j] != 0x22) continue; // '"'
    final start = ++j;
    while (j < line.length && line[j] != 0x22) {
      j++;
    }
    if (j >= line.length) return;
    final parsed = DateTime.tryParse(
      latin1.decode(Uint8List.sublistView(line, start, j)),
    );
    if (parsed != null) {
      final t = parsed.toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      days.add('${t.year}-${two(t.month)}-${two(t.day)}');
    }
    i = j;
  }
}

bool _isSpace(int byte) =>
    byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D;
