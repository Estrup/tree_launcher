import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

enum LogLevel {
  debug,
  info,
  warning,
  error;

  static LogLevel? tryParse(String name) {
    final lower = name.toLowerCase();
    for (final level in values) {
      if (level.name == lower) return level;
    }
    return null;
  }
}

/// One line of the app's log.
class LogEntry {
  const LogEntry({
    required this.at,
    required this.level,
    required this.source,
    required this.message,
  });

  final DateTime at;
  final LogLevel level;

  /// The part of the app it comes from, e.g. `jira-triggers`.
  final String source;
  final String message;

  static final _linePattern = RegExp(
    r'^(\d{4}-\d\d-\d\d \d\d:\d\d:\d\d\.\d{3}) (\w+) +(\S+) +(.*)$',
  );

  /// The entry as a line of the log file: time, level, source, message.
  /// A message's later lines are indented, so each entry starts a line.
  String toLine() {
    final time = at.toIso8601String().replaceFirst('T', ' ');
    final message = this.message.trimRight().replaceAll('\n', '\n    ');
    return '${time.substring(0, 23)} ${level.name.toUpperCase().padRight(7)} '
        '${source.padRight(14)} $message';
  }

  /// Parses the first line [toLine] wrote; null for anything else, such as
  /// a message's later line.
  static LogEntry? parse(String line) {
    final match = _linePattern.firstMatch(line);
    if (match == null) return null;
    final at = DateTime.tryParse(match[1]!.replaceFirst(' ', 'T'));
    final level = LogLevel.tryParse(match[2]!);
    if (at == null || level == null) return null;
    return LogEntry(
      at: at,
      level: level,
      source: match[3]!,
      message: match[4]!,
    );
  }

  LogEntry withMoreText(String text) => LogEntry(
    at: at,
    level: level,
    source: source,
    message: '$message\n$text',
  );
}

/// The app's log: what it did and what went wrong, for the Log window and,
/// through one plain-text file a day in [directory], for Claude to read.
///
/// Write to it with [appLog]. [AppLog.current] only keeps entries in memory
/// until the app [open]s one with a directory.
class AppLog extends ChangeNotifier {
  AppLog({
    this.directory,
    this.capacity = 2000,
    this.keepDays = 14,
    this.echo = false,
  });

  /// The log the app writes to.
  static AppLog current = AppLog();

  /// Where the day files (`YYYY-MM-DD.log`) are written; null keeps the log
  /// in memory only.
  final String? directory;

  /// The most entries kept in memory.
  final int capacity;

  /// Day files older than this are deleted when the log is opened.
  final int keepDays;

  /// Whether entries are also printed to the console (debug runs).
  final bool echo;

  final List<LogEntry> _entries = [];
  final List<LogEntry> _unwritten = [];
  Future<void> _writing = Future.value();
  bool _notifyScheduled = false;

  /// The entries in memory, oldest first.
  List<LogEntry> get entries => List.unmodifiable(_entries);

  /// The day file for [day].
  String? fileFor(DateTime day) {
    final dir = directory;
    if (dir == null) return null;
    final date = day.toIso8601String().substring(0, 10);
    return p.join(dir, '$date.log');
  }

  /// Creates the directory, reads today's entries back in and deletes day
  /// files older than [keepDays]. Never throws.
  Future<void> open() async {
    final dir = directory;
    if (dir == null) return;
    try {
      await Directory(dir).create(recursive: true);
      final today = File(fileFor(DateTime.now())!);
      if (await today.exists()) {
        final earlier = <LogEntry>[];
        for (final line in await today.readAsLines()) {
          final entry = LogEntry.parse(line);
          if (entry != null) {
            earlier.add(entry);
          } else if (earlier.isNotEmpty && line.startsWith('    ')) {
            earlier.last = earlier.last.withMoreText(line.substring(4));
          }
        }
        _entries.insertAll(0, earlier);
        _trim();
      }
      final cutoff = DateTime.now().subtract(Duration(days: keepDays));
      await for (final file in Directory(dir).list()) {
        final name = p.basenameWithoutExtension(file.path);
        final day = DateTime.tryParse(name);
        if (file is File && day != null && day.isBefore(cutoff)) {
          await file.delete();
        }
      }
    } catch (e) {
      // Not debugPrint: that may be captured into this log.
      // ignore: avoid_print
      print('Opening the log in $dir failed: $e');
    }
    _scheduleNotify();
  }

  void add(LogLevel level, String source, String message) =>
      _add(level, source, message, echo: echo);

  void _add(
    LogLevel level,
    String source,
    String message, {
    required bool echo,
  }) {
    final entry = LogEntry(
      at: DateTime.now(),
      level: level,
      source: source,
      message: message,
    );
    // ignore: avoid_print
    if (echo) print(entry.toLine());
    _entries.add(entry);
    _trim();
    if (directory != null) {
      _unwritten.add(entry);
      if (_unwritten.length == 1) _writing = _writing.then((_) => _write());
    }
    _scheduleNotify();
  }

  /// Waits for the entries added so far to be written.
  Future<void> flush() => _writing;

  /// Also logs every `debugPrint` (as a warning when it reports a failure),
  /// so the messages the app already prints show in the log.
  void captureDebugPrint() {
    final print = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      print(message, wrapWidth: wrapWidth);
      if (message == null || message.trim().isEmpty) return;
      final failed = RegExp(
        r'fail|error|exception',
        caseSensitive: false,
      ).hasMatch(message);
      // Already printed above.
      _add(
        failed ? LogLevel.warning : LogLevel.debug,
        'app',
        message,
        echo: false,
      );
    };
  }

  Future<void> _write() async {
    final entries = [..._unwritten];
    _unwritten.clear();
    final byFile = <String, StringBuffer>{};
    for (final entry in entries) {
      (byFile[fileFor(entry.at)!] ??= StringBuffer()).writeln(entry.toLine());
    }
    for (final MapEntry(key: path, value: text) in byFile.entries) {
      try {
        await File(
          path,
        ).writeAsString(text.toString(), mode: FileMode.append, flush: true);
      } catch (e) {
        // ignore: avoid_print
        print('Writing the log to $path failed: $e');
      }
    }
  }

  void _trim() {
    if (_entries.length > capacity) {
      _entries.removeRange(0, _entries.length - capacity);
    }
  }

  /// Tells the listeners once per burst of entries, never inside a build.
  void _scheduleNotify() {
    if (_notifyScheduled || !hasListeners) return;
    _notifyScheduled = true;
    scheduleMicrotask(() {
      _notifyScheduled = false;
      notifyListeners();
    });
  }
}

/// Adds an entry to the app's log ([AppLog.current]).
void appLog(String source, String message, {LogLevel level = LogLevel.info}) =>
    AppLog.current.add(level, source, message);
