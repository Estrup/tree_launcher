import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/github_issues/data/github_issue_cache.dart';
import 'package:tree_launcher/features/github_issues/domain/github_issue.dart';
import 'package:tree_launcher/features/github_issues/presentation/widgets/github_issue_dialog.dart';
import 'package:tree_launcher/features/github_prs/domain/github_config.dart';

import 'fake_github_issues_service.dart';
import 'test_database.dart';

class _MemoryCache extends GithubIssueCache {
  _MemoryCache() : super(testDatabase());

  final Map<String, CachedGithubIssue> entries = {};

  @override
  Future<CachedGithubIssue?> read(String ref) async => entries[ref];

  @override
  Future<void> write(
    String ref,
    GithubIssue issue, {
    DateTime? fetchedAt,
  }) async {
    entries[ref] = CachedGithubIssue(
      issue: issue,
      fetchedAt: fetchedAt ?? DateTime.now(),
    );
  }
}

/// A service whose fetches fail, as when GitHub is unreachable.
class _FailingService extends FakeGithubIssuesService {
  @override
  Future<GithubIssue> fetchIssue(GithubConfig config, int number) async =>
      throw Exception('GitHub is unreachable');
}

final _config = GithubConfig(
  owner: 'acme',
  repo: 'app',
  token: 'token',
  issuesEnabled: true,
);

Future<List<String>> _pumpDialog(
  WidgetTester tester, {
  required FakeGithubIssuesService service,
  required _MemoryCache cache,
  VoidCallback? onIssueChanged,
}) async {
  final opened = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.current,
      home: Scaffold(
        body: GithubIssueDialog(
          config: _config,
          number: 482,
          service: service,
          cache: cache,
          onIssueChanged: onIssueChanged,
          openUrl: opened.add,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return opened;
}

void main() {
  testWidgets('shows the fetched issue with its comments and labels', (
    tester,
  ) async {
    final service = FakeGithubIssuesService()
      ..detail = fakeIssue(482, 'Login redirect loops', labels: ['bug'])
          .copyWith(
            comments: const [
              GithubIssueComment(author: 'jo', body: 'Same here'),
            ],
          );
    final cache = _MemoryCache();
    final opened = await _pumpDialog(tester, service: service, cache: cache);

    expect(find.text('acme/app#482'), findsOneWidget);
    expect(find.text('Login redirect loops'), findsOneWidget);
    expect(find.text('bug'), findsOneWidget);
    expect(find.text('Same here'), findsOneWidget);
    expect(find.text('No description'), findsOneWidget);
    expect(cache.entries.keys, ['acme/app#482']);

    await tester.tap(find.text('Open in GitHub'));
    expect(opened, ['https://github.com/acme/app/issues/482']);
  });

  testWidgets('refreshes a cached issue every time it opens', (tester) async {
    final service = FakeGithubIssuesService()
      ..detail = fakeIssue(482, 'Fresh title');
    final cache = _MemoryCache();
    await cache.write(
      'acme/app#482',
      fakeIssue(482, 'Stale title'),
      fetchedAt: DateTime(2026, 1, 1),
    );
    await _pumpDialog(tester, service: service, cache: cache);

    expect(service.detailFetches, 1);
    expect(find.text('Fresh title'), findsOneWidget);
    expect(find.text('Stale title'), findsNothing);
    expect(find.text('Fetched just now'), findsOneWidget);
  });

  testWidgets('keeps the cached copy beside a failed refresh', (tester) async {
    final cache = _MemoryCache();
    await cache.write('acme/app#482', fakeIssue(482, 'Cached title'));
    await _pumpDialog(tester, service: _FailingService(), cache: cache);

    expect(find.text('Cached title'), findsOneWidget);
    expect(find.text('GitHub is unreachable'), findsOneWidget);
  });

  testWidgets('changes the state from the pill', (tester) async {
    var changed = 0;
    final service = FakeGithubIssuesService()
      ..detail = fakeIssue(482, 'Login redirect loops');
    await _pumpDialog(
      tester,
      service: service,
      cache: _MemoryCache(),
      onIssueChanged: () => changed++,
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close as completed'));
    await tester.pumpAndSettle();

    expect(service.stateChanges, {482: GithubIssueState.closed});
    expect(changed, 1);
    expect(service.detailFetches, 2);
  });

  testWidgets('assigns me, and hides the button once I am assigned', (
    tester,
  ) async {
    final service = FakeGithubIssuesService()
      ..detail = fakeIssue(482, 'Login redirect loops');
    await _pumpDialog(tester, service: service, cache: _MemoryCache());
    expect(find.text('Unassigned'), findsOneWidget);

    service.detail = fakeIssue(482, 'Login redirect loops', assignees: ['me']);
    await tester.tap(find.text('Assign to me'));
    await tester.pumpAndSettle();

    expect(service.assigned, {482: 'me'});
    expect(find.text('Assign to me'), findsNothing);
  });

  testWidgets('says so when GitHub leaves me out', (tester) async {
    final service = FakeGithubIssuesService()
      ..detail = fakeIssue(482, 'Login redirect loops')
      ..ignoreAssignee = true;
    await _pumpDialog(tester, service: service, cache: _MemoryCache());

    await tester.tap(find.text('Assign to me'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining("GitHub didn't assign you to #482"),
      findsOneWidget,
    );
  });
}
