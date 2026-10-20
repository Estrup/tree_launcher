import 'dart:async';
import 'dart:io';

import 'package:tree_launcher/core/design_system/app_snackbar.dart';

/// Opens a URL, file or folder; widgets that open things take one, so tests
/// can check what would open.
typedef UrlOpener = void Function(String target);

/// Opens [target] with macOS `open`: a URL in the default browser, a file or
/// folder in its default app. Shows a notice when that fails.
void openExternal(String target) => unawaited(_open(target));

Future<void> _open(String target) async {
  try {
    final result = await Process.run('open', [target]);
    if (result.exitCode == 0) return;
  } catch (_) {
    // Reported below.
  }
  showAppSnackBar("Couldn't open $target");
}

/// Shows [path] selected in a Finder window. Shows a notice when that fails.
void revealInFinder(String path) => unawaited(_reveal(path));

Future<void> _reveal(String path) async {
  try {
    final result = await Process.run('open', ['-R', path]);
    if (result.exitCode == 0) return;
  } catch (_) {
    // Reported below.
  }
  showAppSnackBar("Couldn't show $path in Finder");
}
