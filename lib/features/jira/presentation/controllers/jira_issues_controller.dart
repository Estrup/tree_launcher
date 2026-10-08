import 'package:flutter/foundation.dart';

import 'package:tree_launcher/features/jira/data/jira_api_service.dart';
import 'package:tree_launcher/features/jira/domain/jira_issue.dart';
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
/// selected fixVersion, and the status filter.
class JiraIssuesController extends ChangeNotifier {
  JiraIssuesController({JiraApiService? service})
    : _service = service ?? JiraApiService();

  final JiraApiService _service;

  String? _repoPath;
  String? _projectKey;

  /// The fixVersion id saved in the repo config, used when (re)loading.
  String? _rememberedVersionId;

  List<JiraVersion> _versions = const [];
  JiraVersion? _selectedVersion;
  List<JiraIssue> _issues = const [];
  bool _isLoading = false;
  String? _error;
  DateTime? _lastRefreshed;
  final Set<String> _statusFilter = {};
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
  List<JiraIssue> get issues => _issues;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get lastRefreshed => _lastRefreshed;

  /// Statuses currently filtered on. Empty means every status is shown.
  Set<String> get statusFilter => Set.unmodifiable(_statusFilter);

  /// Issues that pass the status filter.
  List<JiraIssue> get visibleIssues => _statusFilter.isEmpty
      ? _issues
      : _issues.where((i) => _statusFilter.contains(i.status)).toList();

  /// Statuses of the loaded issues with counts, ordered to do → in progress →
  /// done (then by first appearance). Filtered statuses with no issues in this
  /// version are kept at the end so they can still be switched off.
  List<JiraStatusCount> get statusCounts {
    final counts = <String, int>{};
    final categories = <String, String?>{};
    for (final issue in _issues) {
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

  /// Reloads the project's versions and the selected version's issues.
  Future<void> refresh() async {
    final key = _projectKey;
    if (key == null) return;
    final generation = _startLoad();
    try {
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

  /// Switches to [version], remembers it for the repo, and loads its issues.
  /// The status filter is kept, since statuses are shared across versions.
  Future<void> selectVersion(JiraVersion version) async {
    if (version.id == _selectedVersion?.id) return;
    _selectedVersion = version;
    _issues = const [];
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
    _notify();
  }

  void clearStatusFilter() {
    if (_statusFilter.isEmpty) return;
    _statusFilter.clear();
    _notify();
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
  }

  int _startLoad() {
    _isLoading = true;
    _error = null;
    _notify();
    return ++_generation;
  }

  void _fail(int generation, Object e) {
    if (generation != _generation) return;
    _error = e.toString().replaceFirst('Exception: ', '');
  }

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
    _isLoading = false;
    _error = null;
    _lastRefreshed = null;
    _statusFilter.clear();
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
