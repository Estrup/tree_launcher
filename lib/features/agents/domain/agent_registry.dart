import 'package:tree_launcher/features/agents/domain/agent_event.dart';
import 'package:tree_launcher/features/agents/domain/agent_run.dart';

/// The agent runs in the running app, for the agent HTTP API.
///
/// Implemented by the live `AgentsController`, so reports go through its
/// in-memory → save → notify pipeline and show in the agent tabs at once.
abstract class AgentRegistry {
  /// Every run, newest update first.
  List<AgentRun> get runs;

  AgentRun? runById(String id);

  /// The run's timeline, oldest first.
  List<AgentEvent> eventsFor(String id);

  /// Registers a run. With [id], updates that run (throws
  /// [AgentNotFoundException] when there is none). Without, returns the
  /// active run that matches it (same kind, repo, worktree and issues) or
  /// creates one, which needs [AgentRegistration.kind] and `repoName`.
  Future<({AgentRun run, bool created})> register(
    AgentRegistration registration, {
    String? id,
  });

  /// Applies [report] to run [id]. Throws [AgentNotFoundException] when there
  /// is no such run.
  Future<AgentRun> report(String id, AgentReport report);
}

class AgentNotFoundException implements Exception {
  const AgentNotFoundException(this.id);

  final String id;

  @override
  String toString() => 'agent not found: $id';
}
