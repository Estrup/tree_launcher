import 'dart:convert';
import 'dart:io';

import 'package:tree_launcher/features/github_prs/domain/github_config.dart';
import 'package:tree_launcher/features/github_prs/domain/pull_request.dart';

class GithubApiService {
  Future<List<GithubPullRequest>> fetchOpenPullRequests(
    GithubConfig config,
  ) async {
    final client = HttpClient();
    try {
      final uri = Uri.https('api.github.com', '/repos/${config.owner}/${config.repo}/pulls', {
        'state': 'open',
        'sort': 'created',
        'direction': 'desc',
        'per_page': '100',
      });

      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${config.token}');
      request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      request.headers.set('X-GitHub-Api-Version', '2022-11-28');
      request.headers.set(HttpHeaders.userAgentHeader, 'TreeLauncher');

      final response = await request.close();
      final body = await utf8.decodeStream(response);

      if (response.statusCode == 401) {
        throw Exception('GitHub authentication failed. Check your token.');
      }
      if (response.statusCode == 403) {
        throw Exception('GitHub API rate limit exceeded or access denied.');
      }
      if (response.statusCode == 404) {
        throw Exception('Repository not found: ${config.owner}/${config.repo}');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('GitHub API error (${response.statusCode}): $body');
      }

      final jsonList = jsonDecode(body) as List<dynamic>;
      return jsonList
          .map((e) => GithubPullRequest.fromJson(e as Map<String, dynamic>))
          .toList();
    } finally {
      client.close(force: true);
    }
  }
}
