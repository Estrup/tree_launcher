import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/features/github_issues/data/github_issue_cache.dart';
import 'package:tree_launcher/features/github_issues/domain/github_issue.dart';
import 'package:tree_launcher/features/github_issues/domain/github_issue_search.dart';
import 'package:tree_launcher/features/github_issues/domain/github_milestone.dart';
import 'package:tree_launcher/features/github_issues/presentation/github_issue_actions.dart';
import 'package:tree_launcher/features/github_prs/data/github_http.dart';
import 'package:tree_launcher/features/github_prs/domain/github_config.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_naming.dart';

Map<String, dynamic> _apiIssue({
  int number = 482,
  String state = 'open',
  String? stateReason,
}) => {
  'number': number,
  'title': 'Login redirect loops',
  'state': state,
  'state_reason': stateReason,
  'html_url': 'https://github.com/acme/app/issues/$number',
  'user': {'login': 'kim'},
  'assignees': [
    {'login': 'me'},
    {'login': 'jo'},
  ],
  'labels': [
    {'name': 'bug', 'color': 'd73a4a'},
  ],
  'milestone': {'number': 3, 'title': 'v2.0'},
  'type': {'id': 1, 'name': 'Bug'},
  'body': 'Steps to reproduce',
  'created_at': '2026-10-01T08:00:00Z',
  'updated_at': '2026-10-18T09:30:00Z',
  'comments': 4,
};

