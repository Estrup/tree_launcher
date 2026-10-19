import 'package:path_provider/path_provider.dart';

/// Debug-only data directory override, supplied via
/// `--dart-define=DATA_DIR=/some/folder`. Points the database, `config.json`
/// and the backups at another folder, e.g. a copy of the real data to try a
/// migration on. Empty means "not set": the app support directory is used.
const String dataDirectoryOverride = String.fromEnvironment('DATA_DIR');

/// The folder the app keeps its data in: [dataDirectoryOverride] when set,
/// else the app support directory.
Future<String> appDataDirectory() async => dataDirectoryOverride.isNotEmpty
    ? dataDirectoryOverride
    : (await getApplicationSupportDirectory()).path;
