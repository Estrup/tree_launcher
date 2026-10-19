import 'package:tree_launcher/features/github_issues/domain/github_issue.dart';
import 'package:tree_launcher/features/github_issues/domain/github_milestone.dart';
import 'package:tree_launcher/features/github_prs/data/github_http.dart';
import 'package:tree_launcher/features/github_prs/domain/github_config.dart';

/// A page-limited list of issues, and whether GitHub has more.
typedef GithubIssueList = ({List<GithubIssue> issues, bool truncated});

/// Reads and changes a repo's GitHub issues over the REST API.
class GithubIssuesApiService {
  /// Pages of 100 a list loads at most (so up to 500 items).
  static const maxListPages = 5;

  /// Added to a 403 that isn't a rate limit.
  static const _forbiddenHint = 'It needs Issues read and write.';

  Uri _repoUri(
    GithubConfig config,
    String path, [
    Map<String, String>? query,
  ]) => Uri.https(
    'api.github.com',
    '/repos/${config.owner}/${config.repo}$path',
    query,
  );

  Future<GithubResponse> _get(GithubConfig config, Uri uri) =>
      githubRequest(config, 'GET', uri, forbiddenHint: _forbiddenHint);

  /// The repo's milestones, open and closed.
  Future<List<GithubMilestone>> fetchMilestones(GithubConfig config) async {
    final milestones = <GithubMilestone>[];
    Uri? uri = _repoUri(config, '/milestones', {
      'state': 'all',
      'per_page': '100',
    });
    for (var page = 0; uri != null && page < 3; page++) {
      final response = await _get(config, uri);
      milestones.addAll(
        (response.json as List<dynamic>).whereType<Map<String, dynamic>>().map(
          GithubMilestone.fromApiJson,
        ),
      );
      uri = response.nextPage;
    }
    return milestones;
  }

  /// The issues in [milestone], open and closed, or every open issue when
  /// [milestone] is null. Most recently updated first; pull requests left
  /// out.
  Future<GithubIssueList> fetchIssues(
    GithubConfig config, {
    int? milestone,
  }) async {
    final issues = <GithubIssue>[];
    Uri? uri = _repoUri(config, '/issues', {
      'state': milestone == null ? 'open' : 'all',
      'milestone': ?milestone?.toString(),
      'sort': 'updated',
      'direction': 'desc',
      'per_page': '100',
    });
    for (var page = 0; uri != null && page < maxListPages; page++) {
      final response = await _get(config, uri);
      issues.addAll(_issuesIn(response.json as List<dynamic>));
      uri = response.nextPage;
    }
    return (issues: issues, truncated: uri != null);
  }

  /// The issues GitHub search finds for [query] (see
  /// `githubIssueSearchQuery`), most recently updated first.
  Future<List<GithubIssue>> searchIssues(
    GithubConfig config,
    String query, {
    required int limit,
  }) async {
    final response = await _get(
      config,
      Uri.https('api.github.com', '/search/issues', {
        'q': query,
        'sort': 'updated',
        'order': 'desc',
        'per_page': '$limit',
      }),
    );
    final items =
        (response.json as Map<String, dynamic>)['items'] as List<dynamic>? ??
        const [];
    return _issuesIn(items).toList();
  }

  /// Issue [number], without its comments; null when there is none or it is
  /// a pull request.
  Future<GithubIssue?> findIssue(GithubConfig config, int number) async {
    try {
      final response = await _get(config, _repoUri(config, '/issues/$number'));
      final json = response.json as Map<String, dynamic>;
      return GithubIssue.isPullRequestJson(json)
          ? null
          : GithubIssue.fromApiJson(json);
    } on GithubApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Issue [number] with its comments (up to 300), for the issue dialog.
  Future<GithubIssue> fetchIssue(GithubConfig config, int number) async {
    final response = await _get(config, _repoUri(config, '/issues/$number'));
    final issue = GithubIssue.fromApiJson(
      response.json as Map<String, dynamic>,
    );
    final comments = <GithubIssueComment>[];
    Uri? uri = _repoUri(config, '/issues/$number/comments', {
      'per_page': '100',
    });
    for (var page = 0; uri != null && page < 3; page++) {
      final commentsPage = await _get(config, uri);
      comments.addAll(
        (commentsPage.json as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(GithubIssueComment.fromApiJson),
      );
      uri = commentsPage.nextPage;
    }
    return issue.copyWith(comments: comments);
  }

  /// Moves issue [number] to [state]: reopens it, or closes it as completed
  /// or as not planned.
  Future<void> setState(
    GithubConfig config,
    int number,
    GithubIssueState state,
  ) async {
    await githubRequest(
      config,
      'PATCH',
      _repoUri(config, '/issues/$number'),
      body: switch (state) {
        GithubIssueState.open => {'state': 'open'},
        GithubIssueState.closed => {
          'state': 'closed',
          'state_reason': 'completed',
        },
        GithubIssueState.notPlanned => {
          'state': 'closed',
          'state_reason': 'not_planned',
        },
      },
      forbiddenHint: _forbiddenHint,
    );
  }

  /// Adds [login] to issue [number]'s assignees, keeping the others, and
  /// returns the assignees GitHub reports afterwards. GitHub silently skips
  /// a login without push access, so it may be missing.
  Future<List<String>> addAssignee(
    GithubConfig config,
    int number,
    String login,
  ) async {
    final response = await githubRequest(
      config,
      'POST',
      _repoUri(config, '/issues/$number/assignees'),
      body: {
        'assignees': [login],
      },
      forbiddenHint: _forbiddenHint,
    );
    return GithubIssue.fromApiJson(
      response.json as Map<String, dynamic>,
    ).assignees;
  }

  /// The login [config]'s token authenticates as, or null when unknown.
  /// Shared with the PRs tab, so it is looked up once.
  Future<String?> fetchMyLogin(GithubConfig config) => githubLoginFor(config);

  static Iterable<GithubIssue> _issuesIn(List<dynamic> items) => items
      .whereType<Map<String, dynamic>>()
      .where((json) => !GithubIssue.isPullRequestJson(json))
      .map(GithubIssue.fromApiJson);
}
