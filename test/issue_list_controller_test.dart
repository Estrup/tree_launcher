import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/core/presentation/issue_list_controller.dart';

/// Issues are their own keys; a load waits for [next] to give its result.
class _Issues extends IssueListController<String, String> {
  List<String> _listed = const [];
  Completer<List<String>>? next;

  /// Issues containing this are hidden.
  String? hide;

  /// Hides the issues containing [text], like a filter does.
  void filterOut(String text) {
    hide = text;
    pruneSelection();
    notify();
  }

  @override
  String keyOf(String issue) => issue;

  @override
  List<String> get listedIssues => _listed;

  @override
  List<String> get visibleIssues => [
    for (final issue in issues)
      if (hide == null || !issue.contains(hide!)) issue,
  ];

  @override
  bool get isSearching => searchQuery.isNotEmpty;

  @override
  Future<void> refresh() => load((generation) async {
    final result = await (next = Completer<List<String>>()).future;
    if (!isCurrent(generation)) return;
    if (isSearching) {
      showSearchResults(result);
    } else {
      _listed = result;
      loaded();
    }
  });
}

void main() {
  late _Issues issues;

  setUp(() => issues = _Issues());

  test('a load that a newer one replaced is dropped', () async {
    final first = issues.refresh();
    final firstLoad = issues.next!;
    final second = issues.refresh();
    issues.next!.complete(['new']);
    await second;
    firstLoad.complete(['old']);
    await first;

    expect(issues.issues, ['new']);
    expect(issues.isLoading, isFalse);
    expect(issues.lastRefreshed, isNotNull);
  });

  test('shows the error of the newest load only', () async {
    final first = issues.refresh();
    final firstLoad = issues.next!;
    final second = issues.refresh();
    firstLoad.completeError(Exception('old failure'));
    await first;
    expect(issues.error, isNull);
    expect(issues.isLoading, isTrue);

    issues.next!.completeError(Exception('Jira is down'));
    await second;
    expect(issues.error, 'Jira is down');
    expect(issues.isLoading, isFalse);
  });

  test('a search shows its results, and an empty one the list again', () async {
    final listLoad = issues.refresh();
    issues.next!.complete(['a', 'b']);
    await listLoad;

    final searching = issues.search('  x ');
    expect(issues.searchQuery, 'x');
    issues.next!.complete(['x1']);
    await searching;
    expect(issues.issues, ['x1']);

    final back = issues.search('');
    issues.next!.complete(['a', 'b', 'c']);
    await back;
    expect(issues.issues, ['a', 'b', 'c']);
  });

  test('keeps the selection to the visible issues', () async {
    final listLoad = issues.refresh();
    issues.next!.complete(['a1', 'b1', 'b2']);
    await listLoad;

    issues.toggleSelectAll();
    expect(issues.selectedKeys, {'a1', 'b1', 'b2'});
    issues.filterOut('b');
    expect(issues.selectedIssues, ['a1']);
    issues.toggleSelectAll();
    expect(issues.selectedKeys, isEmpty);
  });

  test('a load finishing after dispose does not notify', () async {
    final pending = issues.refresh();
    issues.dispose();
    issues.next!.complete(['late']);
    await pending;
  });
}
