import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:tree_launcher/app/use_cases/agent_launcher.dart';
import 'package:tree_launcher/app/use_cases/claude_session_launcher.dart';
import 'package:tree_launcher/app/use_cases/start_claude_session.dart';
import 'package:tree_launcher/features/activity/data/claude_session_activity.dart';
import 'package:tree_launcher/features/agents/data/agent_run_store.dart';
import 'package:tree_launcher/features/agents/presentation/controllers/agents_controller.dart';
import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';
import 'package:tree_launcher/features/terminal/presentation/controllers/terminal_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';

import 'test_database.dart';

/// The launch use cases the composition root provides, built over the given
/// controllers, as providers for a widget test. Without [agents], agent runs
/// go to a controller of their own on an in-memory database.
List<SingleChildWidget> launchUseCaseProviders({
  required TerminalController terminal,
  required WorkspaceController workspace,
  required SettingsController settings,
  AgentsController? agents,
  ClaudeSessionActivity? claudeActivity,
}) {
  final runs = agents ?? AgentsController(store: AgentRunStore(testDatabase()));
  if (agents == null) addTearDown(runs.dispose);
  final activity = claudeActivity ?? ClaudeSessionActivity();
  final agentLauncher = AgentLauncher(
    terminal: terminal,
    agents: runs,
    workspace: workspace,
    settings: settings,
    claudeActivity: activity,
  );
  final sessions = ClaudeSessionLauncher(
    terminal: terminal,
    workspace: workspace,
    settings: settings,
    claudeActivity: activity,
    agents: agentLauncher,
  );
  return [
    Provider.value(value: agentLauncher),
    Provider.value(value: sessions),
    Provider.value(
      value: StartClaudeSession(
        settings: settings,
        sessions: sessions,
        agents: agentLauncher,
      ),
    ),
  ];
}
