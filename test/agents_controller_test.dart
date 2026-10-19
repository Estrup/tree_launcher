import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/core/database/app_database.dart';
import 'package:tree_launcher/features/agents/data/agent_run_store.dart';
import 'package:tree_launcher/features/agents/domain/agent_kind.dart';
import 'package:tree_launcher/features/agents/domain/agent_registry.dart';
import 'package:tree_launcher/features/agents/domain/agent_run.dart';
import 'package:tree_launcher/features/agents/presentation/controllers/agents_controller.dart';
import 'package:tree_launcher/features/terminal/data/claude_desktop_handoff.dart';
import 'package:tree_launcher/features/terminal/data/terminal_session.dart';
import 'package:tree_launcher/features/terminal/presentation/controllers/terminal_controller.dart';

import 'test_database.dart';

/// A session whose shell has a fixed pid, without starting a PTY.
class _FakeSession extends TerminalSession {
  _FakeSession(String agentId, this._pid)
    : super(
        title: 'Claude',
        workingDirectory: '/repos/wt',
        repoPath: '/repos',
        isClaude: true,
        agentId: agentId,
      );

  final int _pid;

  @override
  int? get pid => _pid;
}

class _FakeTerminal extends TerminalController {
  final fakeSessions = <TerminalSession>[];

  @override
  List<TerminalSession> get sessions => fakeSessions;

  @override
  TerminalSession? claudeSessionForAgent(String agentId) =>
      fakeSessions.where((s) => s.agentId == agentId).firstOrNull;

  void changed() => notifyListeners();
}

/// Reports a fixed Claude CLI per shell pid.
class _FakeCliRegistry extends ClaudeCliRegistry {
  _FakeCliRegistry() : super(sessionsDir: '/nonexistent');

  final clis = <int, ClaudeCliProcess>{};

  @override
  Future<Map<int, ClaudeCliProcess>> runningUnderEach(
    Iterable<int> shellPids,
  ) async => {
    for (final pid in shellPids)
      if (clis[pid] != null) pid: clis[pid]!,
  };
}

void main() {
  late AppDatabase db;
  var now = DateTime(2026, 10, 12, 9);

  setUp(() {
    db = testDatabase();
    now = DateTime(2026, 10, 12, 9);
  });

  AgentsController controller({ClaudeCliRegistry? cli}) => AgentsController(
    store: AgentRunStore(db),
    cliRegistry: cli,
    clock: () => now,
    pollInterval: const Duration(milliseconds: 10),
  );

  test('keeps runs and their timelines across restarts', () async {
    final first = controller();
    final run = await first.createForLaunch(
      kind: AgentKind.verify,
      repoName: 'au2office',
      promptName: 'Verify test2',
      issueKeys: const ['AU2-1'],
    );
    await first.report(run.id, const AgentReport(message: 'deployet ✓'));
    await first.flush();

    final second = controller();
    await second.load();
    final loaded = second.runById(run.id)!;
    expect(loaded.promptName, 'Verify test2');
    expect(loaded.state, AgentState.running);
    expect(
      [for (final e in second.eventsFor(run.id)) e.message],
      ['Started: Verify test2', 'deployet ✓'],
    );
  });

  test('drops archived runs older than a month when loading', () async {
    final first = controller();
    final old = await first.createForLaunch(
      kind: AgentKind.build,
      repoName: 'au2office',
    );
    final kept = await first.createForLaunch(
      kind: AgentKind.build,
      repoName: 'au2office',
    );
    await first.setArchived(old.id, true);
    await first.flush();

    now = now.add(const Duration(days: 31));
    final second = controller();
    await second.load();
    await second.flush();

    expect(second.runById(old.id), isNull);
    expect(second.runById(kept.id), isNotNull);
    expect(second.eventsFor(old.id), isEmpty);
  });

  test(
    'lists a repo\'s runs of a kind and counts those that need you',
    () async {
      final agents = controller();
      final a = await agents.createForLaunch(
        kind: AgentKind.build,
        repoName: 'au2office',
      );
      await agents.createForLaunch(kind: AgentKind.docs, repoName: 'au2office');
      await agents.report(
        a.id,
        const AgentReport(state: AgentState.waiting, message: 'Gate 1'),
      );

      expect(agents.runsFor('au2office', AgentKind.build), hasLength(1));
      expect(agents.needsYouCount('au2office', AgentKind.build), 1);
      expect(agents.needsYouCount('au2office', AgentKind.docs), 0);
      expect(agents.hasRunsFor('au2office', AgentKind.review), isFalse);

      await agents.setArchived(a.id, true);
      expect(agents.runsFor('au2office', AgentKind.build), isEmpty);
      expect(agents.hasRunsFor('au2office', AgentKind.build), isFalse);
      await agents.flush();
    },
  );

  test('reports for an unknown run throw', () async {
    final agents = controller();
    expect(
      () => agents.report('ag_none', const AgentReport(message: 'x')),
      throwsA(isA<AgentNotFoundException>()),
    );
  });

  test('watches agent sessions in the terminal', () async {
    final cli = _FakeCliRegistry();
    final terminal = _FakeTerminal();
    final agents = controller(cli: cli);
    final run = await agents.createForLaunch(
      kind: AgentKind.build,
      repoName: 'au2office',
    );
    agents.attachTerminal(terminal);
    expect(agents.livenessOf(run.id), AgentLiveness.none);

    cli.clis[42] = const ClaudeCliProcess(
      pid: 43,
      sessionId: 'sess-1',
      cwd: '/repos/wt',
      status: 'waiting',
    );
    terminal.fakeSessions.add(_FakeSession(run.id, 42));
    terminal.changed();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(agents.livenessOf(run.id), AgentLiveness.waiting);
    expect(agents.needsYou(agents.runById(run.id)!), isTrue);
    expect(agents.runById(run.id)!.claudeSessionId, 'sess-1');

    cli.clis.remove(42);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(agents.livenessOf(run.id), AgentLiveness.exited);

    terminal.fakeSessions.clear();
    terminal.changed();
    expect(agents.livenessOf(run.id), AgentLiveness.none);

    await agents.flush();
    agents.dispose();
  });
}
