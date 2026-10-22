import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show SnackBarAction;

import 'package:tree_launcher/core/design_system/app_snackbar.dart';
import 'package:tree_launcher/core/errors/user_message.dart';
import 'package:tree_launcher/core/logging/app_log.dart';
import 'package:tree_launcher/features/agents/domain/claude_session_starter.dart';
import 'package:tree_launcher/features/jira/data/jira_api_service.dart';
import 'package:tree_launcher/features/jira/data/jira_trigger_store.dart';
import 'package:tree_launcher/features/jira/domain/jira_issue.dart';
import 'package:tree_launcher/features/jira/domain/jira_trigger.dart';
import 'package:tree_launcher/features/jira/domain/jira_trigger_schedule.dart';
import 'package:tree_launcher/features/settings/domain/app_settings_source.dart';
import 'package:tree_launcher/features/workspace/domain/repo_catalog.dart';
import 'package:tree_launcher/features/workspace/domain/repo_config.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_metadata.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_naming.dart';

/// What one check of the triggers found.
class JiraTriggerCheck {
  const JiraTriggerCheck({
    required this.at,
    required this.triggers,
    required this.started,
    required this.failed,
  });

  final DateTime at;

  /// How many triggers were checked.
  final int triggers;

  /// How many sessions it started.
  final int started;

  /// How many triggers' Jira searches failed.
  final int failed;
}

/// Polls Jira for the repos' [JiraTrigger]s, on the settings'
/// [JiraTriggerSchedule], and starts a Claude session for each issue that
/// newly matches one. There are no webhooks, so a change shows up at the
/// next poll; an issue a rule has fired for is remembered in
/// the [JiraTriggerStore] until it stops matching. What it does is logged
/// under `jira-triggers`.
class JiraTriggerWatcher extends ChangeNotifier {
  JiraTriggerWatcher({
    required RepoCatalog repos,
    required AppSettingsSource settings,
    required JiraApiService jira,
    required JiraTriggerStore store,
    required ClaudeSessionStarter starter,
    required Iterable<WorktreeMetadata> Function(String repoPath) worktreesOf,
    required bool Function(String repoName, String issueKey) isRunning,
    void Function(String message, {SnackBarAction? action})? notify,
    DateTime Function()? now,
  }) : _repos = repos,
       _settings = settings,
       _jira = jira,
       _store = store,
       _starter = starter,
       _worktreesOf = worktreesOf,
       _isRunning = isRunning,
       _notify = notify ?? showAppSnackBar,
       _now = now ?? DateTime.now;

  static const _source = 'jira-triggers';

  final RepoCatalog _repos;
  final AppSettingsSource _settings;
  final JiraApiService _jira;
  final JiraTriggerStore _store;
  final ClaudeSessionStarter _starter;

  /// A repo's worktrees with their recorded issues.
  final Iterable<WorktreeMetadata> Function(String repoPath) _worktreesOf;

  /// Whether an agent is already working on the issue in the repo.
  final bool Function(String repoName, String issueKey) _isRunning;

  final void Function(String message, {SnackBarAction? action}) _notify;
  final DateTime Function() _now;

  /// The most sessions one poll starts; the rest start at the next poll.
  static const maxStartsPerPoll = 3;

  Timer? _timer;
  Future<void>? _polling;
  JiraTriggerCheck? _lastCheck;
  DateTime? _nextTick;

  /// The schedule the timer runs on; null until [start].
  JiraTriggerSchedule? _schedule;

  /// The last check that ran.
  JiraTriggerCheck? get lastCheck => _lastCheck;

  /// When the timer next fires (the check is skipped outside the hours);
  /// null while checks are off.
  DateTime? get nextTick => _nextTick;

  bool get isChecking => _polling != null;

  /// The schedule the checks run on; null until [start].
  JiraTriggerSchedule? get schedule => _schedule;

  /// Starts checking on the settings' [JiraTriggerSchedule]: now, when its
  /// hours allow, and then every interval.
  void start() {
    if (_schedule != null) return;
    _schedule = _settings.settings.jiraTriggerSchedule;
    appLog(_source, _describe(_schedule!));
    _arm();
    unawaited(_tick());
  }

  /// Applies a changed schedule at once: the wait restarts on the new
  /// interval, and turning checks on checks now. Call when the settings
  /// change.
  void settingsChanged() {
    final before = _schedule;
    final schedule = _settings.settings.jiraTriggerSchedule;
    if (before == null || schedule == before) return;
    _schedule = schedule;
    appLog(_source, _describe(schedule));
    _arm();
    if (!before.enabled && schedule.enabled) unawaited(_tick());
  }

