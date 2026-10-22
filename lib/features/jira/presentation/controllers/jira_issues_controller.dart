import 'package:flutter/foundation.dart';

import 'package:tree_launcher/core/presentation/issue_list_controller.dart';
import 'package:tree_launcher/features/jira/data/jira_api_service.dart';
import 'package:tree_launcher/features/jira/domain/jira_issue.dart';
import 'package:tree_launcher/features/jira/domain/jira_search.dart';
import 'package:tree_launcher/features/jira/domain/jira_transition.dart';
import 'package:tree_launcher/features/jira/domain/jira_user.dart';
import 'package:tree_launcher/features/jira/domain/jira_version.dart';
import 'package:tree_launcher/features/workspace/domain/repo_config.dart';
import 'package:tree_launcher/core/errors/user_message.dart';
import 'package:tree_launcher/core/logging/app_log.dart';

/// One status in the Jira tab's filter, with how many loaded issues have it.
class JiraStatusCount {
  final String name;
  final String? category;
  final int count;

  const JiraStatusCount({
    required this.name,
    required this.category,
    required this.count,
  });
}

/// Backs the Jira tab: the selected repo's project versions, the issues in the
/// selected fixVersion or found by a search, the status filter, the selected
/// issues, and changing issues' status or assignee.
class JiraIssuesController extends IssueListController<JiraIssue, String> {
  JiraIssuesController({JiraApiService? service})
    : _service = service ?? JiraApiService();

  /// Most issues a search shows.
  static const searchLimit = 50;

  final JiraApiService _service;

  String? _repoPath;
  String? _projectKey;

  /// The fixVersion id saved in the repo config, used when (re)loading.
  String? _rememberedVersionId;

  List<JiraVersion> _versions = const [];
  JiraVersion? _selectedVersion;
  List<JiraIssue> _issues = const [];
  final Set<String> _statusFilter = {};

  /// The token's user, once looked up; null until then or when that failed.
  JiraUser? _me;

  /// Persists an explicit fixVersion pick for the repo at [repoPath]. Wired at
  /// the app level so the choice is remembered across restarts.
  void Function(String repoPath, JiraVersion version)? onVersionSelected;

  String? get projectKey => _projectKey;

  /// Versions for the picker: unreleased first, then released newest-first.
  List<JiraVersion> get versions => _versions;
  JiraVersion? get selectedVersion => _selectedVersion;

  @override
  String keyOf(JiraIssue issue) => issue.key;

  /// The fixVersion's issues.
  @override
  List<JiraIssue> get listedIssues => _issues;

  /// Whether [issues] are search results rather than the fixVersion's issues.
  @override
  bool get isSearching => _searchJql != null;

  /// Whether the search may have found more issues than [searchLimit].
  bool get searchTruncated =>
      isSearching && searchResults.length >= searchLimit;

  /// Statuses currently filtered on. Empty means every status is shown.
  Set<String> get statusFilter => Set.unmodifiable(_statusFilter);

  /// Display name of the token's user, once known.
  String? get myDisplayName => _me?.displayName;

  /// Issues that pass the status filter.
  @override
  List<JiraIssue> get visibleIssues => _statusFilter.isEmpty
      ? issues
      : issues.where((i) => _statusFilter.contains(i.status)).toList();

  /// Statuses of the loaded issues with counts, ordered to do → in progress →
  /// done (then by first appearance). Filtered statuses with no issues in this
  /// version are kept at the end so they can still be switched off.
  List<JiraStatusCount> get statusCounts {
    final counts = <String, int>{};
    final categories = <String, String?>{};
    for (final issue in issues) {
      final status = issue.status;
      if (status == null) continue;
      counts[status] = (counts[status] ?? 0) + 1;
      categories[status] ??= issue.statusCategory;
    }
    const order = {'new': 0, 'indeterminate': 1, 'done': 2};
    final names = counts.keys.toList();
    final firstSeen = {for (var i = 0; i < names.length; i++) names[i]: i};
    names.sort((a, b) {
      final byCategory = (order[categories[a]] ?? 1).compareTo(
        order[categories[b]] ?? 1,
      );
      return byCategory != 0
          ? byCategory
          : firstSeen[a]!.compareTo(firstSeen[b]!);
    });
    return [
      for (final name in names)
        JiraStatusCount(
          name: name,
          category: categories[name],
          count: counts[name]!,
        ),
      for (final name in _statusFilter.where((s) => !counts.containsKey(s)))
        JiraStatusCount(name: name, category: null, count: 0),
    ];
  }

