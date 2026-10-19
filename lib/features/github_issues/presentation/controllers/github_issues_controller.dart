import 'package:flutter/foundation.dart';

import 'package:tree_launcher/features/github_issues/data/github_issues_api_service.dart';
import 'package:tree_launcher/features/github_issues/domain/github_issue.dart';
import 'package:tree_launcher/features/github_issues/domain/github_issue_search.dart';
import 'package:tree_launcher/features/github_issues/domain/github_milestone.dart';
import 'package:tree_launcher/features/github_prs/domain/github_config.dart';
import 'package:tree_launcher/features/github_prs/domain/pull_request.dart';
import 'package:tree_launcher/models/repo_config.dart';

/// One label in the Issues tab's filter, with how many loaded issues have it.
class GithubLabelCount {
  final GithubLabel label;
  final int count;

  const GithubLabelCount({required this.label, required this.count});
}

/// Backs the Issues tab: the selected repo's milestones, the issues in the
/// selected milestone (or every open issue) or found by a search, the state
/// and label filters, the selected issues, and changing issues' state or
/// assignees.
class GithubIssuesController extends ChangeNotifier {
  GithubIssuesController({GithubIssuesApiService? service})
    : _service = service ?? GithubIssuesApiService();

  /// Most issues a search shows.
  static const searchLimit = 50;

  final GithubIssuesApiService _service;

  String? _repoPath;

  /// The repo's GitHub connection while its Issues tab is on.
  GithubConfig? _config;

  /// The milestone number saved in the repo config, used on the first load.
  int? _rememberedMilestone;

  List<GithubMilestone> _milestones = const [];
  bool _milestonesLoaded = false;

  /// Null for all open issues.
  int? _selectedMilestoneNumber;
  List<GithubIssue> _issues = const [];
  bool _issuesTruncated = false;
  String _searchQuery = '';
  List<GithubIssue> _searchResults = const [];
  bool _isLoading = false;
  String? _error;
  DateTime? _lastRefreshed;
  final Set<GithubIssueState> _stateFilter = {};

  /// Names of the labels filtered on.
  final Set<String> _labelFilter = {};

  /// Numbers of the selected issues; always a subset of [visibleIssues].
  final Set<int> _selected = {};

  /// The token's login, once looked up.
  String? _myLogin;
  bool _disposed = false;

  /// Bumped on every load, so a slow response for an earlier repo or
  /// milestone is dropped instead of overwriting newer results.
  int _generation = 0;

  /// Persists an explicit milestone pick (null for all open issues) for the
  /// repo at [repoPath]. Wired at the app level so it is remembered.
  void Function(String repoPath, int? milestoneNumber)? onMilestoneSelected;

  /// The GitHub connection, while the repo shows its issues.
  GithubConfig? get config => _config;

  /// The API service, shared with the issue dialog.
  GithubIssuesApiService get service => _service;

  /// Milestones for the picker: open first, then closed.
  List<GithubMilestone> get milestones => _milestones;

  /// The picked milestone's number; null for all open issues.
  int? get selectedMilestoneNumber => _selectedMilestoneNumber;

  GithubMilestone? get selectedMilestone => _milestones
      .where((m) => m.number == _selectedMilestoneNumber)
      .firstOrNull;

  /// The search's results while searching, otherwise the milestone's issues.
  List<GithubIssue> get issues => isSearching ? _searchResults : _issues;

  /// What was searched for; empty when not searching.
  String get searchQuery => _searchQuery;

  /// Whether [issues] are search results rather than the milestone's issues.
  bool get isSearching => _searchQ != null;

  /// Whether GitHub may have more issues than are loaded.
  bool get truncated =>
      isSearching ? _searchResults.length >= searchLimit : _issuesTruncated;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get lastRefreshed => _lastRefreshed;

  /// States filtered on; empty means every state is shown.
  Set<GithubIssueState> get stateFilter => Set.unmodifiable(_stateFilter);

  /// Label names filtered on; empty means labels don't matter.
  Set<String> get labelFilter => Set.unmodifiable(_labelFilter);

  bool get hasFilter => _stateFilter.isNotEmpty || _labelFilter.isNotEmpty;

  Set<int> get selectedNumbers => Set.unmodifiable(_selected);

  /// The selected issues, in list order.
  List<GithubIssue> get selectedIssues =>
      visibleIssues.where((i) => _selected.contains(i.number)).toList();

  /// The token's login, once known.
  String? get myLogin => _myLogin;

