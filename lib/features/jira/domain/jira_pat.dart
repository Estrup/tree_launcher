import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Personal Access Token used to authenticate against the self-hosted Jira
/// Server/Data Center instance. The same file the `jira` skill uses, so the
/// app needs no separate credential setup.
///
/// Resolves `~/.config/jira-pat.txt` via the `HOME` environment variable
/// (macOS-only app, so `HOME` is reliable — matches the rest of the codebase).
/// Returns `null` — never throws — when `HOME` is unset, the file is missing,
/// or it is empty, so callers can surface a clear "no token" message.
String? jiraPatPath() {
  final home = Platform.environment['HOME'];
  if (home == null || home.isEmpty) return null;
  return p.join(home, '.config', 'jira-pat.txt');
}

Future<String?> readJiraPat() async {
  try {
    final path = jiraPatPath();
    if (path == null) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    final pat = (await file.readAsString()).trim();
    return pat.isEmpty ? null : pat;
  } catch (e) {
    debugPrint('readJiraPat failed: $e');
    return null;
  }
}
