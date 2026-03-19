import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tree_launcher/app/coordinators/remote_control_coordinator.dart';
import 'package:tree_launcher/app/coordinators/workspace_flow_coordinator.dart';
import 'package:tree_launcher/app/dependencies.dart';
import 'package:tree_launcher/app/shell/workspace_shell.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/agent/presentation/controllers/agent_panel_controller.dart';
import 'package:tree_launcher/features/builds/presentation/controllers/builds_controller.dart';
import 'package:tree_launcher/features/copilot/presentation/controllers/copilot_controller.dart';
import 'package:tree_launcher/features/github_prs/presentation/controllers/github_prs_controller.dart';
import 'package:tree_launcher/features/kanban/presentation/controllers/kanban_controller.dart';
import 'package:tree_launcher/features/markdown_editor/presentation/controllers/markdown_editor_controller.dart';
import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';
import 'package:tree_launcher/features/terminal/presentation/controllers/terminal_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';

class TreeLauncherApp extends StatelessWidget {
  const TreeLauncherApp({super.key});

  @override
  Widget build(BuildContext context) {
    final dependencies = AppDependencies();
    return MultiProvider(
      providers: [
        Provider.value(value: dependencies),
        ChangeNotifierProvider(
          create: (_) => WorkspaceController.create(
            gitService: dependencies.gitService,
            repoConfigStore: dependencies.repoConfigStore,
          )..loadRepos(),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              SettingsController(store: dependencies.appSettingsStore)
                ..loadSettings(),
        ),
        ChangeNotifierProvider(create: (_) => TerminalController()),
        ChangeNotifierProvider(create: (_) => KanbanController()),
        ChangeNotifierProvider(create: (_) => BuildsController()),
        ChangeNotifierProvider(create: (_) => GithubPrsController()),
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
        ChangeNotifierProxyProvider3<
          WorkspaceController,
          SettingsController,
          CopilotController,
          AgentPanelController
        >(
          create: (context) => AgentPanelController(
            microphoneRecordingService: dependencies.microphoneRecordingService,
            chatGptService: dependencies.chatGptService,
            workspaceController: context.read<WorkspaceController>(),
            settingsController: context.read<SettingsController>(),
            copilotController: context.read<CopilotController>(),
          ),
          update: (context, workspaceController, settingsController,
              copilotController, previous) {
            previous?.updateDependencies(
              workspaceController: workspaceController,
              settingsController: settingsController,
              copilotController: copilotController,
            );
            return previous ??
                AgentPanelController(
                  microphoneRecordingService:
                      dependencies.microphoneRecordingService,
                  chatGptService: dependencies.chatGptService,
                  workspaceController: workspaceController,
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
            theme: AppTheme.dark,
            darkTheme: AppTheme.dark,
            themeMode: ThemeMode.dark,
            home: const RemoteControlCoordinator(
              child: WorkspaceFlowCoordinator(child: WorkspaceShell()),
            ),
          );
        },
      ),
    );
  }
}