  /// Follows the app-level selected repo. Reloads when the repo or its project
  /// key changes; otherwise only tracks the remembered fixVersion.
  void syncToRepo(RepoConfig? repo) {
    final key = repo?.jiraProjectKey;
    _rememberedVersionId = repo?.jiraFixVersionId;
    if (repo?.path == _repoPath && key == _projectKey) return;

    _repoPath = repo?.path;
    _projectKey = key;
    // Deferred so we never notifyListeners() synchronously during the
    // provider's build (syncToRepo is called from ProxyProvider.update).
    Future.microtask(() {
      _reset();
      if (key != null) refresh();
    });
  }

  /// Reloads the project's versions and the selected version's issues, or
  /// the search's results while searching (an issue key or words, see
  /// [jiraSearchJql]).
  @override
  Future<void> refresh() async {
    final key = _projectKey;
    if (key == null) return;
    await load((generation) async {
      final jql = _searchJql;
      if (jql != null) {
        await _fetchSearchResults(jql, generation);
        return;
      }
      final versions = orderVersionsForPicker(
        await _service.fetchVersions(key),
      );
      if (!isCurrent(generation)) return;
      _versions = versions;
      _selectedVersion = pickVersion(
        versions,
        _selectedVersion?.id ?? _rememberedVersionId,
      );
      await _fetchIssues(generation);
    });
  }

  /// Switches to [version], remembers it for the repo, and loads its issues.
  /// Ends a search. The status filter is kept, since statuses are shared
  /// across versions.
  Future<void> selectVersion(JiraVersion version) async {
    if (isSearching) {
      endSearch();
    } else if (version.id == _selectedVersion?.id) {
      return;
    }
    _selectedVersion = version;
    _issues = const [];
    dropSelection();
    final repoPath = _repoPath;
    if (repoPath != null) onVersionSelected?.call(repoPath, version);

    await load(_fetchIssues);
  }

  void toggleStatus(String status) {
    if (!_statusFilter.remove(status)) _statusFilter.add(status);
    pruneSelection();
    notify();
  }

  void clearStatusFilter() {
    if (_statusFilter.isEmpty) return;
    _statusFilter.clear();
    notify();
  }

  /// The statuses the issues [keys] can move to, each with the transition
  /// every issue takes there.
  Future<List<JiraStatusMove>> statusMovesFor(List<String> keys) async {
    final transitions = await Future.wait(keys.map(_service.fetchTransitions));
    return jiraStatusMoves({
      for (var i = 0; i < keys.length; i++) keys[i]: transitions[i],
    });
  }

  /// Moves the issues in [move] to its status, then reloads the list.
  /// Returns the issues Jira refused to move, with its reason.
  Future<Map<String, String>> applyStatusMove(JiraStatusMove move) async {
    final failures = <String, String>{};
    await Future.wait(
      move.transitions.entries.map((entry) async {
        try {
          await _service.transitionIssue(entry.key, entry.value.id);
        } catch (e) {
          failures[entry.key] = userMessage(e);
        }
      }),
    );
    await refresh();
    return failures;
  }

  /// Assigns [key] to the token's user, then reloads the list. Throws when
  /// Jira refuses.
  Future<void> assignToMe(String key) async {
    final me = _me ?? await _service.fetchMyself();
    _me = me;
    await _service.assignIssue(key, me.name);
    await refresh();
  }

  Future<void> _loadMe() async {
    try {
      _me = await _service.fetchMyself();
      notify();
    } catch (e) {
      // "Assign to me" stays offered everywhere and reports the problem.
      debugPrint('Jira user lookup failed: $e');
    }
  }

  Future<void> _fetchIssues(int generation) async {
    final key = _projectKey;
    final version = _selectedVersion;
    if (key == null || version == null) {
      _issues = const [];
      return;
    }
    final issues = await _service.searchIssues(
      fixVersionIssuesJql(key, version.id),
    );
    if (!isCurrent(generation)) return;
    appLog(
      'jira',
      'Loaded ${issues.length} issues of $key ${version.name}',
      level: LogLevel.debug,
    );
    _issues = issues;
    loaded();
    if (_me == null) _loadMe();
  }

  Future<void> _fetchSearchResults(String jql, int generation) async {
    final results = await _service.findIssues(jql, limit: searchLimit);
    if (!isCurrent(generation)) return;
    // The issue the query names comes first.
    final key = jiraKeyInQuery(_projectKey!, searchQuery);
    showSearchResults([
      ...results.where((i) => i.key == key),
      ...results.where((i) => i.key != key),
    ]);
    if (_me == null) _loadMe();
  }

  String? get _searchJql {
    final key = _projectKey;
    return key == null ? null : jiraSearchJql(key, searchQuery);
  }

  void _reset() {
    resetList();
    _versions = const [];
    _selectedVersion = null;
    _issues = const [];
    _statusFilter.clear();
    notify();
  }
}
