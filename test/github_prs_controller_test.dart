import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/features/github_prs/data/github_api_service.dart';
import 'package:tree_launcher/features/github_prs/domain/github_config.dart';
import 'package:tree_launcher/features/github_prs/domain/pull_request.dart';
import 'package:tree_launcher/features/github_prs/presentation/controllers/github_prs_controller.dart';
import 'package:tree_launcher/features/workspace/domain/repo_config.dart';

/// Records which config each PR fetch used; no PRs.
class _FakePrService extends GithubApiService {
  final fetched = <GithubConfig>[];

  @override
  Future<List<GithubPullRequest>> fetchOpenPullRequests(
    GithubConfig config,
  ) async {
    fetched.add(config);
    return const [];
  }

  @override
  Future<String?> fetchAuthenticatedUserLogin(GithubConfig config) async =>
      'me';
}

/// A fresh instance each call, like the controller gets after a config save.
RepoConfig _repo({
  String owner = 'acme',
  String repo = 'app',
  String token = 'ghp_a',
  int interval = 5,
  bool issuesEnabled = false,
}) => RepoConfig(
  name: 'app',
  path: '/repos/app',
  githubConfig: GithubConfig(
    owner: owner,
    repo: repo,
    token: token,
    prRefreshIntervalMinutes: interval,
    issuesEnabled: issuesEnabled,
  ),
);

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late _FakePrService service;
  late GithubPrsController controller;

  setUp(() {
    service = _FakePrService();
    controller = GithubPrsController(service: service);
  });

  tearDown(() => controller.dispose());

  Future<void> sync(RepoConfig repo) async {
    controller.syncToRepo(repo);
    await _settle();
  }

  test('reloads when the selected repo\'s GitHub config changes', () async {
    await sync(_repo());
    await sync(_repo());
    expect(service.fetched, hasLength(1));

    await sync(_repo(token: 'ghp_b'));
    expect(service.fetched.last.token, 'ghp_b');

    await sync(_repo(token: 'ghp_b', owner: 'other'));
    expect(service.fetched.last.owner, 'other');

    await sync(_repo(token: 'ghp_b', owner: 'other', repo: 'web'));
    expect(service.fetched.last.repo, 'web');

    await sync(
      _repo(token: 'ghp_b', owner: 'other', repo: 'web', interval: 15),
    );
    expect(service.fetched.last.prRefreshIntervalMinutes, 15);
    expect(service.fetched, hasLength(5));
  });

  test('ignores changes the PR list does not use', () async {
    await sync(_repo());
    await sync(_repo(issuesEnabled: true));

    expect(service.fetched, hasLength(1));
  });

  test('clears when the token is removed', () async {
    await sync(_repo());
    expect(controller.lastRefreshed, isNotNull);

    await sync(_repo(token: ''));

    expect(controller.lastRefreshed, isNull);
    expect(service.fetched, hasLength(1));
  });
}
