import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tree_launcher/core/logging/app_log.dart';
import 'package:tree_launcher/app/use_cases/jira_trigger_watcher.dart';
import 'package:tree_launcher/features/agents/domain/claude_session_starter.dart';
import 'package:tree_launcher/features/jira/data/jira_api_service.dart';
import 'package:tree_launcher/features/jira/data/jira_trigger_store.dart';
import 'package:tree_launcher/features/jira/domain/jira_issue.dart';
import 'package:tree_launcher/features/jira/domain/jira_trigger.dart';
import 'package:tree_launcher/features/jira/domain/jira_trigger_schedule.dart';
import 'package:tree_launcher/features/settings/domain/app_settings.dart';
import 'package:tree_launcher/features/settings/domain/app_settings_source.dart';
import 'package:tree_launcher/features/workspace/domain/repo_catalog.dart';
import 'package:tree_launcher/features/workspace/domain/repo_config.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_metadata.dart';

import 'test_database.dart';

class _Repos implements RepoCatalog {
  _Repos(this.repos);

  @override
  List<RepoConfig> repos;

  @override
  Future<void> get whenLoaded => Future.value();
}

class _Settings implements AppSettingsSource {
  @override
  AppSettings settings = AppSettings(defaultBranchPrefix: 'feature');
}

/// Answers every search with [issues], recording the JQL.
class _Jira extends JiraApiService {
  List<JiraIssue> issues = [];
  final searched = <String>[];

  @override
  Future<List<JiraIssue>> searchIssues(String jql) async {
    searched.add(jql);
    return issues;
  }
}

class _Starter implements ClaudeSessionStarter {
  final requests = <ClaudeSessionRequest>[];
  Object? failWith;

  @override
  Future<StartedClaudeSession> start(ClaudeSessionRequest request) async {
    requests.add(request);
    if (failWith != null) throw failWith!;
    final created = request.newWorktree;
    final name = created?.worktreeName ?? p.basename(request.existingWorktree!);
    return StartedClaudeSession(
      repoName: request.repoName,
      worktree: StartedWorktree(
        name: name,
        path: '/repos/$name',
        branch: created?.newBranch ?? 'b',
        baseBranch: created?.baseBranch,
        created: created != null,
      ),
      title: 't',
    );
  }
}