  /// Issues in a filtered state that have any filtered label.
  List<GithubIssue> get visibleIssues => issues
      .where(
        (i) =>
            (_stateFilter.isEmpty || _stateFilter.contains(i.state)) &&
            (_labelFilter.isEmpty ||
                i.labels.any((l) => _labelFilter.contains(l.name))),
      )
      .toList();

  /// The loaded issues' states with counts, in open → closed → not planned
  /// order. Filtered states with no issues are kept so they can be switched
  /// off.
  List<(GithubIssueState, int)> get stateCounts => [
    for (final state in GithubIssueState.values)
      if (issues.any((i) => i.state == state) || _stateFilter.contains(state))
        (state, issues.where((i) => i.state == state).length),
  ];

  /// The loaded issues' labels with counts, most used first. Filtered labels
  /// with no issues are kept at the end so they can be switched off.
  List<GithubLabelCount> get labelCounts {
    final labels = <String, GithubLabel>{};
    final counts = <String, int>{};
    for (final issue in issues) {
      for (final label in issue.labels) {
        labels[label.name] ??= label;
        counts[label.name] = (counts[label.name] ?? 0) + 1;
      }
    }
    final names = counts.keys.toList()
      ..sort((a, b) {
        final byCount = counts[b]!.compareTo(counts[a]!);
        return byCount != 0
            ? byCount
            : a.toLowerCase().compareTo(b.toLowerCase());
      });
    return [
      for (final name in names)
        GithubLabelCount(label: labels[name]!, count: counts[name]!),
      for (final name in _labelFilter.where((n) => !counts.containsKey(n)))
        GithubLabelCount(
          label: GithubLabel(name: name, color: ''),
          count: 0,
        ),
    ];
  }

  /// Key of issue [number] outside the repo (local tags), e.g.
  /// `owner/repo#482`.
  String issueRef(int number) =>
      githubIssueRef(_config?.owner ?? '', _config?.repo ?? '', number);

  /// Follows the app-level selected repo. Reloads when the repo, its GitHub
  /// connection, or whether it shows issues changes; otherwise only tracks
  /// the remembered milestone.
  void syncToRepo(RepoConfig? repo) {
    final github = repo?.githubConfig;
    final config = github != null && github.showsIssues ? github : null;
    _rememberedMilestone = repo?.githubMilestoneNumber;
    if (repo?.path == _repoPath && _sameConnection(config, _config)) return;

    _repoPath = repo?.path;
    _config = config;
    // Deferred so we never notifyListeners() synchronously during the
    // provider's build (syncToRepo is called from ProxyProvider.update).
    Future.microtask(() {
      _reset();
      if (config != null) refresh();
    });
  }

  static bool _sameConnection(GithubConfig? a, GithubConfig? b) =>
      a?.owner == b?.owner && a?.repo == b?.repo && a?.token == b?.token;

  /// Reloads the milestones and the selected milestone's issues, or the
  /// search's results while searching.
  Future<void> refresh() async {
    final config = _config;
    if (config == null) return;
    final generation = _startLoad();
    try {
      final q = _searchQ;
      if (q != null) {
        await _fetchSearchResults(config, q, generation);
        return;
      }
      final milestones = orderMilestonesForPicker(
        await _service.fetchMilestones(config),
      );
      if (generation != _generation) return;
      final wanted = _milestonesLoaded
          ? _selectedMilestoneNumber
          : _rememberedMilestone;
      _milestones = milestones;
      _milestonesLoaded = true;
      // A milestone that is gone falls back to all open issues.
      _selectedMilestoneNumber = milestones.any((m) => m.number == wanted)
          ? wanted
          : null;
      await _fetchIssues(config, generation);
    } catch (e) {
      _fail(generation, e);
    } finally {
      _finishLoad(generation);
    }
  }

  /// Shows the issues matching [query] (see [githubIssueSearchQuery])
  /// instead of the milestone's. An empty query goes back to the milestone,
  /// reloading its issues.
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

  /// Switches to milestone [number] (null for all open issues), remembers it
  /// for the repo, and loads its issues. Ends a search; the filters are kept.
  Future<void> selectMilestone(int? number) async {
    if (isSearching) {
      _searchQuery = '';
      _searchResults = const [];
    } else if (number == _selectedMilestoneNumber) {
      return;
    }
    _selectedMilestoneNumber = number;
    _rememberedMilestone = number;
    _issues = const [];
    _issuesTruncated = false;
    _selected.clear();
    final repoPath = _repoPath;
    if (repoPath != null) onMilestoneSelected?.call(repoPath, number);

    final config = _config;
    if (config == null) return;
    final generation = _startLoad();
    try {
      await _fetchIssues(config, generation);
    } catch (e) {
      _fail(generation, e);
    } finally {
      _finishLoad(generation);
    }
  }

