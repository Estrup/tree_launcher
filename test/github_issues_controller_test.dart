import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/features/github_issues/data/github_issues_api_service.dart';
import 'package:tree_launcher/features/github_issues/domain/github_issue.dart';
import 'package:tree_launcher/features/github_issues/presentation/controllers/github_issues_controller.dart';
import 'package:tree_launcher/features/github_prs/domain/github_config.dart';
import 'package:tree_launcher/models/repo_config.dart';

import 'fake_github_issues_service.dart';

/// Lets the deferred sync and its loads finish.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeGithubIssuesService service;
  late GithubIssuesController controller;

  setUp(() {
    service = FakeGithubIssuesService();
    controller = GithubIssuesController(service: service);
  });

  tearDown(() => controller.dispose());

  Future<void> sync(RepoConfig repo) async {
    controller.syncToRepo(repo);
    await _settle();
    await _settle();
  }

  test('loads every open issue for a repo with issues on', () async {
    await sync(issuesRepo());
    expect(controller.config?.repo, 'app');
    expect(controller.selectedMilestoneNumber, isNull);
    expect(controller.issues.map((i) => i.number), [482, 480]);
    expect(service.fetchedMilestones, [null]);
    expect(controller.myLogin, 'me');
  });

  test('stays empty while the Issues tab is off', () async {
    await sync(
      RepoConfig(
        name: 'app',
        path: '/repos/app',
        githubConfig: GithubConfig(owner: 'acme', repo: 'app', token: 't'),
      ),
    );
    expect(controller.config, isNull);
    expect(controller.issues, isEmpty);
    expect(service.fetchedMilestones, isEmpty);
  });

  test(
    'opens on the remembered milestone, or all open when it is gone',
    () async {
      await sync(issuesRepo(milestone: 3));
      expect(controller.selectedMilestone?.title, 'v2.0');
      expect(controller.issues.map((i) => i.number), [470, 460]);

      final other = GithubIssuesController(service: service);
      addTearDown(other.dispose);
      other.syncToRepo(issuesRepo(milestone: 99));
      await _settle();
      await _settle();
      expect(other.selectedMilestoneNumber, isNull);
      expect(other.issues.map((i) => i.number), [482, 480]);
    },
  );

  test('picking a milestone loads and remembers it', () async {
    final picks = <int?>[];
    controller.onMilestoneSelected = (_, number) => picks.add(number);
    await sync(issuesRepo());

    await controller.selectMilestone(3);
    expect(controller.issues.map((i) => i.number), [470, 460]);
    await controller.selectMilestone(null);
    expect(controller.issues.map((i) => i.number), [482, 480]);
    expect(picks, [3, null]);

    // A refresh keeps the pick rather than the repo's remembered one.
    await controller.selectMilestone(3);
    await controller.refresh();
    expect(controller.selectedMilestoneNumber, 3);
  });

  test('searches, lists the named issue first, and goes back', () async {
    await sync(issuesRepo());
    service.byNumber = {300: fakeIssue(300, 'Old login bug')};
    service.found = [fakeIssue(12, 'Mentions 300'), fakeIssue(300, 'dup')];

    await controller.search('#300');
    expect(controller.isSearching, isTrue);
    expect(service.searched.last, 'repo:acme/app is:issue 300');
    expect(controller.issues.map((i) => i.number), [300, 12]);

    await controller.search('');
    expect(controller.isSearching, isFalse);
    expect(controller.issues.map((i) => i.number), [482, 480]);
  });

  test('picking a milestone ends a search', () async {
    await sync(issuesRepo());
    await controller.search('login');
    await controller.selectMilestone(3);
    expect(controller.isSearching, isFalse);
    expect(controller.searchQuery, '');
    expect(controller.issues.map((i) => i.number), [470, 460]);
  });

  test('filters by state and label, and prunes the selection', () async {
    await sync(issuesRepo(milestone: 3));
    controller.toggleSelectAll();
    expect(controller.selectedNumbers, {470, 460});

    controller.toggleState(GithubIssueState.closed);
    expect(controller.visibleIssues.map((i) => i.number), [460]);
    expect(controller.selectedNumbers, {460});
    expect(controller.stateCounts, [
      (GithubIssueState.open, 1),
      (GithubIssueState.closed, 1),
    ]);

    controller.clearFilters();
    await controller.selectMilestone(null);
    controller.toggleLabel('bug');
    expect(controller.visibleIssues.map((i) => i.number), [482]);
    expect(controller.labelCounts.map((c) => (c.label.name, c.count)), [
      ('bug', 1),
      ('enhancement', 1),
    ]);
    // A filtered state with no issues stays offered.
    controller.toggleState(GithubIssueState.notPlanned);
    expect(controller.stateCounts.last, (GithubIssueState.notPlanned, 0));
    expect(controller.visibleIssues, isEmpty);
  });

  test('changes state and reports refusals', () async {
    await sync(issuesRepo());
    service.refuse = {480: 'Validation failed'};
    final failures = await controller.applyState([
      482,
      480,
    ], GithubIssueState.notPlanned);
    expect(service.stateChanges, {482: GithubIssueState.notPlanned});
    expect(failures, {480: 'Validation failed'});
  });

  test('assigns me, and says so when GitHub leaves me out', () async {
    await sync(issuesRepo());
    await controller.assignToMe(482);
    expect(service.assigned, {482: 'me'});

    service.ignoreAssignee = true;
    await expectLater(
      controller.assignToMe(482),
      throwsA(
        predicate((e) => e.toString().contains("didn't assign you to #482")),
      ),
    );
  });

  test('drops a slow load for a repo that was switched away from', () async {
    final gate = Completer<void>();
    final slow = _SlowService(gate);
    final c = GithubIssuesController(service: slow);
    addTearDown(c.dispose);
    c.syncToRepo(issuesRepo());
    await _settle();
    await _settle();

    c.syncToRepo(
      RepoConfig(
        name: 'other',
        path: '/repos/other',
        githubConfig: GithubConfig(
          owner: 'acme',
          repo: 'other',
          token: 'token',
          issuesEnabled: true,
        ),
      ),
    );
    await _settle();
    await _settle();
    expect(c.issues.map((i) => i.title), ['In other']);

    gate.complete();
    await _settle();
    expect(c.issues.map((i) => i.title), ['In other']);
  });
}

/// Holds acme/app's issues back until [gate] completes.
class _SlowService extends FakeGithubIssuesService {
  _SlowService(this.gate);

  final Completer<void> gate;

  @override
  Future<GithubIssueList> fetchIssues(
    GithubConfig config, {
    int? milestone,
  }) async {
    if (config.repo == 'app') {
      await gate.future;
      return (issues: [fakeIssue(1, 'In app')], truncated: false);
    }
    return (issues: [fakeIssue(2, 'In other')], truncated: false);
  }
}
