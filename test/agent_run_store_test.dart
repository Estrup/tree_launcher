import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/core/database/app_database.dart';
import 'package:tree_launcher/features/agents/data/agent_run_store.dart';
import 'package:tree_launcher/features/agents/domain/agent_event.dart';
import 'package:tree_launcher/features/agents/domain/agent_kind.dart';
import 'package:tree_launcher/features/agents/domain/agent_run.dart';

import 'test_database.dart';

void main() {
  late AppDatabase db;
  late AgentRunStore store;

  setUp(() {
    db = testDatabase();
    store = AgentRunStore(db);
  });

  AgentRun run(String id, {String? summary}) => AgentRun(
    id: id,
    kind: AgentKind.verify,
    repoName: 'au2office',
    issueKeys: const ['AU2-1'],
    summary: summary,
    startedAt: DateTime(2026, 10, 12, 9),
    updatedAt: DateTime(2026, 10, 12, 9),
  );

  AgentEvent event(String runId, String message) => AgentEvent(
    agentId: runId,
    at: DateTime(2026, 10, 12, 9, 30),
    message: message,
  );

  test('saveRuns writes only the runs that changed', () async {
    await store.saveRuns([run('ag_a'), run('ag_b')]);
    // Changed behind the store's back: rewriting ag_b would undo this.
    await (db.update(db.agentRuns)..where((t) => t.id.equals('ag_b'))).write(
      const AgentRunsCompanion(title: Value('elsewhere')),
    );

    await store.saveRuns([run('ag_a', summary: 'step 2'), run('ag_b')]);

    final runs = {for (final r in await AgentRunStore(db).loadRuns()) r.id: r};
    expect(runs['ag_a']!.summary, 'step 2');
    expect(runs['ag_b']!.title, 'elsewhere');
  });

  test('saveRuns deletes a removed run with its events', () async {
    await store.saveRuns([run('ag_a'), run('ag_b')]);
    await store.appendEvent(event('ag_a', 'started'));
    await store.appendEvent(event('ag_b', 'started'));

    await store.saveRuns([run('ag_b')]);

    expect((await store.loadRuns()).map((r) => r.id), ['ag_b']);
    expect((await store.loadEvents()).map((e) => e.agentId), ['ag_b']);
  });

  test('saveRuns leaves runs another instance added', () async {
    await store.saveRuns([run('ag_a')]);
    await AgentRunStore(db).saveRuns([run('ag_other')]);

    await store.saveRuns([run('ag_a', summary: 'later')]);

    final ids = (await AgentRunStore(db).loadRuns()).map((r) => r.id);
    expect(ids, unorderedEquals(['ag_a', 'ag_other']));
  });

  test('updating a run keeps its events', () async {
    await store.saveRuns([run('ag_a')]);
    await store.appendEvent(event('ag_a', 'started'));

    await store.saveRuns([run('ag_a', summary: 'step 2')]);

    expect(await store.loadEvents(), hasLength(1));
  });

  test('replaceEvents keeps only the given events of saved runs', () async {
    await store.saveRuns([run('ag_a')]);
    await store.appendEvent(event('ag_a', 'one'));
    await store.appendEvent(event('ag_a', 'two'));

    await store.replaceEvents([
      event('ag_a', 'two'),
      event('ag_unknown', 'dropped'),
    ]);

    expect((await store.loadEvents()).map((e) => e.message), ['two']);
  });
}
