import 'package:flutter/foundation.dart';

import 'package:tree_launcher/core/errors/user_message.dart';

/// What the issue tabs' controllers (Jira, GitHub) share: loading, with the
/// response of a load that a newer one replaced dropped; the error to show;
/// a search shown instead of the list; and the selected issues.
///
/// [I] is the issue type and [K] what identifies an issue (a Jira key, a
/// GitHub number). A subclass says how to load ([refresh], with [load]),
/// what its list is ([listedIssues]) and how it filters ([visibleIssues]).
abstract class IssueListController<I, K> extends ChangeNotifier {
  /// What identifies [issue].
  @protected
  K keyOf(I issue);

  /// The issues of the picked fixVersion or milestone, shown when not
  /// searching.
  @protected
  List<I> get listedIssues;

  /// The issues that pass the tab's filters, in list order.
  List<I> get visibleIssues;

  /// Whether [searchQuery] has something to search for, so [issues] are its
  /// results.
  bool get isSearching;

  /// Reloads what the tab shows: the list, or the search's results.
  Future<void> refresh();

  bool _isLoading = false;
  String? _error;
  DateTime? _lastRefreshed;
  bool _disposed = false;

  /// Bumped on every load, so a slow response for an earlier repo, list or
  /// search is dropped instead of overwriting newer results.
  int _generation = 0;

  String _searchQuery = '';
  List<I> _searchResults = const [];

  /// Keys of the selected issues; always a subset of [visibleIssues]'.
  final Set<K> _selected = {};

  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get lastRefreshed => _lastRefreshed;

  /// The search's results while searching, otherwise [listedIssues].
  List<I> get issues => isSearching ? _searchResults : listedIssues;

  /// What was searched for; empty when not searching.
  String get searchQuery => _searchQuery;

  /// The last search's results.
  @protected
  List<I> get searchResults => _searchResults;

  /// Keys of the selected issues.
  Set<K> get selectedKeys => Set.unmodifiable(_selected);

  /// The selected issues, in list order.
  List<I> get selectedIssues =>
      visibleIssues.where((i) => _selected.contains(keyOf(i))).toList();

  /// Shows the issues matching [query] instead of the list. A query with
  /// nothing to search for goes back to the list, reloading it.
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
      notify();
    }
  }

  void setSelected(K key, bool selected) {
    selected ? _selected.add(key) : _selected.remove(key);
    notify();
  }

  /// Selects every visible issue, or clears the selection when all already
  /// are.
  void toggleSelectAll() {
    final keys = visibleIssues.map(keyOf);
    if (keys.every(_selected.contains)) {
      _selected.clear();
    } else {
      _selected.addAll(keys);
    }
    notify();
  }

  void clearSelection() {
    if (_selected.isEmpty) return;
    _selected.clear();
    notify();
  }

  /// Runs [work] as a load: shows the spinner and then [work]'s error, if
  /// any, unless a newer load has started meanwhile. [work] gets the load's
  /// generation, to check with [isCurrent] before it stores what it got.
  @protected
  Future<void> load(Future<void> Function(int generation) work) async {
    final generation = ++_generation;
    _isLoading = true;
    _error = null;
    notify();
    try {
      await work(generation);
    } catch (e) {
      if (isCurrent(generation)) _error = userMessage(e);
    } finally {
      if (isCurrent(generation)) {
        _isLoading = false;
        notify();
      }
    }
  }

  /// Whether the load of [generation] is still the newest.
  @protected
  bool isCurrent(int generation) => generation == _generation;

  /// Notes that a load stored fresh issues: now is when the tab was last
  /// refreshed, and issues no longer shown are unselected.
  @protected
  void loaded() {
    _lastRefreshed = DateTime.now();
    pruneSelection();
  }

  /// Stores a search's [results], as [loaded] does.
  @protected
  void showSearchResults(List<I> results) {
    _searchResults = results;
    loaded();
  }

  /// Ends the search, going back to the list (without reloading it).
  @protected
  void endSearch() {
    _searchQuery = '';
    _searchResults = const [];
  }

  /// Unselects the issues that aren't visible.
  @protected
  void pruneSelection() => _selected.retainAll(visibleIssues.map(keyOf));

  /// Unselects every issue, without notifying.
  @protected
  void dropSelection() => _selected.clear();

  /// Forgets the search, the selection, the error and when it was loaded,
  /// and drops any load in flight. Doesn't notify.
  @protected
  void resetList() {
    _generation++;
    _searchQuery = '';
    _searchResults = const [];
    _isLoading = false;
    _error = null;
    _lastRefreshed = null;
    _selected.clear();
  }

  /// [notifyListeners], unless disposed (a load can finish after that).
  @protected
  void notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
