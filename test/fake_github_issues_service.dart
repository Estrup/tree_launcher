import 'package:tree_launcher/features/github_issues/data/github_issues_api_service.dart';
import 'package:tree_launcher/features/github_issues/domain/github_issue.dart';
import 'package:tree_launcher/features/github_issues/domain/github_milestone.dart';
import 'package:tree_launcher/features/github_prs/domain/github_config.dart';
import 'package:tree_launcher/features/github_prs/domain/pull_request.dart';
import 'package:tree_launcher/models/repo_config.dart';

/// A repo with the Issues tab on for acme/app.
RepoConfig issuesRepo({int? milestone}) => RepoConfig(
  name: 'app',
  path: '/repos/app',
  githubConfig: GithubConfig(
    owner: 'acme',
    repo: 'app',
    token: 'token',
    issuesEnabled: true,
  ),
  githubMilestoneNumber: milestone,
);

GithubIssue fakeIssue(
  int number,
  String title, {
  GithubIssueState state = GithubIssueState.open,
  List<String> assignees = const [],
  List<String> labels = const [],
}) => GithubIssue(
  number: number,
  title: title,
  state: state,
  htmlUrl: 'https://github.com/acme/app/issues/$number',
  author: 'kim',
  assignees: assignees,
  labels: [for (final name in labels) GithubLabel(name: name, color: 'd73a4a')],
);

/// Records what the controller asks for and answers from its fields.
class FakeGithubIssuesService extends GithubIssuesApiService {
  List<GithubMilestone> milestones = const [
    GithubMilestone(number: 3, title: 'v2.0'),
    GithubMilestone(number: 1, title: 'v1.0', open: false),
  ];

  /// Open issues, and each milestone's issues.
  List<GithubIssue> openIssues = [
    fakeIssue(482, 'Login redirect loops', labels: ['bug']),
    fakeIssue(480, 'Dark mode', assignees: ['me'], labels: ['enhancement']),
  ];
  Map<int, List<GithubIssue>> milestoneIssues = {
    3: [
      fakeIssue(470, 'Ship it'),
      fakeIssue(460, 'Done thing', state: GithubIssueState.closed),
    ],
  };
  bool truncated = false;
  List<GithubIssue> found = [fakeIssue(300, 'Old login bug')];

  /// What [findIssue] finds by number.
  Map<int, GithubIssue> byNumber = {};

  /// What [fetchIssue] returns, with comments.
  GithubIssue? detail;
  String? login = 'me';

  /// Numbers [setState] refuses, with the message.
  Map<int, String> refuse = {};

  /// Whether [addAssignee] leaves the user out, as GitHub does without
  /// write access.
  bool ignoreAssignee = false;

  final fetchedMilestones = <int?>[];
  final searched = <String>[];
  final stateChanges = <int, GithubIssueState>{};
  final assigned = <int, String>{};
  int detailFetches = 0;

  @override
  Future<List<GithubMilestone>> fetchMilestones(GithubConfig config) async =>
      milestones;

  @override
  Future<GithubIssueList> fetchIssues(
    GithubConfig config, {
    int? milestone,
  }) async {
    fetchedMilestones.add(milestone);
    return (
      issues: milestone == null
          ? openIssues
          : (milestoneIssues[milestone] ?? const <GithubIssue>[]),
      truncated: truncated,
    );
  }

  @override
  Future<List<GithubIssue>> searchIssues(
    GithubConfig config,
    String query, {
    required int limit,
  }) async {
    searched.add(query);
    return found;
  }

  @override
  Future<GithubIssue?> findIssue(GithubConfig config, int number) async =>
      byNumber[number];

  @override
  Future<GithubIssue> fetchIssue(GithubConfig config, int number) async {
    detailFetches++;
    return detail ?? openIssues.firstWhere((i) => i.number == number);
  }

  @override
  Future<void> setState(
    GithubConfig config,
    int number,
    GithubIssueState state,
  ) async {
    final reason = refuse[number];
    if (reason != null) throw Exception(reason);
    stateChanges[number] = state;
  }

  @override
  Future<List<String>> addAssignee(
    GithubConfig config,
    int number,
    String login,
  ) async {
    assigned[number] = login;
    return ignoreAssignee ? const [] : [login];
  }

  @override
  Future<String?> fetchMyLogin(GithubConfig config) async => login;
}
