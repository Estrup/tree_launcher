import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:tree_launcher/core/logging/app_log.dart';

import 'package:tree_launcher/features/agents/data/agent_run_store.dart';
import 'package:tree_launcher/features/agents/domain/agent_event.dart';
import 'package:tree_launcher/features/agents/domain/agent_kind.dart';
import 'package:tree_launcher/features/agents/domain/agent_registry.dart';
import 'package:tree_launcher/features/agents/domain/agent_run.dart';
import 'package:tree_launcher/features/terminal/data/claude_desktop_handoff.dart';
import 'package:tree_launcher/features/terminal/presentation/controllers/terminal_controller.dart';

/// What the app sees of an agent's Claude session in the built-in terminal,
/// next to what the agent reports.
enum AgentLiveness {
  /// No terminal session for the agent (it ended, or runs elsewhere).
  none,

  /// A terminal session that hasn't been checked yet.
  unknown,

  /// The terminal is open but Claude has exited.
  exited,
  idle,
  busy,

  /// Claude has a question or permission prompt open.
  waiting,
}

/// The app's agent runs: what each agent has reported (through the agent API)
/// and, for agents in the built-in terminal, whether their Claude session is
/// busy, idle or waiting for an answer.
class AgentsController extends ChangeNotifier implements AgentRegistry {
  AgentsController({
    required AgentRunStore store,
    ClaudeCliRegistry? cliRegistry,
    DateTime Function()? clock,
    Duration pollInterval = const Duration(seconds: 3),
  }) : _store = store,
       _cliRegistry = cliRegistry ?? ClaudeCliRegistry(),
       _clock = clock ?? DateTime.now,
       _pollInterval = pollInterval;

  /// Archived runs older than this are dropped when the app starts.
  static const archivedRetention = Duration(days: 30);

  /// Timeline events kept in memory per run.
  static const maxEventsPerRun = 300;

  final AgentRunStore _store;
  final ClaudeCliRegistry _cliRegistry;
  final DateTime Function() _clock;
  final Duration _pollInterval;

  final Map<String, AgentRun> _runs = {};
  final Map<String, List<AgentEvent>> _events = {};
  final Map<String, AgentLiveness> _liveness = {};
  Future<void>? _loading;
  Future<void> _saving = Future.value();
  bool _disposed = false;

  TerminalController? _terminal;
  Timer? _pollTimer;
  bool _polling = false;