  /// Checks the triggers now, whatever the schedule says.
  Future<void> checkNow() {
    appLog(_source, 'Checking now, asked for by hand');
    return poll();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  static String _describe(JiraTriggerSchedule schedule) {
    if (!schedule.enabled) return 'Checks are off';
    final hours = schedule.hasHours
        ? ' between ${formatTimeOfDay(schedule.from!)} and '
              '${formatTimeOfDay(schedule.until!)}'
        : '';
    return 'Checking every ${schedule.intervalMinutes} min$hours';
  }

  void _arm() {
    _timer?.cancel();
    final schedule = _schedule!;
    _timer = schedule.enabled
        ? Timer.periodic(schedule.interval, (_) {
            _nextTick = _now().add(schedule.interval);
            notifyListeners();
            unawaited(_tick());
          })
        : null;
    _nextTick = schedule.enabled ? _now().add(schedule.interval) : null;
    notifyListeners();
  }

  /// Polls when the schedule allows it now.
  Future<void> _tick() async {
    final schedule = _schedule;
    if (schedule == null) return;
    if (schedule.isActiveAt(_now())) {
      await poll();
    } else if (schedule.enabled) {
      appLog(
        _source,
        'Skipped the check, outside the hours',
        level: LogLevel.debug,
      );
    }
  }

  /// Checks every enabled rule once. A poll still running is joined, not
  /// repeated.
  Future<void> poll() {
    final running = _polling;
    if (running != null) return running;
    final poll = _polling = _poll().whenComplete(() {
      _polling = null;
      notifyListeners();
    });
    notifyListeners();
    return poll;
  }

  Future<void> _poll() async {
    var checked = 0;
    var starts = 0;
    var failed = 0;
    try {
      final repos = await _repos.loadedRepos();
      await _store.keepTriggers({
        for (final repo in repos)
          for (final trigger in repo.jiraTriggers) trigger.id,
      });
      for (final repo in repos) {
        final projectKey = repo.jiraProjectKey;
        if (projectKey == null) continue;
        for (final trigger in repo.jiraTriggers) {
          if (!trigger.enabled || !trigger.isComplete) continue;
          checked++;
          final label = '${repo.name}: ${_label(trigger)}';
          final List<JiraIssue> issues;
          try {
            issues = await _jira.searchIssues(trigger.jql(projectKey));
          } catch (e) {
            failed++;
            appLog(
              _source,
              '$label: the Jira search failed: ${userMessage(e)}',
              level: LogLevel.warning,
            );
            continue;
          }
          await _store.keepOnly(trigger.id, {for (final i in issues) i.key});
          final fired = await _store.firedFor(trigger.id);
          final fresh = [
            for (final issue in issues)
              if (!fired.contains(issue.key)) issue,
          ];
          appLog(
            _source,
            '$label: ${issues.length} matching, ${fresh.length} new',
            level: fresh.isEmpty ? LogLevel.debug : LogLevel.info,
          );
          for (final issue in fresh) {
            if (starts == maxStartsPerPoll) {
              appLog(
                _source,
                'Started $maxStartsPerPoll sessions, the rest wait for the '
                'next check',
              );
              return;
            }
            // Claimed first, so a start that fails isn't retried each poll,
            // and only one instance sharing the database starts it.
            if (!await _store.claim(trigger.id, issue.key)) continue;
            starts++;
            await _fire(repo, trigger, issue);
          }
        }
      }
    } catch (e) {
      appLog(
        _source,
        'Checking the triggers failed: ${userMessage(e)}',
        level: LogLevel.error,
      );
    } finally {
      _lastCheck = JiraTriggerCheck(
        at: _now(),
        triggers: checked,
        started: starts,
        failed: failed,
      );
      appLog(
        _source,
        'Checked $checked trigger${checked == 1 ? '' : 's'}: '
        '$starts started${failed > 0 ? ', $failed failed' : ''}',
      );
    }
  }

  /// How the log names [trigger].
  static String _label(JiraTrigger trigger) {
    final when = trigger.event == JiraTriggerEvent.status
        ? 'moves to ${trigger.status}'
        : 'is created';
    return '"${trigger.promptName}" when an issue in version '
        '${trigger.fixVersionId} $when';
  }

  /// Shows [message] and logs it.
  void _report(String message, {LogLevel level = LogLevel.info}) {
    appLog(_source, message, level: level);
    _notify('Jira trigger: $message');
  }

  Future<void> _fire(
    RepoConfig repo,
    JiraTrigger trigger,
    JiraIssue issue,
  ) async {
    final what = '${trigger.promptName} for ${issue.key}';
    if (_isRunning(repo.name, issue.key)) {
      _report(
        'not starting $what, an agent is already on it',
        level: LogLevel.warning,
      );
      return;
    }
    final existing = trigger.worktreePath ?? _worktreeOf(repo, issue.key);
    NewWorktreeRequest? newWorktree;
    if (existing == null) {
      final base = repo.baseBranchForFixVersions([
        trigger.fixVersionId,
        ...issue.fixVersionIds,
      ]);
      if (base == null) {
        _report(
          "couldn't start $what, its fixVersion has no default branch",
          level: LogLevel.warning,
        );
        return;
      }
      final name = worktreeNameForJiraIssue(issue.key, issue.summary);
      newWorktree = NewWorktreeRequest(
        worktreeName: name,
        baseBranch: base,
        newBranch: buildBranchName(
          name,
          _settings.settings.defaultBranchPrefix,
        ),
      );
    }
    try {
      final started = await _starter.start(
        ClaudeSessionRequest(
          repoName: repo.name,
          existingWorktree: existing,
          newWorktree: newWorktree,
          issueKey: issue.key,
          prompt: trigger.promptName,
          title: issue.summary,
          model: trigger.model,
          effort: trigger.effort,
        ),
      );
      final worktree = started.worktree;
      _report(
        'started $what in ${worktree.name}'
        '${worktree.created ? ' (new, from ${worktree.baseBranch})' : ''}',
      );
    } catch (e) {
      _report("couldn't start $what: ${userMessage(e)}", level: LogLevel.error);
    }
  }

  /// The path of [repo]'s worktree for [issueKey], if it is still on disk.
  String? _worktreeOf(RepoConfig repo, String issueKey) {
    for (final worktree in _worktreesOf(repo.path)) {
      if (worktree.jiraIssue == issueKey &&
          Directory(worktree.path).existsSync()) {
        return worktree.path;
      }
    }
    return null;
  }
}
