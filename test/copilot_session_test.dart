import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/features/agent/data/copilot_tool_registry.dart';
import 'package:tree_launcher/features/copilot/data/sound_service.dart';
import 'package:tree_launcher/features/copilot/domain/copilot_session.dart';
import 'package:tree_launcher/features/copilot/presentation/controllers/copilot_controller.dart';
import 'package:tree_launcher/features/settings/domain/app_settings.dart';
import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';
import 'package:tree_launcher/features/workspace/data/git_service.dart';
import 'package:tree_launcher/features/workspace/domain/repo_config.dart';
import 'package:tree_launcher/features/workspace/domain/worktree.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:tree_launcher/services/config_service.dart';

void main() {
  group('CopilotSession', () {
    test('restores legacy json without a worktreeName', () {
      final session = CopilotSession.fromJson({
        'id': 'session-1',
        'name': 'feature-auth',
        'repoPath': '/tmp/repo',
        'workingDirectory': '/tmp/repo/feature-auth',
        'createdAt': DateTime.utc(2024).toIso8601String(),
      });

      expect(session.name, 'feature-auth');
      expect(session.worktreeName, 'feature-auth');
      expect(session.toJson()['worktreeName'], 'feature-auth');
    });

    test('serializes a promoted title while preserving the worktree name', () {
      final session = CopilotSession(
        id: 'session-2',
        name: 'Refactor login flow',
        worktreeName: 'feature-auth',
        repoPath: '/tmp/repo',
        workingDirectory: '/tmp/repo/feature-auth',
        createdAt: DateTime.utc(2024),
      );

      final restored = CopilotSession.fromJson(session.toJson());

      expect(restored.name, 'Refactor login flow');
      expect(restored.worktreeName, 'feature-auth');
    });
  });

  group('Copilot session rename flow', () {
    test(
      'creates sessions with the worktree name as the initial fallback',
      () async {
        final harness = await _createHarness();
        addTearDown(harness.dispose);

        final session = await harness.copilot.createSession(
          harness.repoPath,
          '${harness.repoPath}/feature-auth',
          'feature-auth',
        );

        expect(session.name, 'feature-auth');
        expect(session.worktreeName, 'feature-auth');
        expect(
          harness.workspace.selectedRepo!.copilotSessions.single.worktreeName,
          'feature-auth',
        );
        expect(
          harness.configService.savedRepos.single.copilotSessions.single.name,
          'feature-auth',
        );
      },
    );

    test('promotes a CLI title and persists the renamed session', () async {
      final harness = await _createHarness();
      addTearDown(harness.dispose);

      final session = await harness.copilot.createSession(
        harness.repoPath,
        '${harness.repoPath}/feature-auth',
        'feature-auth',
      );
      final terminal = harness.copilot.terminalForSession(session.id)!;

      terminal.onTitleChange?.call('Refactor login flow');
      await pumpEventQueue();

      final renamed = harness.workspace.selectedRepo!.copilotSessions.single;
      expect(renamed.name, 'Refactor login flow');
      expect(renamed.worktreeName, 'feature-auth');
      expect(harness.copilot.activeSession!.name, 'Refactor login flow');
      expect(
        harness.configService.savedRepos.single.copilotSessions.single.name,
        'Refactor login flow',
      );
    });

    test(
      'ignores status-only titles for renaming while still tracking activity',
      () async {
        final harness = await _createHarness();
        addTearDown(harness.dispose);

        final session = await harness.copilot.createSession(
          harness.repoPath,
          '${harness.repoPath}/feature-auth',
          'feature-auth',
        );
        final terminal = harness.copilot.terminalForSession(session.id)!;

        terminal.onTitleChange?.call('🤖 Thinking');
        await pumpEventQueue();

        expect(
          harness.workspace.selectedRepo!.copilotSessions.single.name,
          'feature-auth',
        );
        expect(
          harness.copilot.statusForSession(session.id),
          CopilotActivityStatus.working,
        );
      },
    );

    test(
      'does not revert a renamed session back to the worktree title',
      () async {
        final harness = await _createHarness();
        addTearDown(harness.dispose);

        final session = await harness.copilot.createSession(
          harness.repoPath,
          '${harness.repoPath}/feature-auth',
          'feature-auth',
        );
        final terminal = harness.copilot.terminalForSession(session.id)!;

        terminal.onTitleChange?.call('Refactor login flow');
        await pumpEventQueue();
        terminal.onTitleChange?.call('feature-auth');
        await pumpEventQueue();

        expect(
          harness.workspace.selectedRepo!.copilotSessions.single.name,
          'Refactor login flow',
        );
      },
    );

    test(
      'copilot tools still resolve a session by its original worktree name after rename',
      () async {
        final harness = await _createHarness();
        addTearDown(harness.dispose);

        final session = await harness.copilot.createSession(
          harness.repoPath,
          '${harness.repoPath}/feature-auth',
          'feature-auth',
        );
        final terminal = harness.copilot.terminalForSession(session.id)!;
        final registry = CopilotToolRegistry(
          copilotController: harness.copilot,
        );

        terminal.onTitleChange?.call('Refactor login flow');
        await pumpEventQueue();

        final result = await registry.executeTool('focus_copilot_session', {
          'sessionName': 'feature-auth',
        });

        expect(result.payload['focused'], isTrue);
        expect(result.payload['sessionName'], 'Refactor login flow');
        expect(harness.copilot.activeSession!.id, session.id);
      },
    );
  });
}

Future<_TestHarness> _createHarness() async {
  final configService = FakeConfigService();
  final workspace = WorkspaceController(
    gitService: FakeGitService(),
    configService: configService,
  );
  final settings = SettingsController(configService: configService);
  final copilot = CopilotController.create(
    workspaceController: workspace,
    settingsController: settings,
    soundService: FakeSoundService(),
  );

  const repoPath = '/tmp/tree-launcher-copilot-repo';
  await workspace.addRepo(repoPath);

  return _TestHarness(
    repoPath: repoPath,
    workspace: workspace,
    settings: settings,
    copilot: copilot,
    configService: configService,
  );
}

class _TestHarness {
  const _TestHarness({
    required this.repoPath,
    required this.workspace,
    required this.settings,
    required this.copilot,
    required this.configService,
  });

  final String repoPath;
  final WorkspaceController workspace;
  final SettingsController settings;
  final CopilotController copilot;
  final FakeConfigService configService;

  void dispose() {
    copilot.dispose();
    settings.dispose();
    workspace.dispose();
  }
}

class FakeSoundService extends SoundService {
  @override
  Future<void> playSystemSound(CopilotAttentionSound sound) async {}
}

class FakeConfigService extends ConfigService {
  List<RepoConfig> savedRepos = const [];
  AppSettings savedSettings = AppSettings();

  @override
  Future<List<RepoConfig>> loadRepos() async => savedRepos;

  @override
  Future<void> saveRepos(List<RepoConfig> repos) async {
    savedRepos = List<RepoConfig>.from(repos);
  }

  @override
  Future<AppSettings> loadSettings() async => savedSettings;

  @override
  Future<void> saveSettings(AppSettings settings) async {
    savedSettings = settings;
  }
}

class FakeGitService extends GitService {
  @override
  Future<WorktreeListResult> getWorktrees(String repoPath) async {
    return WorktreeListResult(worktrees: const [], isBareLayout: false);
  }

  @override
  Future<bool> isGitRepo(String path) async => true;
}
