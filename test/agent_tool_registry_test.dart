import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/features/agent/data/agent_tool_registry.dart';
import 'package:tree_launcher/features/agent/data/copilot_tool_registry.dart';
import 'package:tree_launcher/features/copilot/data/sound_service.dart';
import 'package:tree_launcher/features/copilot/presentation/controllers/copilot_controller.dart';
import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';
import 'package:tree_launcher/features/workspace/data/git_service.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:tree_launcher/services/repo_action_tool_registry.dart';

void main() {
  group('AgentToolRegistry.buildSystemPrompt', () {
    test('prioritizes prose, next steps, and open questions', () {
      final workspaceController = WorkspaceController(gitService: GitService());
      final settingsController = SettingsController();
      final copilotController = CopilotController.create(
        workspaceController: workspaceController,
        settingsController: settingsController,
        soundService: SoundService(),
      );
      addTearDown(() {
        copilotController.dispose();
        settingsController.dispose();
        workspaceController.dispose();
      });

      final registry = AgentToolRegistry(
        repoToolRegistry: RepoActionToolRegistry(
          repoProvider: workspaceController,
        ),
        copilotToolRegistry: CopilotToolRegistry(
          copilotController: copilotController,
        ),
      );

      final prompt = registry.buildSystemPrompt();

      expect(prompt, contains("Focus on the copilot's human-readable prose"));
      expect(
        prompt,
        contains('Do not narrate tool calls, file insertions, patches'),
      );
      expect(
        prompt,
        contains(
          'Always call out any concrete next step the user needs to take',
        ),
      );
      expect(prompt, contains('unresolved question, blocker, or decision'));
      expect(
        prompt,
        contains('If there is no user action needed, make that clear'),
      );
    });
  });
}
