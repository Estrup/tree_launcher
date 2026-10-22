import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tree_launcher/app/dependencies.dart';
import 'package:tree_launcher/app/shell/workspace_shell.dart';
import 'package:tree_launcher/core/design_system/app_snackbar.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/github_issues/presentation/controllers/github_issues_controller.dart';
import 'package:tree_launcher/features/github_prs/presentation/controllers/github_prs_controller.dart';
import 'package:tree_launcher/features/jira/presentation/controllers/jira_issues_controller.dart';
import 'package:tree_launcher/features/jira/presentation/controllers/jira_titles_controller.dart';
import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';

class TreeLauncherApp extends StatelessWidget {
  const TreeLauncherApp({super.key, required this.dependencies});

  /// The composition root, built by [bootstrap] (or by a test). Its core
  /// controllers are provided as they are, so the agent API and the widget
  /// tree share them.
  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: dependencies),
        ChangeNotifierProvider.value(value: dependencies.workspace),
        ChangeNotifierProvider.value(value: dependencies.settings),
        ChangeNotifierProvider.value(value: dependencies.terminal),
        ChangeNotifierProvider.value(value: dependencies.sessionPanel),
        ChangeNotifierProvider.value(value: dependencies.agents),
        ChangeNotifierProvider.value(value: dependencies.documents),
        ChangeNotifierProvider.value(value: dependencies.activity),
        Provider.value(value: dependencies.agentLauncher),
        Provider.value(value: dependencies.claudeSessions),
        Provider.value(value: dependencies.startClaudeSession),
        ChangeNotifierProvider.value(value: dependencies.agentApi),
        ChangeNotifierProvider.value(value: dependencies.log),
        ChangeNotifierProvider.value(value: dependencies.jiraTriggers),
        Provider.value(value: dependencies.configFile),
        Provider.value(value: dependencies.launcherService),
        Provider.value(value: dependencies.claudeActivity),
        Provider.value(value: dependencies.jiraService),
        Provider.value(value: dependencies.jiraIssueCache),
        Provider.value(value: dependencies.jiraCommentDrafts),
        Provider.value(value: dependencies.githubIssuesService),
        Provider.value(value: dependencies.githubIssueCache),
        ChangeNotifierProxyProvider<WorkspaceController, GithubPrsController>(
          create: (_) =>
              GithubPrsController(service: dependencies.githubPrsService),
          update: (context, workspace, previous) {
            final controller = previous!;
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
          create: (_) => GithubIssuesController(
            service: dependencies.githubIssuesService,
          ),
          update: (context, workspace, previous) {
            final controller = previous!;
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
          create: (_) => JiraTitlesController(
            service: dependencies.jiraService,
            cache: dependencies.jiraIssueCache,
          ),
        ),
        ChangeNotifierProxyProvider<WorkspaceController, JiraIssuesController>(
          create: (_) =>
              JiraIssuesController(service: dependencies.jiraService),
          update: (context, workspace, previous) {
            final controller = previous!;
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
          // Only a theme change rebuilds the app; AppTheme.current reads the
          // palette SettingsController applied.
          context.select<SettingsController, String>(
            (settings) => settings.settings.themeName,
          );
          return MaterialApp(
            title: 'TreeLauncher',
            debugShowCheckedModeBanner: false,
            scaffoldMessengerKey: appMessengerKey,
            theme: AppTheme.current,
            home: const WorkspaceShell(),
          );
        },
      ),
    );
  }
}
