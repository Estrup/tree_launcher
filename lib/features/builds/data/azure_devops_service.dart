import 'dart:convert';
import 'dart:io';

import 'package:tree_launcher/features/builds/domain/azure_devops_config.dart';
import 'package:tree_launcher/features/builds/domain/build_definition.dart';
import 'package:tree_launcher/features/builds/domain/build_result.dart';

class AzureDevopsService {
  String _authHeader(String pat) {
    final bytes = utf8.encode(':$pat');
    return 'Basic ${base64Encode(bytes)}';
  }

  Uri _apiUri(AzureDevopsConfig config, String path,
      [Map<String, String>? queryParameters]) {
    final base = config.serverUrl.endsWith('/')
        ? config.serverUrl.substring(0, config.serverUrl.length - 1)
        : config.serverUrl;
    final fullPath = '${config.project}/_apis/$path';
    final parsed = Uri.parse('$base/$fullPath');
    return parsed.replace(queryParameters: {
      ...?parsed.queryParameters.isNotEmpty ? parsed.queryParameters : null,
      'api-version': '7.1',
      ...?queryParameters,
    });
  }

  Future<String> _get(AzureDevopsConfig config, String path,
      [Map<String, String>? queryParameters]) async {
    final client = HttpClient();
    try {
      final uri = _apiUri(config, path, queryParameters);
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.authorizationHeader, _authHeader(config.pat));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');

      final response = await request.close();
      final body = await utf8.decodeStream(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(_extractError(body, response.statusCode));
      }
      return body;
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _post(
    AzureDevopsConfig config,
    String path,
    Map<String, dynamic> body,
  ) async {
    final client = HttpClient();
    try {
      final uri = _apiUri(config, path);
      final request = await client.postUrl(uri);
      request.headers.set(HttpHeaders.authorizationHeader, _authHeader(config.pat));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));

      final response = await request.close();
      final responseBody = await utf8.decodeStream(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(_extractError(responseBody, response.statusCode));
      }
      return responseBody;
    } finally {
      client.close(force: true);
    }
  }

  String _extractError(String body, int statusCode) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final message = decoded['message'] as String?;
      if (message != null && message.trim().isNotEmpty) {
        return message.trim();
      }
    } catch (_) {}
    return body.trim().isEmpty
        ? 'Azure DevOps request failed (HTTP $statusCode)'
        : body.trim();
  }

  /// Fetches all build pipeline definitions for the project.
  Future<List<BuildDefinition>> fetchDefinitions(
    AzureDevopsConfig config,
  ) async {
    final body = await _get(config, 'build/definitions');
    final json = jsonDecode(body) as Map<String, dynamic>;
    final items = json['value'] as List<dynamic>? ?? [];
    return items
        .map((e) => BuildDefinition.fromApiJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetches the latest build for a single pipeline definition.
  Future<BuildResult?> fetchLatestBuild(
    AzureDevopsConfig config,
    int definitionId,
  ) async {
    final body = await _get(config, 'build/builds', {
      'definitions': definitionId.toString(),
      '\$top': '1',
    });
    final json = jsonDecode(body) as Map<String, dynamic>;
    final items = json['value'] as List<dynamic>? ?? [];
    if (items.isEmpty) return null;
    return BuildResult.fromApiJson(items.first as Map<String, dynamic>);
  }

  /// Fetches the latest build for each of the given definition IDs.
  Future<Map<int, BuildResult?>> fetchLatestBuilds(
    AzureDevopsConfig config,
    List<int> definitionIds,
  ) async {
    final results = <int, BuildResult?>{};
    // Batch request: Azure DevOps supports comma-separated definition IDs.
    if (definitionIds.isEmpty) return results;

    final body = await _get(config, 'build/builds', {
      'definitions': definitionIds.join(','),
      'maxBuildsPerDefinition': '1',
    });
    final json = jsonDecode(body) as Map<String, dynamic>;
    final items = json['value'] as List<dynamic>? ?? [];

    // Initialize all as null.
    for (final id in definitionIds) {
      results[id] = null;
    }

    for (final item in items) {
      final build = BuildResult.fromApiJson(item as Map<String, dynamic>);
      results[build.definitionId] = build;
    }

    return results;
  }

  /// Queues a new build for the given pipeline and branch.
  Future<BuildResult> queueBuild(
    AzureDevopsConfig config,
    int definitionId,
    String branch,
  ) async {
    final sourceBranch =
        branch.startsWith('refs/') ? branch : 'refs/heads/$branch';
    final body = await _post(config, 'build/builds', {
      'definition': {'id': definitionId},
      'sourceBranch': sourceBranch,
    });
    final json = jsonDecode(body) as Map<String, dynamic>;
    return BuildResult.fromApiJson(json);
  }

  /// Fetches the commit message for a build via its changes endpoint.
  /// Returns the first change's commit message, or null if none found.
  Future<String?> fetchBuildCommitMessage(
    AzureDevopsConfig config,
    int buildId,
  ) async {
    try {
      final body = await _get(config, 'build/builds/$buildId/changes', {
        '\$top': '1',
      });
      final json = jsonDecode(body) as Map<String, dynamic>;
      final items = json['value'] as List<dynamic>? ?? [];
      if (items.isEmpty) return null;
      final first = items.first as Map<String, dynamic>;
      final message = first['message'] as String?;
      return message?.trim();
    } catch (_) {
      return null;
    }
  }

  /// Fetches branch names from all git repositories in the project.
  Future<List<String>> fetchBranches(AzureDevopsConfig config) async {
    // First, get repositories in the project.
    final reposBody = await _get(config, 'git/repositories');
    final reposJson = jsonDecode(reposBody) as Map<String, dynamic>;
    final repos = reposJson['value'] as List<dynamic>? ?? [];

    final branches = <String>{};
    for (final repo in repos) {
      final repoId = repo['id'] as String?;
      if (repoId == null) continue;
      try {
        final refsBody = await _get(
          config,
          'git/repositories/$repoId/refs',
          {'filter': 'heads/'},
        );
        final refsJson = jsonDecode(refsBody) as Map<String, dynamic>;
        final refs = refsJson['value'] as List<dynamic>? ?? [];
        for (final ref in refs) {
          final name = ref['name'] as String? ?? '';
          if (name.startsWith('refs/heads/')) {
            branches.add(name.replaceFirst('refs/heads/', ''));
          }
        }
      } catch (_) {
        // Skip repos where we cannot list refs.
      }
    }

    final sorted = branches.toList()..sort();
    return sorted;
  }
}
