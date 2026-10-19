import 'package:tree_launcher/features/github_prs/data/github_http.dart';
import 'package:tree_launcher/features/github_prs/domain/github_config.dart';
import 'package:tree_launcher/features/github_prs/domain/pull_request.dart';

class GithubApiService {
  Future<List<GithubPullRequest>> fetchOpenPullRequests(
    GithubConfig config,
  ) async {
    final uri = Uri.https(
      'api.github.com',
      '/repos/${config.owner}/${config.repo}/pulls',
      {
        'state': 'open',
        'sort': 'created',
        'direction': 'desc',
        'per_page': '100',
      },
    );
    final response = await githubRequest(config, 'GET', uri);
    final jsonList = response.json as List<dynamic>;
    return jsonList
        .map((e) => GithubPullRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Returns the login of the user the token authenticates as, or null if the
  /// call fails. Never throws so it can't block PR loading.
  Future<String?> fetchAuthenticatedUserLogin(GithubConfig config) =>
      githubLoginFor(config);
}
