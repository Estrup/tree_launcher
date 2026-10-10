import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tree_launcher/features/activity/data/claude_session_activity.dart';
import 'package:tree_launcher/features/activity/data/worktree_event_store.dart';
import 'package:tree_launcher/features/settings/domain/app_settings.dart';
import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';
import 'package:tree_launcher/features/terminal/domain/claude_cli_command.dart';
import 'package:tree_launcher/features/terminal/presentation/claude_session_actions.dart';
import 'package:tree_launcher/features/terminal/presentation/controllers/terminal_controller.dart';
import 'package:tree_launcher/features/workspace/data/git_service.dart';
import 'package:tree_launcher/features/workspace/domain/repo_config.dart';
import 'package:tree_launcher/features/workspace/domain/worktree.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:tree_launcher/services/config_service.dart';

const _discordArgs = '--channels plugin:discord@claude-plugins-official';

class _FakeConfigService extends ConfigService {
  List<RepoConfig> savedRepos = const [];

  @override
  Future<List<RepoConfig>> loadRepos() async => savedRepos;

  @override
  Future<void> saveRepos(List<RepoConfig> repos) async {
    savedRepos = List<RepoConfig>.from(repos);
  }

  @override
  Future<AppSettings> loadSettings() async => AppSettings();

  @override
  Future<void> saveSettings(AppSettings settings) async {}

  @override
  Future<String?> loadLastSelectedRepoPath() async => null;

  @override
  Future<void> saveLastSelectedRepoPath(String? path) async {}
}

class _FakeGitService extends GitService {
  @override
  Future<WorktreeListResult> getWorktrees(String repoPath) async =>
      WorktreeListResult(worktrees: const [], isBareLayout: false);

  @override
  Future<bool> isGitRepo(String path) async => true;
}

/// Records Claude launches instead of spawning a shell.
class _RecordingTerminal extends TerminalController {
  final launched =
      <({String title, String dir, String repo, String command})>[];
  final running = <String>{};
  final focused = <String>[];

  @override
  void openClaudeSession(
    String title,
    String workingDirectory,
    String repoPath,
    String command,
  ) {
    launched.add((
      title: title,
      dir: workingDirectory,
      repo: repoPath,
      command: command,
    ));
    running.add(workingDirectory);
  }

  @override
  bool focusClaudeSession(String workingDirectory) {
    if (!running.contains(workingDirectory)) return false;
    focused.add(workingDirectory);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('buildClaudeCliCommand', () {
    test('passes the extra args and the prompt after --', () {
      expect(
        buildClaudeCliCommand(extraArgs: _discordArgs, prompt: 'Fix AU2-1'),
        "claude $_discordArgs -- 'Fix AU2-1'",
      );
    });

    test('shell-quotes apostrophes in the prompt', () {
      expect(
        buildClaudeCliCommand(prompt: "Don't break it"),
        "claude -- 'Don'\\''t break it'",
      );
    });

    test('adds --model and --effort after the extra args', () {
      expect(
        buildClaudeCliCommand(
          extraArgs: _discordArgs,
          prompt: 'Fix AU2-1',
          model: 'opus',
          effort: 'high',
        ),
        "claude $_discordArgs --model opus --effort high -- 'Fix AU2-1'",
      );
    });

    test('omits empty args and prompt', () {
      expect(buildClaudeCliCommand(extraArgs: '  ', prompt: ' '), 'claude');
    });

    test('resume continues the last conversation and ignores the prompt', () {
      expect(
        buildClaudeCliCommand(
          extraArgs: _discordArgs,
          prompt: 'ignored',
          resume: true,
        ),
        'claude $_discordArgs --continue',
      );
    });
  });

  group('AppSettings.claudeModel / claudeEffort', () {
    test('default to null and round-trip', () {
      expect(AppSettings().claudeModel, isNull);
      expect(AppSettings().claudeEffort, isNull);
      final json = AppSettings(
        claudeModel: 'opus',
        claudeEffort: 'xhigh',
      ).toJson();
      final restored = AppSettings.fromJson(json);
      expect(restored.claudeModel, 'opus');
      expect(restored.claudeEffort, 'xhigh');
    });

    test('copyWith clears them back to the CLI default', () {
      final cleared = AppSettings(
        claudeModel: 'opus',
        claudeEffort: 'max',
      ).copyWith(clearClaudeModel: true, clearClaudeEffort: true);
      expect(cleared.claudeModel, isNull);
      expect(cleared.claudeEffort, isNull);
    });
  });

  group('AppSettings.claudeCliArgs', () {
    test('defaults to the Discord channel when absent', () {
      expect(AppSettings().claudeCliArgs, _discordArgs);
      expect(AppSettings.fromJson({}).claudeCliArgs, _discordArgs);
    });

    test('round-trips, including an explicitly empty value', () {
      for (final args in ['--model opus', '']) {
        final restored = AppSettings.fromJson(
          AppSettings().copyWith(claudeCliArgs: args).toJson(),
        );
        expect(restored.claudeCliArgs, args);
      }
    });
  });

  group('RepoConfig.claudeSessions', () {
    test('round-trips and defaults to empty', () {
      final repo = RepoConfig(
        name: 'demo',
        path: '/repos/demo',
        claudeSessions: const ['/repos/demo-a'],
      );
      expect(RepoConfig.fromJson(repo.toJson()).claudeSessions, [
        '/repos/demo-a',
      ]);
      expect(
        RepoConfig.fromJson({
          'name': 'demo',
          'path': '/repos/demo',
        }).claudeSessions,
        isEmpty,
      );
    });

    test('ignores malformed entries', () {
      final restored = RepoConfig.fromJson({
        'name': 'demo',
        'path': '/repos/demo',
        'claudeSessions': ['/repos/demo-a', 42, null],
      });
      expect(restored.claudeSessions, ['/repos/demo-a']);
    });
  });

  group('TerminalController Claude sessions', () {
    late TerminalController terminal;

    setUp(() => terminal = TerminalController());
    tearDown(() => terminal.dispose());

    test('evicts the oldest plain terminal, never a Claude session', () {
      terminal.openClaudeSession('Claude: a', '/w/a', '/r', 'claude');
      for (var i = 0; i < TerminalController.maxSessions; i++) {
        terminal.openTerminal('t$i', '/w/t$i', '/r');
      }

      expect(terminal.sessions, hasLength(TerminalController.maxSessions));
      expect(terminal.claudeSessionFor('/w/a'), isNotNull);
      expect(terminal.sessions.map((s) => s.title), isNot(contains('t0')));
    });

    test('exceeds the limit rather than closing a Claude session', () {
      for (var i = 0; i <= TerminalController.maxSessions; i++) {
        terminal.openClaudeSession('Claude: $i', '/w/$i', '/r', 'claude');
      }
      expect(terminal.sessions, hasLength(TerminalController.maxSessions + 1));
    });

    test('a plain terminal does not reuse the Claude session', () {
      terminal.openClaudeSession('Claude: a', '/w/a', '/r', 'claude');
      terminal.openTerminal('a', '/w/a', '/r');

      expect(terminal.sessions, hasLength(2));
      expect(terminal.activeSession!.isClaude, isFalse);
    });

    test('starting Claude where it already runs shows that session', () {
      terminal.openClaudeSession('Claude: a', '/w/a', '/r', 'claude');
      terminal.openTerminal('b', '/w/b', '/r');
      terminal.openClaudeSession('Claude: a', '/w/a', '/r', 'claude');

      expect(terminal.sessions, hasLength(2));
      expect(terminal.activeSession!.workingDirectory, '/w/a');
      expect(terminal.focusClaudeSession('/w/b'), isFalse);
    });
  });

  group('ClaudeSessionLauncher', () {
    late Directory tempDir;
    late _FakeConfigService config;
    late WorkspaceController workspace;
    late SettingsController settings;
    late _RecordingTerminal terminal;
    late String worktree;
    late String projectsDir;

    ClaudeSessionLauncher launcher() => ClaudeSessionLauncher(
      terminal: terminal,
      workspace: workspace,
      settings: settings,
      claudeActivity: ClaudeSessionActivity(claudeProjectsDir: projectsDir),
    );

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('claude_session_test');
      // The settings store resolves the app-support dir even with a fake
      // ConfigService.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => tempDir.path,
          );
      worktree = p.join(tempDir.path, 'repo-a');
      Directory(worktree).createSync();
      projectsDir = p.join(tempDir.path, 'projects');
      config = _FakeConfigService();
      workspace = WorkspaceController(
        gitService: _FakeGitService(),
        configService: config,
        eventStore: WorktreeEventStore(directoryPath: tempDir.path),
      );
      settings = SettingsController(configService: config);
      terminal = _RecordingTerminal();
      await workspace.addRepo('/repos/demo');
    });

