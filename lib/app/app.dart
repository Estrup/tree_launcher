import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tree_launcher/app/coordinators/workspace_flow_coordinator.dart';
import 'package:tree_launcher/app/dependencies.dart';
import 'package:tree_launcher/core/design_system/app_snackbar.dart';
import 'package:tree_launcher/features/activity/presentation/controllers/activity_controller.dart';
import 'package:tree_launcher/features/agents/presentation/controllers/agents_controller.dart';
import 'package:tree_launcher/features/github_issues/presentation/controllers/github_issues_controller.dart';
import 'package:tree_launcher/features/github_prs/presentation/controllers/github_prs_controller.dart';
import 'package:tree_launcher/features/jira/presentation/controllers/jira_issues_controller.dart';
import 'package:tree_launcher/features/jira/presentation/controllers/jira_titles_controller.dart';
import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';
import 'package:tree_launcher/features/terminal/presentation/controllers/terminal_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:tree_launcher/screens/home_screen.dart';
import 'package:tree_launcher/theme/app_theme.dart';

class TreeLauncherApp extends StatelessWidget {
  const TreeLauncherApp({super.key, this.dependencies});

  /// Injected by [bootstrap] so the app reuses the singletons whose background
  /// services were already started. Falls back to a fresh instance (e.g. in
  /// widget tests).
  final AppDependencies? dependencies;

  @override
  Widget build(BuildContext context) {
    final dependencies = this.dependencies ?? AppDependencies();
    return MultiProvider(
      providers: [
        Provider.value(value: dependencies),
        ChangeNotifierProvider(
          create: (_) {
            final controller = WorkspaceController.create(
              gitService: dependencies.gitService,
              repoConfigStore: dependencies.repoConfigStore,
              eventStore: dependencies.worktreeEventStore,
            )..loadRepos();
            // Let the agent HTTP API create worktrees through the live
            // controller so writes go through the in-memory → save → notify
            // pipeline (a direct config write would be clobbered).
            dependencies.agentApiServer.registerWorktreeCreator(controller);
            return controller;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final controller = SettingsController(
              store: dependencies.appSettingsStore,
            )..loadSettings();
            // Tag changes from the agent API go through the live controller,
            // like worktree creation above.
            dependencies.agentApiServer.registerJiraTagEditor(controller);
            return controller;
          },
        ),
        ChangeNotifierProxyProvider<SettingsController, TerminalController>(
          create: (_) => TerminalController(),
          // Re-report the terminal colors after a palette switch.
          update: (context, settings, previous) =>
              (previous ?? TerminalController())..syncColors(),
        ),
        ChangeNotifierProxyProvider<TerminalController, AgentsController>(
          create: (_) {
            final controller = AgentsController(
              store: dependencies.agentRunStore,
            )..load();
            // Agents register and report through the live controller, so
            // their cards update at once.
            dependencies.agentApiServer.registerAgentRegistry(controller);
            return controller;
          },
          // Watch the terminal's agent sessions (busy / waiting / exited).
          update: (context, terminal, previous) =>
              previous!..attachTerminal(terminal),
        ),
        ChangeNotifierProvider(
          create: (_) => ActivityController(
            eventStore: dependencies.worktreeEventStore,
            claudeActivity: dependencies.claudeActivity,
            manualPostStore: dependencies.manualPostStore,
          ),
        ),
        ChangeNotifierProxyProvider<WorkspaceController, GithubPrsController>(
          create: (_) => GithubPrsController(),
          update: (context, workspace, previous) {
            final controller = previous ?? GithubPrsController();
            controller.onRequestedMeTransition = (pr) =>
                workspace.clearSnoozeForBranch(pr.headBranch);
            controller.syncToRepo(workspace.selectedRepo);
            return controller;
          },
        ),
        ChangeNotifierProxyProvider<
          WorkspaceController,
          GithubIssuesController
        >(
          create: (_) => GithubIssuesController(),
          update: (context, workspace, previous) {
            final controller = previous ?? GithubIssuesController();
            controller.onMilestoneSelected = (repoPath, number) {
              final repo = workspace.repos
                  .where((r) => r.path == repoPath)
                  .firstOrNull;
              if (repo != null) workspace.updateGithubMilestone(repo, number);
            };
            controller.syncToRepo(workspace.selectedRepo);
            return controller;
          },
        ),
        ChangeNotifierProvider(
          create: (_) =>
              JiraTitlesController(cache: dependencies.jiraIssueCache),
        ),
        ChangeNotifierProxyProvider<WorkspaceController, JiraIssuesController>(
          create: (_) => JiraIssuesController(),
          update: (context, workspace, previous) {
            final controller = previous ?? JiraIssuesController();
            controller.onVersionSelected = (repoPath, version) {
              final repo = workspace.repos
                  .where((r) => r.path == repoPath)
                  .firstOrNull;
              if (repo != null) {
                workspace.updateJiraFixVersion(repo, version.id);
              }
            };
            controller.syncToRepo(workspace.selectedRepo);
            return controller;
          },
        ),
      ],
      child: Builder(
        builder: (context) {
          context.watch<SettingsController>();
          return MaterialApp(
            title: 'TreeLauncher',
            debugShowCheckedModeBanner: false,
            scaffoldMessengerKey: appMessengerKey,
            theme: AppTheme.current,
            home: const WorkspaceFlowCoordinator(child: HomeScreen()),
          );
        },
      ),
    );
  }
}