  /// Loads the saved runs, dropping archived ones past [archivedRetention].
  /// Safe to call more than once.
  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    final runs = await _store.loadRuns();
    final cutoff = _clock().subtract(archivedRetention);
    final kept = runs
        .where((r) => !(r.archived && r.updatedAt.isBefore(cutoff)))
        .toList();
    for (final run in kept) {
      _runs[run.id] = run;
    }
    final events = await _store.loadEvents();
    var dropped = false;
    for (final event in events) {
      if (!_runs.containsKey(event.agentId)) {
        dropped = true;
        continue;
      }
      _events.putIfAbsent(event.agentId, () => []).add(event);
    }
    for (final list in _events.values) {
      if (list.length > maxEventsPerRun) {
        list.removeRange(0, list.length - maxEventsPerRun);
      }
    }
    if (kept.length != runs.length) _persist();
    if (dropped) {
      await _store.replaceEvents([for (final list in _events.values) ...list]);
    }
    _notify();
  }

  /// Waits for pending writes (for tests).
  Future<void> flush() => _saving;

  @override
  List<AgentRun> get runs =>
      _runs.values.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  /// The runs of [kind] in the repo named [repoName], newest update first.
  /// Archived runs are left out unless [includeArchived].
  List<AgentRun> runsFor(
    String repoName,
    AgentKind kind, {
    bool includeArchived = false,
  }) => [
    for (final run in runs)
      if (run.repoName == repoName &&
          run.kind == kind &&
          (includeArchived || !run.archived))
        run,
  ];

  /// Whether the repo has any unarchived run of [kind].
  bool hasRunsFor(String repoName, AgentKind kind) => _runs.values.any(
    (r) => r.repoName == repoName && r.kind == kind && !r.archived,
  );

  /// How many of the repo's runs of [kind] need a human: waiting at a gate,
  /// or with a question or permission prompt open in their terminal.
  int needsYouCount(String repoName, AgentKind kind) => _runs.values
      .where(
        (r) =>
            r.repoName == repoName &&
            r.kind == kind &&
            !r.archived &&
            needsYou(r),
      )
      .length;

  /// Whether [run] waits for a human.
  bool needsYou(AgentRun run) =>
      run.state == AgentState.waiting ||
      (!run.state.isFinished && livenessOf(run.id) == AgentLiveness.waiting);

  @override
  AgentRun? runById(String id) => _runs[id];

  @override
  List<AgentEvent> eventsFor(String id) => List.unmodifiable(_events[id] ?? []);

  @override
  Future<({AgentRun run, bool created})> register(
    AgentRegistration registration, {
    String? id,
  }) async {
    await load();
    final now = _clock();
    if (id != null) {
      final existing = _runs[id];
      if (existing == null) throw AgentNotFoundException(id);
      final run = existing.registered(registration, now);
      _put(run);
      return (run: run, created: false);
    }

    final match = _activeMatch(registration);
    if (match != null) {
      final run = match.registered(registration, now);
      _put(run);
      return (run: run, created: false);
    }

    final kind = registration.kind;
    final repoName = registration.repoName;
    if (kind == null || repoName == null) {
      throw ArgumentError('a new agent needs a kind and a repo');
    }
    final run = AgentRun(
      id: _newId(),
      kind: kind,
      repoName: repoName,
      startedAt: now,
      updatedAt: now,
    ).registered(registration, now);
    _put(run);
    _addEvent(
      AgentEvent(
        agentId: run.id,
        at: now,
        message: 'Registered',
        level: AgentEventLevel.info,
      ),
    );
    return (run: run, created: true);
  }

  /// The active run [registration] describes again (a resumed session that
  /// lost its id): same kind, repo, worktree and issues.
  AgentRun? _activeMatch(AgentRegistration registration) {
    final worktreePath = registration.worktreePath;
    if (worktreePath == null) return null;
    final issues = {...?registration.issueKeys};
    for (final run in runs) {
      if (run.state.isFinished || run.archived) continue;
      if (run.kind == registration.kind &&
          run.repoName == registration.repoName &&
          run.worktreePath == worktreePath &&
          setEquals({...run.issueKeys}, issues)) {
        return run;
      }
    }
    return null;
  }

  @override
  Future<AgentRun> report(String id, AgentReport report) async {
    await load();
    final existing = _runs[id];
    if (existing == null) throw AgentNotFoundException(id);
    final result = existing.reported(report, _clock());
    _put(result.run);
    final event = result.event;
    if (event != null) _addEvent(event);
    return result.run;
  }

  @override
  Future<void> note(
    String id,
    String message, {
    AgentEventLevel level = AgentEventLevel.info,
  }) async {
    await load();
    if (!_runs.containsKey(id)) throw AgentNotFoundException(id);
    _addEvent(
      AgentEvent(agentId: id, at: _clock(), message: message, level: level),
    );
  }

  /// Creates the run for an agent the app is about to launch, so its card
  /// shows at once and the agent can report under its id.
  Future<AgentRun> createForLaunch({
    required AgentKind kind,
    required String repoName,
    String? promptName,
    String? title,
    List<String> issueKeys = const [],
    String? worktreePath,
    String? branch,
    int? prNumber,
    String? model,
    String? effort,
  }) async {
    await load();
    final now = _clock();
    final run = AgentRun(
      id: _newId(),
      kind: kind,
      repoName: repoName,
      promptName: promptName,
      title: title,
      issueKeys: issueKeys,
      worktreePath: worktreePath,
      branch: branch,
      prNumber: prNumber,
      model: model,
      effort: effort,
      startedAt: now,
      updatedAt: now,
    );
    _put(run);
    _addEvent(
      AgentEvent(
        agentId: run.id,
        at: now,
        message: promptName == null ? 'Started' : 'Started: $promptName',
      ),
    );
    return run;
  }

  /// Marks the run as stopped by the user.
  Future<void> markStopped(String id) => report(
    id,
    const AgentReport(
      state: AgentState.stopped,
      message: 'Stopped from Tree Launcher',
      level: AgentEventLevel.warning,
    ),
  );

  /// Moves the run in or out of the archive.
  Future<void> setArchived(String id, bool archived) async {
    final run = _runs[id];
    if (run == null || run.archived == archived) return;
    _put(run.copyWith(archived: archived));
  }

  /// Removes the run and its timeline.
  Future<void> delete(String id) async {
    if (_runs.remove(id) == null) return;
    _events.remove(id);
    _liveness.remove(id);
    _persist();
    final remaining = [for (final list in _events.values) ...list];
    _saving = _saving.then((_) => _store.replaceEvents(remaining));
    _notify();
  }

  void _put(AgentRun run) {
    _runs[run.id] = run;
    _persist();
    _notify();
  }

  void _addEvent(AgentEvent event) {
    final run = _runs[event.agentId];
    appLog(
      'agents',
      '${run == null ? event.agentId : '${run.kind.label} ${run.id} '
                    '(${run.repoName}${run.issueKeys.isEmpty ? '' : ', ${run.issueKeys.join(', ')}'})'}'
          '${event.stage == null ? '' : ' [${event.stage}]'}: ${event.message}',
      level: switch (event.level) {
        AgentEventLevel.warning => LogLevel.warning,
        AgentEventLevel.error => LogLevel.error,
        _ => LogLevel.info,
      },
    );
    final list = _events.putIfAbsent(event.agentId, () => []);
    list.add(event);
    if (list.length > maxEventsPerRun) list.removeAt(0);
    _saving = _saving.then((_) => _store.appendEvent(event));
    _notify();
  }

  void _persist() {
    final snapshot = _runs.values.toList();
    _saving = _saving.then((_) => _store.saveRuns(snapshot));
  }

  static final _random = Random.secure();
  static const _idChars = 'abcdefghijklmnopqrstuvwxyz0123456789';

  String _newId() {
    String id;
    do {
      id =
          'ag_${List.generate(8, (_) => _idChars[_random.nextInt(_idChars.length)]).join()}';
    } while (_runs.containsKey(id));
    return id;
  }

  // ---------------------------------------------------------------------------
  // Liveness of agents in the built-in terminal
  // ---------------------------------------------------------------------------

  /// Watches [terminal]'s agent sessions. Called from the provider tree, so it
  /// may be called again with the same controller.
  void attachTerminal(TerminalController terminal) {
    if (identical(terminal, _terminal)) return;
    _terminal?.removeListener(_onTerminalChanged);
    _terminal = terminal;
    terminal.addListener(_onTerminalChanged);
    _onTerminalChanged();
  }

  /// What the built-in terminal shows of agent [id]'s Claude session.
  AgentLiveness livenessOf(String id) {
    final session = _terminal?.claudeSessionForAgent(id);
    if (session == null) return AgentLiveness.none;
    return _liveness[id] ?? AgentLiveness.unknown;
  }

  void _onTerminalChanged() {
    final hasAgents = _agentSessionPids().isNotEmpty;
    if (hasAgents && _pollTimer == null) {
      _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
      _poll();
    } else if (!hasAgents && _pollTimer != null) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
    // Sessions that closed lose their liveness.
    final live = _agentSessionPids().keys.toSet();
    final before = _liveness.length;
    _liveness.removeWhere((id, _) => !live.contains(id));
    if (_liveness.length != before) _notify();
  }

  /// Agent id → shell pid of each live agent terminal session.
  Map<String, int> _agentSessionPids() {
    final terminal = _terminal;
    if (terminal == null) return const {};
    return {
      for (final session in terminal.sessions)
        if (session.agentId != null &&
            !session.isDisposed &&
            session.pid != null)
          session.agentId!: session.pid!,
    };
  }

  Future<void> _poll() async {
    if (_polling || _disposed) return;
    _polling = true;
    try {
      final pids = _agentSessionPids();
      if (pids.isEmpty) return;
      final clis = await _cliRegistry.runningUnderEach(pids.values);
      var changed = false;
      for (final MapEntry(key: id, value: pid) in pids.entries) {
        final cli = clis[pid];
        final liveness = cli == null
            ? AgentLiveness.exited
            : switch (cli.status) {
                'busy' => AgentLiveness.busy,
                'waiting' => AgentLiveness.waiting,
                _ => AgentLiveness.idle,
              };
        if (_liveness[id] != liveness) {
          _liveness[id] = liveness;
          changed = true;
        }
        final run = _runs[id];
        if (cli != null &&
            run != null &&
            run.claudeSessionId != cli.sessionId) {
          _runs[id] = run.copyWith(claudeSessionId: cli.sessionId);
          _persist();
          changed = true;
        }
      }
      if (changed) _notify();
    } finally {
      _polling = false;
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    _terminal?.removeListener(_onTerminalChanged);
    super.dispose();
  }
}