    tearDown(() {
      terminal.dispose();
      settings.dispose();
      workspace.dispose();
      tempDir.deleteSync(recursive: true);
    });

    test(
      'start runs Claude with the prompt and remembers the shortcut',
      () async {
        await launcher().start(
          repoPath: '/repos/demo',
          worktreePath: worktree,
          prompt: 'Fix AU2-1',
        );

        expect(terminal.launched.single.title, 'Claude: repo-a');
        expect(terminal.launched.single.repo, '/repos/demo');
        expect(
          terminal.launched.single.command,
          "claude $_discordArgs -- 'Fix AU2-1'",
        );
        expect(config.savedRepos.single.claudeSessions, [worktree]);
        expect(workspace.selectedRepo!.claudeSessions, [worktree]);

        // Starting again doesn't duplicate the shortcut.
        await workspace.rememberClaudeSession('/repos/demo', worktree);
        expect(config.savedRepos.single.claudeSessions, [worktree]);

        await workspace.forgetClaudeSession('/repos/demo', worktree);
        expect(config.savedRepos.single.claudeSessions, isEmpty);
      },
    );

    test('resume shows a running session without starting another', () async {
      terminal.running.add(worktree);
      await launcher().resume(repoPath: '/repos/demo', worktreePath: worktree);

      expect(terminal.focused, [worktree]);
      expect(terminal.launched, isEmpty);
    });

    test('resume continues the last conversation when there is one', () async {
      final sessionDir = Directory(
        p.join(projectsDir, ClaudeSessionActivity.encodeProjectDir(worktree)),
      )..createSync(recursive: true);
      File(p.join(sessionDir.path, 'a.jsonl')).writeAsStringSync('{}');

      await launcher().resume(repoPath: '/repos/demo', worktreePath: worktree);

      expect(
        terminal.launched.single.command,
        'claude $_discordArgs --continue',
      );
    });

    test('resume starts fresh when there is nothing to continue', () async {
      await launcher().resume(repoPath: '/repos/demo', worktreePath: worktree);

      expect(terminal.launched.single.command, 'claude $_discordArgs');
    });

    test('resume drops the shortcut when the worktree is gone', () async {
      final gone = p.join(tempDir.path, 'deleted');
      await workspace.rememberClaudeSession('/repos/demo', gone);

      await launcher().resume(repoPath: '/repos/demo', worktreePath: gone);

      expect(terminal.launched, isEmpty);
      expect(config.savedRepos.single.claudeSessions, isEmpty);
    });
  });
}
