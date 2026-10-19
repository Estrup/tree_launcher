import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/core/database/app_database.dart';

/// An empty in-memory [AppDatabase], closed when the current test ends.
/// Call it from a test or `setUp`.
AppDatabase testDatabase() {
  // Every test opens its own; that's intended.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final db = AppDatabase.memory();
  addTearDown(db.close);
  return db;
}
