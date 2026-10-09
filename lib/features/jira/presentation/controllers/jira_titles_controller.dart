import 'package:flutter/foundation.dart';

import 'package:tree_launcher/features/jira/data/jira_api_service.dart';
import 'package:tree_launcher/features/jira/data/jira_issue_cache.dart';
import 'package:tree_launcher/features/jira/domain/jira_pat.dart';

/// Looks up Jira issue titles (summaries) for the worktree list.
///
/// Titles are seeded from the on-disk [JiraIssueCache] (issues opened in the
/// issue dialog), then refreshed from Jira once per key per app session with a
/// single batched search. Without a Jira token, or when Jira is unreachable,
/// only cached titles are shown — failures are logged, never surfaced.
class JiraTitlesController extends ChangeNotifier {
  JiraTitlesController({JiraApiService? service, JiraIssueCache? cache})
    : _service = service ?? JiraApiService(),
      _cache = cache ?? JiraIssueCache();

  final JiraApiService _service;
  final JiraIssueCache _cache;

  final Map<String, String> _titles = {};

  /// Keys already fetched (or being fetched) this session.
  final Set<String> _requested = {};

  Future<void>? _cacheLoad;
  bool _disposed = false;

  /// The title for [issueKey], or null when unknown.
  String? titleFor(String issueKey) => _titles[issueKey.trim().toUpperCase()];

  /// Loads titles for [issueKeys] not yet requested this session. Cheap to
  /// call repeatedly (e.g. on every list rebuild).
  Future<void> ensureTitles(Iterable<String> issueKeys) async {
    final keys = issueKeys
        .map((k) => k.trim().toUpperCase())
        .where((k) => k.isNotEmpty && !_requested.contains(k))
        .toSet();
    if (keys.isEmpty) return;
    _requested.addAll(keys);

    await (_cacheLoad ??= _loadCache());
    if (await readJiraPat() == null) return;

    try {
      final issues = await _service.searchIssues('key in (${keys.join(',')})');
      for (final issue in issues) {
        _setTitle(issue.key, issue.summary);
      }
    } catch (e) {
      // Jira rejects the whole search when any key doesn't exist, so fall
      // back to fetching the keys one by one.
      debugPrint('Jira title search failed, fetching individually: $e');
      await Future.wait(keys.map(_fetchOne));
    }
    _notify();
  }

  Future<void> _fetchOne(String key) async {
    try {
      final issue = await _service.fetchIssue(key);
      _setTitle(issue.key, issue.summary);
    } catch (e) {
      debugPrint('Jira title fetch failed for $key: $e');
    }
  }

  Future<void> _loadCache() async {
    final cached = await _cache.readAll();
    for (final entry in cached.entries) {
      _setTitle(entry.key, entry.value.summary);
    }
    _notify();
  }

  void _setTitle(String key, String summary) {
    final title = summary.trim();
    if (title.isNotEmpty) _titles[key.toUpperCase()] = title;
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
