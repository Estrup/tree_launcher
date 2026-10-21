import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show SnackBarAction;

import 'package:tree_launcher/core/design_system/app_snackbar.dart';
import 'package:tree_launcher/core/errors/user_message.dart';
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

/// Polls Jira for the repos' [JiraTrigger]s, on the settings'
/// [JiraTriggerSchedule], and starts a Claude session for each issue that
/// newly matches one. There are no webhooks, so a change shows up at the
/// next poll; an issue a rule has fired for is remembered in
/// the [JiraTriggerStore] until it stops matching.
class JiraTriggerWatcher {
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

  /// The schedule the timer runs on; null until [start].
  JiraTriggerSchedule? _schedule;

  /// Starts checking on the settings' [JiraTriggerSchedule]: now, when its
  /// hours allow, and then every interval.
  void start() {
    if (_schedule != null) return;
    _schedule = _settings.settings.jiraTriggerSchedule;
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
    _arm();
    if (!before.enabled && schedule.enabled) unawaited(_tick());
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  void _arm() {
    _timer?.cancel();
    final schedule = _schedule!;
    _timer = schedule.enabled
        ? Timer.periodic(schedule.interval, (_) => _tick())
        : null;
  }

  /// Polls when the schedule allows it now.
  Future<void> _tick() async {
    if (_schedule?.isActiveAt(_now()) ?? false) await poll();
  }

  /// Checks every enabled rule once. A poll still running is joined, not
  /// repeated.
  Future<void> poll() =>
      _polling ??= _poll().whenComplete(() => _polling = null);

  Future<void> _poll() async {
    try {
      final repos = await _repos.loadedRepos();
      await _store.keepTriggers({
        for (final repo in repos)
          for (final trigger in repo.jiraTriggers) trigger.id,
      });
      var starts = 0;
      for (final repo in repos) {
        final projectKey = repo.jiraProjectKey;
        if (projectKey == null) continue;
        for (final trigger in repo.jiraTriggers) {
          if (!trigger.enabled || !trigger.isComplete) continue;
          final List<JiraIssue> issues;
          try {
            issues = await _jira.searchIssues(trigger.jql(projectKey));
          } catch (e) {
            debugPrint('Polling Jira trigger ${trigger.id} failed: $e');
            continue;
          }
          await _store.keepOnly(trigger.id, {for (final i in issues) i.key});
          final fired = await _store.firedFor(trigger.id);
          for (final issue in issues) {
            if (fired.contains(issue.key)) continue;
            if (starts == maxStartsPerPoll) return;
            // Claimed first, so a start that fails isn't retried each poll,
            // and only one instance sharing the database starts it.
            if (!await _store.claim(trigger.id, issue.key)) continue;
            starts++;
            await _fire(repo, trigger, issue);
          }
        }
      }
    } catch (e) {
      debugPrint('Polling the Jira triggers failed: $e');
    }
  }

  Future<void> _fire(
    RepoConfig repo,
    JiraTrigger trigger,
    JiraIssue issue,
  ) async {
    final what = '${trigger.promptName} for ${issue.key}';
    if (_isRunning(repo.name, issue.key)) {
      _notify('Jira trigger: not starting $what, an agent is already on it');
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
        _notify(
          "Jira trigger: couldn't start $what, its fixVersion has no "
          'default branch',
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
      await _starter.start(
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
      _notify('Jira trigger started $what');
    } catch (e) {
      _notify("Jira trigger: couldn't start $what: ${userMessage(e)}");
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
