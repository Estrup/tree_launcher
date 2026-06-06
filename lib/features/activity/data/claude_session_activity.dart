import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Derives "activity" for a worktree from Claude Code desktop's own session
/// transcripts. Claude stores per-project sessions under
/// `~/.claude/projects/<dash-encoded-path>/*.jsonl`; each worktree maps to its
/// own folder, and every transcript line carries a `"timestamp"` for the event
/// it records. We read those per-line timestamps to know which days work
/// happened there (a single session can span days, so the file mtime alone
/// would undercount). This works retroactively — no polling, no bookkeeping in
/// this app — and is a natural fit since the user works primarily in Claude.
class ClaudeSessionActivity {
  ClaudeSessionActivity({String? homeDir, String? claudeProjectsDir})
    : _homeDir = homeDir ?? Platform.environment['HOME'],
      _claudeProjectsDirOverride = claudeProjectsDir;

  final String? _homeDir;
  final String? _claudeProjectsDirOverride;

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
  Future<List<DateTime>> activeDaysFor(String worktreePath) async {
    final stamps = await sessionTimestampsFor(worktreePath);
    final days = <DateTime>{
      for (final t in stamps) DateTime(t.year, t.month, t.day),
    };
    final sorted = days.toList()..sort();
    return sorted;
  }

  /// The most recent moment Claude was active in [worktreePath], or null.
  Future<DateTime?> lastActiveFor(String worktreePath) async {
    final stamps = await sessionTimestampsFor(worktreePath);
    if (stamps.isEmpty) return null;
    return stamps.last;
  }
}
