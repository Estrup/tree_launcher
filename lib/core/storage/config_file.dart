import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:tree_launcher/core/storage/app_data_directory.dart';

/// The app's `config.json`: one JSON object whose top-level keys are owned by
/// different stores (`repos` and `lastSelectedRepoPath` by `RepoConfigStore`,
/// `settings` by `AppSettingsStore`).
///
/// Every read and write goes through one instance, serialised on a single
/// chain, so two saves of different sections can't interleave and put back a
/// stale copy of each other's section. Writes go to a temporary file that is
/// renamed over the original, so a reader (or a crash) never sees a
/// half-written file.
///
/// The app creates one instance, in `AppDependencies`, and hands it to every
/// store that owns a section.
class ConfigFile {
  /// [path] defaults to `config.json` in the app's data directory.
  ConfigFile({String? path}) : _path = path;

  static const fileName = 'config.json';

  final String? _path;

  /// Completes when the last queued read or write is done.
  Future<void> _tail = Future.value();

  Future<String> get path async =>
      _path ?? p.join(await appDataDirectory(), fileName);

  /// The whole file, decoded. A missing file reads as empty.
  Future<Map<String, dynamic>> read() => _locked(_read);

  /// Reads the file, lets [change] edit the decoded object in place, and
  /// writes it back, with no other read or write in between. Returns what
  /// [change] returns. Nothing is written if [change] throws.
  Future<T> update<T>(
    FutureOr<T> Function(Map<String, dynamic> config) change,
  ) => _locked(() async {
    final config = await _read();
    final result = await change(config);
    await _write(config);
    return result;
  });

  Future<T> _locked<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<Map<String, dynamic>> _read() async {
    final file = File(await path);
    if (!await file.exists()) {
      return {'repos': [], 'settings': {}};
    }
    return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  }

  Future<void> _write(Map<String, dynamic> config) async {
    final target = await path;
    await File(target).parent.create(recursive: true);
    // Per-process name, so a second instance (a debug build) writing at the
    // same moment can't overwrite this one's temporary file.
    final tmp = File('$target.$pid.tmp');
    await tmp.writeAsString(
      const JsonEncoder.withIndent('  ').convert(config),
      flush: true,
    );
    await tmp.rename(target);
  }
}
