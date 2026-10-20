import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tree_launcher/features/activity/data/claude_session_activity.dart';
import 'package:tree_launcher/features/activity/data/worktree_event_store.dart';
import 'package:tree_launcher/features/settings/domain/app_settings.dart';
import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';
import 'package:tree_launcher/features/terminal/domain/claude_cli_command.dart';
import 'package:tree_launcher/app/use_cases/claude_session_launcher.dart';
import 'package:tree_launcher/features/terminal/data/terminal_session.dart';
import 'package:tree_launcher/features/terminal/presentation/controllers/terminal_controller.dart';
import 'package:tree_launcher/features/workspace/data/git_service.dart';
import 'package:tree_launcher/features/workspace/domain/worktree.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';

import 'fake_config_stores.dart';
import 'test_database.dart';

const _discordArgs = '--channels plugin:discord@claude-plugins-official';

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
      <
        ({
          String title,
          String dir,
          String repo,
          String command,
          bool reuseRunning,
          bool show,
        })
      >[];
  final running = <String>{};
  final focused = <String>[];

  @override
  TerminalSession? openClaudeSession(
    String title,
    String workingDirectory,
    String repoPath,
    String command, {
    bool reuseRunning = true,
    Map<String, String> environment = const {},
    bool show = true,
  }) {
    launched.add((
      title: title,
      dir: workingDirectory,
      repo: repoPath,
      command: command,
      reuseRunning: reuseRunning,
      show: show,
    ));
    running.add(workingDirectory);
    return null;
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

    test('resumes a session by id, quoted', () {
      expect(
        buildClaudeCliCommand(
          prompt: 'ignored',
          model: 'opus',
          resume: true,
          resumeSessionId: 'abc-123',
        ),
        "claude --model opus --resume 'abc-123'",
      );
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

    test('starts a session in the background without showing it', () {
      terminal.openTerminal('t', '/w/t', '/r');
      terminal.hide();

      final session = terminal.openClaudeSession(
        'Claude: a',
        '/w/a',
        '/r',
        'claude',
        show: false,
      );

      expect(terminal.sessions, hasLength(2));
      expect(terminal.isVisible, isFalse);
      expect(terminal.activeSession!.title, 't');

      terminal.showSession(session!);
      expect(terminal.isVisible, isTrue);
      expect(terminal.activeSession, same(session));
    });

    test("stopping a worktree's sessions leaves agents and terminals", () {
      terminal.openClaudeSession('Claude: a', '/w/a', '/r', 'claude');
      terminal.openAgentSession(
        'Docs: AU2-1',
        '/w/a',
        '/r',
        'claude',
        agentId: 'ag_1',
      );
      terminal.openTerminal('a', '/w/a', '/r');

      terminal.closeClaudeSessions('/w/a');

      expect(terminal.claudeSessionFor('/w/a')!.agentId, 'ag_1');
      expect(terminal.sessions.map((s) => s.title), ['Docs: AU2-1', 'a']);
    });

    test('starts a second session in the same checkout on request', () {
      terminal.openClaudeSession('Claude: a', '/w/a', '/r', 'claude');
      terminal.openClaudeSession(
        'Claude: a · AU2-2',
        '/w/a',
        '/r',
        'claude',
        reuseRunning: false,
      );

      expect(terminal.sessions, hasLength(2));
      expect(terminal.sessions.map((s) => s.workingDirectory), [
        '/w/a',
        '/w/a',
      ]);
      expect(terminal.activeSession!.title, 'Claude: a · AU2-2');
    });
  });

  group('ClaudeSessionLauncher', () {
    late Directory tempDir;
    late FakeRepoConfigStore config;
    late MemoryWorktreeMetadataStore metadataStore;
    late WorkspaceController workspace;
    late SettingsController settings;
    late _RecordingTerminal terminal;
    late String worktree;
    late String projectsDir;

    /// The worktrees with a saved Claude session shortcut.
    List<String> savedSessions() => [
      for (final m in metadataStore.saved.values)
        if (m.session != null) m.path,
    ];

    /// The prompt each saved session was started with.
    Map<String, String?> savedPrompts() => {
      for (final m in metadataStore.saved.values)
        if (m.session != null) m.path: m.session!.promptId,
    };

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
      config = FakeRepoConfigStore();
      metadataStore = MemoryWorktreeMetadataStore();
      workspace = WorkspaceController(
        gitService: _FakeGitService(),
        repoConfigStore: config,
        eventStore: WorktreeEventStore(testDatabase()),
        metadataStore: metadataStore,
      );
      settings = SettingsController(store: FakeAppSettingsStore());
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
        expect(savedSessions(), [worktree]);
        expect(
          [
            for (final m in workspace.metadata.sessionsFor('/repos/demo'))
              m.path,
          ],
          [worktree],
        );

        // Starting again doesn't duplicate the shortcut, and records the
        // latest prompt.
        await workspace.rememberClaudeSession(
          '/repos/demo',
          worktree,
          promptId: 'Verify',
        );
        expect(savedSessions(), [worktree]);
        expect(savedPrompts(), {worktree: 'Verify'});

        await workspace.forgetClaudeSession('/repos/demo', worktree);
        expect(savedSessions(), isEmpty);
        expect(savedPrompts(), isEmpty);
      },
    );

    test('start runs in the background unless asked to show it', () async {
      final title = await launcher().start(
        repoPath: '/repos/demo',
        worktreePath: worktree,
      );
      await launcher().start(
        repoPath: '/repos/demo',
        worktreePath: worktree,
        show: true,
      );

      expect(title, 'Claude: repo-a');
      expect([for (final l in terminal.launched) l.show], [false, true]);
    });

    test('start runs next to a session already in the worktree', () async {
      terminal.running.add(worktree);
      await launcher().start(
        repoPath: '/repos/demo',
        worktreePath: worktree,
        prompt: 'Fix AU2-2',
        issueKey: 'AU2-2',
      );

      expect(terminal.focused, isEmpty);
      expect(terminal.launched.single.title, 'Claude: repo-a · AU2-2');
      expect(terminal.launched.single.reuseRunning, isFalse);
    });

    test('claudeSessionTitle leaves out an issue the name already has', () {
      expect(
        claudeSessionTitle('/w/fix-au2-2', issueKey: 'AU2-2'),
        'Claude: fix-au2-2',
      );
    });

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
      expect(savedSessions(), isEmpty);
    });
  });
}