void main() {
  late _Jira jira;
  late _Starter starter;
  late JiraTriggerStore store;
  late List<String> notices;
  late List<WorktreeMetadata> worktrees;
  late Set<String> running;
  late _Settings settings;
  late DateTime now;

  final rejected = JiraTrigger(
    id: 'qa',
    fixVersionId: '2',
    since: DateTime(2026, 10, 21),
    status: 'QA Rejected',
    assignedToMe: true,
    promptName: 'Fix',
  );

  RepoConfig repo({List<JiraTrigger>? triggers}) => RepoConfig(
    name: 'demo',
    path: '/repos/demo',
    jiraProjectKey: 'AU2',
    jiraVersionBranches: {'2': 'releases/2.41'},
    jiraTriggers: triggers ?? [rejected],
  );

  JiraTriggerWatcher watcher(RepoConfig repo) => JiraTriggerWatcher(
    repos: _Repos([repo]),
    settings: settings,
    jira: jira,
    store: store,
    starter: starter,
    worktreesOf: (_) => worktrees,
    isRunning: (_, key) => running.contains(key),
    notify: (message, {action}) => notices.add(message),
    now: () => now,
  );

  setUp(() {
    AppLog.current = AppLog();
    jira = _Jira();
    starter = _Starter();
    store = JiraTriggerStore(testDatabase());
    notices = [];
    worktrees = [];
    running = {};
    settings = _Settings();
    now = DateTime(2026, 10, 21, 12);
  });

  test('starts once per issue in a new worktree from the version\'s '
      'branch', () async {
    jira.issues = [
      const JiraIssue(key: 'AU2-7', summary: 'Fix login', fixVersionIds: ['2']),
    ];
    final w = watcher(repo());

    await w.poll();
    expect(jira.searched.single, rejected.jql('AU2'));
    final request = starter.requests.single;
    expect(request.repoName, 'demo');
    expect(request.issueKey, 'AU2-7');
    expect(request.prompt, 'Fix');
    expect(request.title, 'Fix login');
    expect((request.model, request.effort), ('opus', 'high'));
    expect(request.existingWorktree, isNull);
    expect(request.newWorktree!.baseBranch, 'releases/2.41');
    expect(request.newWorktree!.worktreeName, 'fix-login-au2-7');
    expect(request.newWorktree!.newBranch, 'feature/fix-login-au2-7');
    expect(
      notices.single,
      'Jira trigger: started Fix for AU2-7 in fix-login-au2-7 '
      '(new, from releases/2.41)',
    );
    expect(w.lastCheck!.started, 1);
    expect(
      AppLog.current.entries.map((e) => (e.source, e.message)),
      containsAll([
        (
          'jira-triggers',
          'demo: "Fix" when an issue in version 2 moves to QA Rejected: '
              '1 matching, 1 new',
        ),
        (
          'jira-triggers',
          'started Fix for AU2-7 in fix-login-au2-7 (new, from releases/2.41)',
        ),
        ('jira-triggers', 'Checked 1 trigger: 1 started'),
      ]),
    );

    // Still matching: not again.
    await w.poll();
    expect(starter.requests, hasLength(1));

    // Gone and back (rejected again): again.
    jira.issues = [];
    await w.poll();
    jira.issues = [const JiraIssue(key: 'AU2-7', summary: 'Fix login')];
    await w.poll();
    expect(starter.requests, hasLength(2));
  });

  test('runs in the issue\'s own worktree when it is on disk', () async {
    final dir = await Directory.systemTemp.createTemp('trigger_wt');
    addTearDown(() => dir.delete(recursive: true));
    worktrees = [
      WorktreeMetadata(
        path: '/gone',
        repoPath: '/repos/demo',
        jiraIssue: 'AU2-7',
      ),
      WorktreeMetadata(
        path: dir.path,
        repoPath: '/repos/demo',
        jiraIssue: 'AU2-7',
      ),
    ];
    jira.issues = [const JiraIssue(key: 'AU2-7', summary: 'Fix login')];

    await watcher(repo()).poll();
    expect(starter.requests.single.existingWorktree, dir.path);
    expect(starter.requests.single.newWorktree, isNull);
  });

  test('runs in the rule\'s worktree when it names one', () async {
    jira.issues = [const JiraIssue(key: 'AU2-8', summary: 'New thing')];
    final created = JiraTrigger(
      id: 'new',
      fixVersionId: '2',
      since: DateTime(2026, 10, 21),
      event: JiraTriggerEvent.created,
      promptName: 'Refine',
      worktreePath: '/repos/shared',
    );

    await watcher(repo(triggers: [created])).poll();
    expect(starter.requests.single.existingWorktree, '/repos/shared');
    expect(starter.requests.single.prompt, 'Refine');
  });

  test('says why when it can\'t start, without trying again', () async {
    jira.issues = [const JiraIssue(key: 'AU2-9', summary: 'x')];
    final unmapped = repo().copyWith(jiraVersionBranches: const {});
    final w = watcher(unmapped);

    await w.poll();
    await w.poll();
    expect(starter.requests, isEmpty);
    expect(notices, [
      "Jira trigger: couldn't start Fix for AU2-9, its fixVersion has no "
          'default branch',
    ]);
    expect(AppLog.current.entries.last.level, LogLevel.info);
    expect(
      AppLog.current.entries
          .where((e) => e.message.contains("couldn't start Fix for AU2-9"))
          .single
          .level,
      LogLevel.warning,
    );
  });

  test('reports a failed start', () async {
    jira.issues = [const JiraIssue(key: 'AU2-9', summary: 'x')];
    starter.failWith = const ClaudePromptException('unknown prompt "Fix"');

    await watcher(repo()).poll();
    expect(notices.single, startsWith("Jira trigger: couldn't start Fix"));
  });

  test('leaves an issue an agent is already on alone', () async {
    jira.issues = [const JiraIssue(key: 'AU2-7', summary: 'x')];
    running = {'AU2-7'};

    await watcher(repo()).poll();
    expect(starter.requests, isEmpty);
    expect(notices.single, contains('an agent is already on it'));
  });

  test('skips disabled and unfinished rules', () async {
    jira.issues = [const JiraIssue(key: 'AU2-7', summary: 'x')];
    await watcher(
      repo(
        triggers: [
          rejected.copyWith(enabled: false),
          JiraTrigger(id: 'draft', fixVersionId: '2', since: DateTime(2026)),
        ],
      ),
    ).poll();
    expect(jira.searched, isEmpty);
  });

  test('starts at most three sessions a poll', () async {
    jira.issues = [
      for (var i = 1; i <= 5; i++) JiraIssue(key: 'AU2-$i', summary: 'x'),
    ];
    final w = watcher(repo());

    await w.poll();
    expect(starter.requests.map((r) => r.issueKey), [
      'AU2-1',
      'AU2-2',
      'AU2-3',
    ]);
    await w.poll();
    expect(starter.requests.map((r) => r.issueKey).skip(3), ['AU2-4', 'AU2-5']);
  });

  group('the schedule', () {
    void schedule(JiraTriggerSchedule schedule) => settings.settings = settings
        .settings
        .copyWith(jiraTriggerSchedule: schedule);

    test('checks at start within the hours', () async {
      schedule(const JiraTriggerSchedule(from: 7 * 60, until: 17 * 60));
      final w = watcher(repo());
      addTearDown(w.dispose);

      w.start();
      await pumpEventQueue();
      expect(jira.searched, hasLength(1));
    });

    test('doesn\'t check outside the hours', () async {
      schedule(const JiraTriggerSchedule(from: 7 * 60, until: 17 * 60));
      now = DateTime(2026, 10, 21, 18);
      final w = watcher(repo());
      addTearDown(w.dispose);

      w.start();
      await pumpEventQueue();
      expect(jira.searched, isEmpty);
    });

    test('checks by hand outside the hours', () async {
      schedule(const JiraTriggerSchedule(from: 7 * 60, until: 17 * 60));
      now = DateTime(2026, 10, 21, 18);
      final w = watcher(repo());
      addTearDown(w.dispose);
      w.start();

      await w.checkNow();
      expect(jira.searched, hasLength(1));
      expect(w.lastCheck!.at, now);
    });

    test('checks at once when turned back on', () async {
      schedule(const JiraTriggerSchedule(enabled: false));
      final w = watcher(repo());
      addTearDown(w.dispose);

      w.start();
      await pumpEventQueue();
      expect(jira.searched, isEmpty);

      schedule(const JiraTriggerSchedule());
      w.settingsChanged();
      await pumpEventQueue();
      expect(jira.searched, hasLength(1));
    });
  });
}