  void toggleState(GithubIssueState state) {
    if (!_stateFilter.remove(state)) _stateFilter.add(state);
    _pruneSelection();
    _notify();
  }

  void toggleLabel(String name) {
    if (!_labelFilter.remove(name)) _labelFilter.add(name);
    _pruneSelection();
    _notify();
  }

  /// Clears the state and label filters.
  void clearFilters() {
    if (!hasFilter) return;
    _stateFilter.clear();
    _labelFilter.clear();
    _notify();
  }

  void setSelected(int number, bool selected) {
    selected ? _selected.add(number) : _selected.remove(number);
    _notify();
  }

  /// Selects every visible issue, or clears the selection when all already
  /// are.
  void toggleSelectAll() {
    final numbers = visibleIssues.map((i) => i.number);
    if (numbers.every(_selected.contains)) {
      _selected.clear();
    } else {
      _selected.addAll(numbers);
    }
    _notify();
  }

  void clearSelection() {
    if (_selected.isEmpty) return;
    _selected.clear();
    _notify();
  }

  /// Moves the issues [numbers] to [state], then reloads the list. Returns
  /// the issues GitHub refused to change, with its reason.
  Future<Map<int, String>> applyState(
    List<int> numbers,
    GithubIssueState state,
  ) async {
    final config = _config;
    if (config == null) return const {};
    final failures = <int, String>{};
    await Future.wait(
      numbers.map((number) async {
        try {
          await _service.setState(config, number, state);
        } catch (e) {
          failures[number] = _message(e);
        }
      }),
    );
    await refresh();
    return failures;
  }

  /// Adds the token's user to issue [number]'s assignees, then reloads the
  /// list. Throws when GitHub refuses, or silently leaves the user out (no
  /// write access).
  Future<void> assignToMe(int number) async {
    final config = _config;
    if (config == null) return;
    final me = _myLogin ?? await _service.fetchMyLogin(config);
    if (me == null) throw Exception("Couldn't look up your GitHub login.");
    _myLogin = me;
    final assignees = await _service.addAssignee(config, number, me);
    await refresh();
    if (!assignees.contains(me)) {
      throw Exception(
        "GitHub didn't assign you to #$number. You may lack write access to "
        '${config.owner}/${config.repo}.',
      );
    }
  }

  Future<void> _loadMe(GithubConfig config) async {
    final login = await _service.fetchMyLogin(config);
    if (login == null || _config != config) return;
    _myLogin = login;
    _notify();
  }

  void _pruneSelection() {
    _selected.retainAll(visibleIssues.map((i) => i.number));
  }

  Future<void> _fetchIssues(GithubConfig config, int generation) async {
    final result = await _service.fetchIssues(
      config,
      milestone: _selectedMilestoneNumber,
    );
    if (generation != _generation) return;
    _issues = result.issues;
    _issuesTruncated = result.truncated;
    _lastRefreshed = DateTime.now();
    _pruneSelection();
    if (_myLogin == null) _loadMe(config);
  }

  Future<void> _fetchSearchResults(
    GithubConfig config,
    String q,
    int generation,
  ) async {
    final number = githubIssueNumberInQuery(_searchQuery);
    final found = _service.searchIssues(config, q, limit: searchLimit);
    // The issue the query names, if it exists; its lookup failing must not
    // fail the search.
    final named = () async {
      if (number == null) return null;
      try {
        return await _service.findIssue(config, number);
      } catch (_) {
        return null;
      }
    }();
    final results = await found;
    final issue = await named;
    if (generation != _generation) return;
    _searchResults = [
      ?issue,
      ...results.where((i) => i.number != issue?.number),
    ];
    _lastRefreshed = DateTime.now();
    _pruneSelection();
    if (_myLogin == null) _loadMe(config);
  }

  String? get _searchQ {
    final config = _config;
    return config == null
        ? null
        : githubIssueSearchQuery(config.owner, config.repo, _searchQuery);
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
    _milestones = const [];
    _milestonesLoaded = false;
    _selectedMilestoneNumber = null;
    _issues = const [];
    _issuesTruncated = false;
    _searchQuery = '';
    _searchResults = const [];
    _isLoading = false;
    _error = null;
    _lastRefreshed = null;
    _stateFilter.clear();
    _labelFilter.clear();
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
