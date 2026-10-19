import 'package:flutter/foundation.dart';

import 'package:tree_launcher/features/jira/data/jira_api_service.dart';
import 'package:tree_launcher/features/jira/domain/jira_issue.dart';
import 'package:tree_launcher/features/jira/domain/jira_search.dart';
import 'package:tree_launcher/features/jira/domain/jira_transition.dart';
import 'package:tree_launcher/features/jira/domain/jira_user.dart';
import 'package:tree_launcher/features/jira/domain/jira_version.dart';
import 'package:tree_launcher/features/workspace/domain/repo_config.dart';

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
class JiraIssuesController extends ChangeNotifier {
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
  String _searchQuery = '';
  List<JiraIssue> _searchResults = const [];
  bool _isLoading = false;
  String? _error;
  DateTime? _lastRefreshed;
  final Set<String> _statusFilter = {};

  /// Keys of the selected issues; always a subset of [visibleIssues].
  final Set<String> _selected = {};

  /// The token's user, once looked up; null until then or when that failed.
  JiraUser? _me;
  bool _disposed = false;

  /// Bumped on every load, so a slow response for an earlier repo or version
  /// is dropped instead of overwriting newer results.
  int _generation = 0;

  /// Persists an explicit fixVersion pick for the repo at [repoPath]. Wired at
  /// the app level so the choice is remembered across restarts.
  void Function(String repoPath, JiraVersion version)? onVersionSelected;

  String? get projectKey => _projectKey;

  /// Versions for the picker: unreleased first, then released newest-first.
  List<JiraVersion> get versions => _versions;
  JiraVersion? get selectedVersion => _selectedVersion;

  /// The search's results while searching, otherwise the fixVersion's issues.
  List<JiraIssue> get issues => isSearching ? _searchResults : _issues;

  /// What was searched for; empty when not searching.
  String get searchQuery => _searchQuery;

  /// Whether [issues] are search results rather than the fixVersion's issues.
  bool get isSearching => _searchJql != null;

  /// Whether the search may have found more issues than [searchLimit].
  bool get searchTruncated =>
      isSearching && _searchResults.length >= searchLimit;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get lastRefreshed => _lastRefreshed;

  /// Statuses currently filtered on. Empty means every status is shown.
  Set<String> get statusFilter => Set.unmodifiable(_statusFilter);

  /// Keys of the selected issues.
  Set<String> get selectedKeys => Set.unmodifiable(_selected);

  /// The selected issues, in list order.
  List<JiraIssue> get selectedIssues =>
      visibleIssues.where((i) => _selected.contains(i.key)).toList();

  /// Display name of the token's user, once known.
  String? get myDisplayName => _me?.displayName;

  /// Issues that pass the status filter.
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
  /// the search's results while searching.
  Future<void> refresh() async {
    final key = _projectKey;
    if (key == null) return;
    final generation = _startLoad();
    try {
      final jql = _searchJql;
      if (jql != null) {
        await _fetchSearchResults(jql, generation);
        return;
      }
      final versions = orderVersionsForPicker(
        await _service.fetchVersions(key),
      );
      if (generation != _generation) return;
      _versions = versions;
      _selectedVersion = pickVersion(
        versions,
        _selectedVersion?.id ?? _rememberedVersionId,
      );
      await _fetchIssues(generation);
    } catch (e) {
      _fail(generation, e);
    } finally {
      _finishLoad(generation);
    }
  }

  /// Shows the issues matching [query] (an issue key or words, see
  /// [jiraSearchJql]) instead of the fixVersion's. A query with nothing to
  /// search for goes back to the fixVersion, reloading its issues.
  Future<void> search(String query) async {
    final trimmed = query.trim();
    if (trimmed == _searchQuery) return;
    final wasSearching = isSearching;
    _searchQuery = trimmed;
    // The previous results stay up while a changed search loads.
    if (!isSearching) _searchResults = const [];
    if (isSearching || wasSearching) {
      await refresh();
    } else {
      _notify();
    }
  }

  /// Switches to [version], remembers it for the repo, and loads its issues.
  /// Ends a search. The status filter is kept, since statuses are shared
  /// across versions.
  Future<void> selectVersion(JiraVersion version) async {
    if (isSearching) {
      _searchQuery = '';
      _searchResults = const [];
    } else if (version.id == _selectedVersion?.id) {
      return;
    }
    _selectedVersion = version;
    _issues = const [];
    _selected.clear();
    final repoPath = _repoPath;
    if (repoPath != null) onVersionSelected?.call(repoPath, version);

    final generation = _startLoad();
    try {
      await _fetchIssues(generation);
    } catch (e) {
      _fail(generation, e);
    } finally {
      _finishLoad(generation);
    }
  }

  void toggleStatus(String status) {
    if (!_statusFilter.remove(status)) _statusFilter.add(status);
    _pruneSelection();
    _notify();
  }

  void clearStatusFilter() {
    if (_statusFilter.isEmpty) return;
    _statusFilter.clear();
    _notify();
  }

  void setSelected(String key, bool selected) {
    selected ? _selected.add(key) : _selected.remove(key);
    _notify();
  }

  /// Selects every visible issue, or clears the selection when all already
  /// are.
  void toggleSelectAll() {
    final keys = visibleIssues.map((i) => i.key);
    if (keys.every(_selected.contains)) {
      _selected.clear();
    } else {
      _selected.addAll(keys);
    }
    _notify();
  }

  void clearSelection() {
    if (_selected.isEmpty) return;
    _selected.clear();
    _notify();
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
          failures[entry.key] = _message(e);
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
      _notify();
    } catch (e) {
      // "Assign to me" stays offered everywhere and reports the problem.
      debugPrint('Jira user lookup failed: $e');
    }
  }

  void _pruneSelection() {
    _selected.retainAll(visibleIssues.map((i) => i.key));
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
    if (generation != _generation) return;
    _issues = issues;
    _lastRefreshed = DateTime.now();
    _pruneSelection();
    if (_me == null) _loadMe();
  }

  Future<void> _fetchSearchResults(String jql, int generation) async {
    final results = await _service.findIssues(jql, limit: searchLimit);
    if (generation != _generation) return;
    // The issue the query names comes first.
    final key = jiraKeyInQuery(_projectKey!, _searchQuery);
    _searchResults = [
      ...results.where((i) => i.key == key),
      ...results.where((i) => i.key != key),
    ];
    _lastRefreshed = DateTime.now();
    _pruneSelection();
    if (_me == null) _loadMe();
  }

  String? get _searchJql {
    final key = _projectKey;
    return key == null ? null : jiraSearchJql(key, _searchQuery);
  }

  int _startLoad() {
    _isLoading = true;
    _error = null;
    _notify();
    return ++_generation;
  }

  void _fail(int generation, Object e) {
    if (generation != _generation) return;
    _error = _message(e);
  }

  static String _message(Object e) =>
      e.toString().replaceFirst('Exception: ', '');

  void _finishLoad(int generation) {
    if (generation != _generation) return;
    _isLoading = false;
    _notify();
  }

  void _reset() {
    _generation++;
    _versions = const [];
    _selectedVersion = null;
    _issues = const [];
    _searchQuery = '';
    _searchResults = const [];
    _isLoading = false;
    _error = null;
    _lastRefreshed = null;
    _statusFilter.clear();
    _selected.clear();
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
