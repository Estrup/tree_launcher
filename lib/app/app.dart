import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tree_launcher/app/coordinators/workspace_flow_coordinator.dart';
import 'package:tree_launcher/app/dependencies.dart';
import 'package:tree_launcher/app/shell/workspace_shell.dart';
import 'package:tree_launcher/core/design_system/app_snackbar.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/activity/presentation/controllers/activity_controller.dart';
import 'package:tree_launcher/features/builds/presentation/controllers/builds_controller.dart';
import 'package:tree_launcher/features/copilot/presentation/controllers/copilot_controller.dart';
import 'package:tree_launcher/features/github_prs/presentation/controllers/github_prs_controller.dart';
import 'package:tree_launcher/features/github_prs/presentation/pr_worktree_actions.dart';
import 'package:tree_launcher/features/markdown_editor/presentation/controllers/markdown_editor_controller.dart';
import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';
import 'package:tree_launcher/features/terminal/presentation/controllers/terminal_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';

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
          create: (_) =>
              SettingsController(store: dependencies.appSettingsStore)
                ..loadSettings(),
        ),
        ChangeNotifierProvider(create: (_) => TerminalController()),
        ChangeNotifierProvider(create: (_) => BuildsController()),
        ChangeNotifierProvider(
          create: (_) =>
              ActivityController(eventStore: dependencies.worktreeEventStore),
        ),
        ChangeNotifierProxyProvider<WorkspaceController, GithubPrsController>(
          create: (_) => GithubPrsController(),
          update: (context, workspace, previous) {
            final controller = previous ?? GithubPrsController();
            controller.onReviewRequested = (pr) =>
                createWorktreeForPr(workspace, pr);
            controller.onRequestedMeTransition = (pr) =>
                workspace.clearSnoozeForBranch(pr.headBranch);
            controller.syncToRepo(workspace.selectedRepo);
            return controller;
          },
        ),
        ChangeNotifierProxyProvider2<
          WorkspaceController,
          SettingsController,
          CopilotController
        >(
          create: (context) => CopilotController.create(
            workspaceController: context.read<WorkspaceController>(),
            settingsController: context.read<SettingsController>(),
            soundService: dependencies.soundService,
          ),
          update: (context, workspaceController, settingsController, previous) {
            previous?.updateDependencies(
              workspaceController: workspaceController,
              settingsController: settingsController,
            );
            return previous ??
                CopilotController.create(
                  workspaceController: workspaceController,
                  settingsController: settingsController,
                  soundService: dependencies.soundService,
                );
          },
        ),
        ChangeNotifierProxyProvider2<
          SettingsController,
          CopilotController,
          MarkdownEditorController
        >(
          create: (context) => MarkdownEditorController(
            settingsController: context.read<SettingsController>(),
            copilotController: context.read<CopilotController>(),
          ),
          update: (context, settingsController, copilotController, previous) {
            return previous ??
                MarkdownEditorController(
                  settingsController: settingsController,
                  copilotController: copilotController,
                );
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
            theme: AppTheme.dark,
            darkTheme: AppTheme.dark,
            themeMode: ThemeMode.dark,
            home: const WorkspaceFlowCoordinator(child: WorkspaceShell()),
          );
        },
      ),
    );
  }
}