void main() {
  group('GithubIssue', () {
    test('parses the REST API shape', () {
      final issue = GithubIssue.fromApiJson(_apiIssue());
      expect(issue.number, 482);
      expect(issue.title, 'Login redirect loops');
      expect(issue.state, GithubIssueState.open);
      expect(issue.author, 'kim');
      expect(issue.assignees, ['me', 'jo']);
      expect(issue.labels.single.name, 'bug');
      expect(issue.labels.single.color, 'd73a4a');
      expect(issue.milestone, 'v2.0');
      expect(issue.type, 'Bug');
      expect(issue.commentCount, 4);
      expect(issue.updatedAt, DateTime.parse('2026-10-18T09:30:00Z'));
    });

    test('tolerates missing fields', () {
      final issue = GithubIssue.fromApiJson({'number': 1});
      expect(issue.title, '');
      expect(issue.state, GithubIssueState.open);
      expect(issue.assignees, isEmpty);
      expect(issue.labels, isEmpty);
      expect(issue.milestone, isNull);
      expect(issue.type, isNull);
    });

    test('reads closed issues as closed or not planned', () {
      GithubIssueState state(String? reason) => GithubIssue.fromApiJson(
        _apiIssue(state: 'closed', stateReason: reason),
      ).state;
      expect(state('completed'), GithubIssueState.closed);
      expect(state(null), GithubIssueState.closed);
      expect(state('not_planned'), GithubIssueState.notPlanned);
      expect(state('duplicate'), GithubIssueState.notPlanned);
      expect(
        GithubIssue.fromApiJson(
          _apiIssue(state: 'open', stateReason: 'reopened'),
        ).state,
        GithubIssueState.open,
      );
    });

    test('tells pull requests apart', () {
      expect(GithubIssue.isPullRequestJson(_apiIssue()), isFalse);
      expect(
        GithubIssue.isPullRequestJson({
          ..._apiIssue(),
          'pull_request': {'url': 'x'},
        }),
        isTrue,
      );
    });

    test('round-trips the cache shape with comments', () {
      final issue = GithubIssue.fromApiJson(_apiIssue()).copyWith(
        comments: [
          GithubIssueComment(
            author: 'jo',
            body: 'Same here',
            created: DateTime.parse('2026-10-02T10:00:00Z'),
          ),
        ],
      );
      final restored = GithubIssue.fromJson(issue.toJson());
      expect(restored.number, 482);
      expect(restored.state, GithubIssueState.open);
      expect(restored.assignees, ['me', 'jo']);
      expect(restored.labels.single.name, 'bug');
      expect(restored.milestone, 'v2.0');
      expect(restored.type, 'Bug');
      expect(restored.comments.single.author, 'jo');
      expect(restored.comments.single.body, 'Same here');
    });

    test('names an issue outside its repo', () {
      expect(githubIssueRef('acme', 'app', 482), 'acme/app#482');
    });
  });

  group('GithubIssueCache', () {
    late Directory tempDir;
    late GithubIssueCache cache;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('github_issue_cache');
      cache = GithubIssueCache(directoryPath: tempDir.path);
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('misses, then round-trips the issue and fetchedAt', () async {
      expect(await cache.read('acme/app#482'), isNull);
      final stamp = DateTime.parse('2026-10-19T12:00:00.000Z');
      await cache.write(
        'acme/app#482',
        GithubIssue.fromApiJson(_apiIssue()),
        fetchedAt: stamp,
      );
      final cached = await cache.read('acme/app#482');
      expect(cached!.issue.title, 'Login redirect loops');
      expect(cached.fetchedAt, stamp);
    });
  });

  group('search', () {
    test('finds the number a query names', () {
      expect(githubIssueNumberInQuery('482'), 482);
      expect(githubIssueNumberInQuery(' #482 '), 482);
      expect(githubIssueNumberInQuery('login 482'), isNull);
      expect(githubIssueNumberInQuery(''), isNull);
    });

    test('passes the query on with the repo and is:issue', () {
      expect(
        githubIssueSearchQuery('acme', 'app', 'login label:bug'),
        'repo:acme/app is:issue login label:bug',
      );
      expect(
        githubIssueSearchQuery('acme', 'app', '#482'),
        'repo:acme/app is:issue 482',
      );
      expect(githubIssueSearchQuery('acme', 'app', '  '), isNull);
    });
  });

  test('orders milestones open by due date, then closed newest first', () {
    final ordered = orderMilestonesForPicker([
      const GithubMilestone(number: 1, title: 'Old', open: false),
      GithubMilestone(number: 2, title: 'Later', dueOn: DateTime(2026, 12, 1)),
      const GithubMilestone(number: 3, title: 'Someday'),
      GithubMilestone(number: 4, title: 'Next', dueOn: DateTime(2026, 11, 1)),
      GithubMilestone(
        number: 5,
        title: 'Recent',
        open: false,
        closedAt: DateTime(2026, 9, 1),
      ),
    ]);
    expect(ordered.map((m) => m.title), [
      'Next',
      'Later',
      'Someday',
      'Recent',
      'Old',
    ]);
  });

  test('names a worktree for an issue with its number last', () {
    expect(
      worktreeNameForGithubIssue(482, 'Login redirect loops'),
      'login-redirect-loops-482',
    );
    expect(worktreeNameForGithubIssue(7, 'Værksted på!'), 'vaerksted-paa-7');
    expect(worktreeNameForGithubIssue(9, '???'), '9');
    expect(validateWorktreeName(worktreeNameForGithubIssue(1, 'A B')), isNull);
  });

  test('builds the Claude context prompt', () {
    final issue = GithubIssue.fromApiJson(_apiIssue());
    final config = GithubConfig(owner: 'acme', repo: 'app', token: 't');
    expect(
      githubIssueContextPrompt(issue, config),
      'Context: Working on GitHub issue #482 "Login redirect loops" in '
      'acme/app (https://github.com/acme/app/issues/482). Run '
      '"gh issue view 482 -R acme/app --comments" for its description and '
      'discussion.',
    );
  });

  test('summarizes a bulk state change', () {
    expect(
      bulkStateSummary(GithubIssueState.closed, 3, 3, const {}),
      'Closed 3 issues as completed.',
    );
    expect(
      bulkStateSummary(GithubIssueState.notPlanned, 5, 4, const {
        12: 'Validation failed',
      }),
      'Closed 3 of 5 issues as not planned. #12: Validation failed. '
      '1 was already not planned.',
    );
    expect(
      bulkStateSummary(GithubIssueState.open, 4, 2, const {}),
      'Reopened 2 of 4 issues. 2 were already open.',
    );
  });

  group('GitHub HTTP', () {
    test('finds the next page in a Link header', () {
      expect(
        githubNextPage(
          '<https://api.github.com/x?page=2>; rel="next", '
          '<https://api.github.com/x?page=5>; rel="last"',
        ),
        Uri.parse('https://api.github.com/x?page=2'),
      );
      expect(
        githubNextPage('<https://api.github.com/x?page=1>; rel="prev"'),
        isNull,
      );
      expect(githubNextPage(null), isNull);
    });

    test('words errors for the user', () {
      String message(int status, [String body = '{}', String? remaining]) =>
          githubErrorMessage(
            status,
            body,
            repo: 'acme/app',
            rateLimitRemaining: remaining,
            forbiddenHint: 'It needs Issues read and write.',
          );
      expect(message(401), 'GitHub authentication failed. Check your token.');
      expect(message(404), 'Repository not found: acme/app');
      expect(message(410), 'Issues are turned off for acme/app.');
      expect(
        message(403, '{"message":"Resource not accessible"}'),
        "The token can't access acme/app. It needs Issues read and write. "
        '(Resource not accessible)',
      );
      expect(message(403, '{}', '0'), startsWith('GitHub rate limit reached.'));
      expect(
        message(
          422,
          '{"message":"Validation Failed","errors":[{"message":"bad"}]}',
        ),
        'Validation Failed: bad',
      );
    });
  });
}
