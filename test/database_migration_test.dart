import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/core/database/app_database.dart';

import 'generated_migrations/schema.dart';

/// Checks each schema version's migration against the dumps in
/// `drift_schemas/` (regenerate the helpers with
/// `dart run drift_dev schema generate drift_schemas/ test/generated_migrations/`).
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  for (final (from, to) in [(1, 2), (2, 3), (3, 4), (1, 4)]) {
    test('migrates from v$from to v$to', () async {
      final schema = await verifier.schemaAt(from);
      final db = AppDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, to);
    });
  }

  test('a new database matches the latest dump', () async {
    final schema = await verifier.schemaAt(4);
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 4);
  });

  test('keeps the data of v1 when migrating to the latest', () async {
    final schema = await verifier.schemaAt(1);
    schema.rawDatabase.execute(
      "INSERT INTO manual_posts (id, at, repo_name, issue_key, description) "
      "VALUES ('p1', '2026-10-19T10:00:00.000', 'demo', 'AU2-1', 'Review')",
    );
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 4);

    final posts = await db.select(db.manualPosts).get();
    expect(posts.single.issueKey, 'AU2-1');
    expect(await db.select(db.worktreeMeta).get(), isEmpty);
    expect(await db.select(db.documents).get(), isEmpty);
  });
}
