import 'dart:convert';
import 'dart:io';

import 'package:tree_launcher/features/github_prs/domain/github_config.dart';

/// A GitHub REST API error, with a [message] fit to show the user.
class GithubApiException implements Exception {
  final int statusCode;
  final String message;

  const GithubApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

/// A successful GitHub REST API response.
class GithubResponse {
  /// The decoded JSON body; null for an empty one.
  final dynamic json;

  /// The next page of a paged list (from the `Link` header), if any.
  final Uri? nextPage;

  const GithubResponse({required this.json, this.nextPage});
}

/// One connection pool for every GitHub request.
final HttpClient _client = HttpClient()
  ..connectionTimeout = const Duration(seconds: 15);

/// Sends a [method] request for [uri] with [config]'s token, and [body] as
/// JSON when given. Throws a [GithubApiException] for an error status, worded
/// for [config]'s repo; [forbiddenHint] is added to a 403 that isn't a rate
/// limit (e.g. which permission the token needs).
Future<GithubResponse> githubRequest(
  GithubConfig config,
  String method,
  Uri uri, {
  Map<String, dynamic>? body,
  String? forbiddenHint,
}) async {
  final request = await _client.openUrl(method, uri);
  request.headers.set(
    HttpHeaders.authorizationHeader,
    'Bearer ${config.token}',
  );
  request.headers.set(
    HttpHeaders.acceptHeader,
    'application/vnd.github+json',
  );
  request.headers.set('X-GitHub-Api-Version', '2022-11-28');
  request.headers.set(HttpHeaders.userAgentHeader, 'TreeLauncher');
  if (body != null) {
    final bytes = utf8.encode(jsonEncode(body));
    request.headers.contentType = ContentType.json;
    request.contentLength = bytes.length;
    request.add(bytes);
  }

  final response = await request.close();
  final text = await utf8.decodeStream(response);
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw GithubApiException(
      response.statusCode,
      githubErrorMessage(
        response.statusCode,
        text,
        repo: '${config.owner}/${config.repo}',
        rateLimitRemaining: response.headers.value('x-ratelimit-remaining'),
        rateLimitReset: response.headers.value('x-ratelimit-reset'),
        forbiddenHint: forbiddenHint,
      ),
    );
  }
  return GithubResponse(
    json: text.trim().isEmpty ? null : jsonDecode(text),
    nextPage: githubNextPage(response.headers.value('link')),
  );
}

/// The message for a GitHub error response with [statusCode] and [body] on
/// [repo] (`owner/name`).
String githubErrorMessage(
  int statusCode,
  String body, {
  required String repo,
  String? rateLimitRemaining,
  String? rateLimitReset,
  String? forbiddenHint,
}) {
  final message = _githubMessage(body);
  final rateLimited =
      (statusCode == 403 || statusCode == 429) &&
      (rateLimitRemaining == '0' ||
          (message?.toLowerCase().contains('rate limit') ?? false));
  if (rateLimited) {
    final reset = int.tryParse(rateLimitReset ?? '');
    if (reset == null) return 'GitHub rate limit reached. Try again later.';
    final at = DateTime.fromMillisecondsSinceEpoch(reset * 1000).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'GitHub rate limit reached. Try again at '
        '${two(at.hour)}:${two(at.minute)}.';
  }
  switch (statusCode) {
    case 401:
      return 'GitHub authentication failed. Check your token.';
    case 403:
      return [
        "The token can't access $repo.",
        ?forbiddenHint,
        if (message != null) '($message)',
      ].join(' ');
    case 404:
      return 'Repository not found: $repo';
    case 410:
      return 'Issues are turned off for $repo.';
    case 422:
      return message ?? 'GitHub rejected the request.';
  }
  return 'GitHub API error ($statusCode): ${message ?? body}';
}

/// GitHub's `message` from an error [body], with the first validation error
/// after it when there is one.
String? _githubMessage(String body) {
  try {
    final json = jsonDecode(body);
    if (json is! Map<String, dynamic>) return null;
    final message = json['message'] as String?;
    final errors = json['errors'];
    final first = errors is List && errors.isNotEmpty ? errors.first : null;
    final detail = first is Map<String, dynamic>
        ? first['message'] as String?
        : null;
    if (message == null) return detail;
    return detail == null ? message : '$message: $detail';
  } catch (_) {
    return null;
  }
}

/// The `rel="next"` URL in a `Link` [header], if any.
Uri? githubNextPage(String? header) {
  if (header == null) return null;
  for (final part in header.split(',')) {
    final match = RegExp(r'<([^>]+)>\s*;\s*rel="next"').firstMatch(part);
    if (match != null) return Uri.tryParse(match.group(1)!);
  }
  return null;
}

/// Lookups of the token's login, by token, so the PRs and issues tabs share
/// one request. A failed lookup is forgotten so the next one retries.
final _logins = <String, Future<String?>>{};

/// The login of the user [config]'s token authenticates as, or null when the
/// lookup fails. Never throws.
Future<String?> githubLoginFor(GithubConfig config) {
  final token = config.token;
  return _logins[token] ??= () async {
    try {
      final response = await githubRequest(
        config,
        'GET',
        Uri.https('api.github.com', '/user'),
      );
      final login = (response.json as Map<String, dynamic>)['login'] as String?;
      if (login == null) _logins.remove(token);
      return login;
    } catch (_) {
      _logins.remove(token);
      return null;
    }
  }();
}
