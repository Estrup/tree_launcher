import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Keeps docs/agent-api.md in step with the routes the server mounts: every
/// mounted route has a section there, and every section a route.
void main() {
  final mount = RegExp(r"""\.\.(get|post|put|delete)\(\s*'([^']+)'""");
  final section = RegExp(
    r'^### `(GET|POST|PUT|DELETE) (/[^`?\s]*)',
    multiLine: true,
  );

  Set<String> mountedRoutes() => {
    for (final file in [
      File('lib/features/agent_api/data/agent_api_server.dart'),
      ...Directory(
        'lib/features/agent_api/data/routes',
      ).listSync().whereType<File>().where((f) => f.path.endsWith('.dart')),
    ])
      for (final match in mount.allMatches(file.readAsStringSync()))
        '${match.group(1)!.toUpperCase()} ${match.group(2)}',
  };

  Set<String> documentedRoutes() => {
    for (final match in section.allMatches(
      File('docs/agent-api.md').readAsStringSync(),
    ))
      '${match.group(1)} ${match.group(2)}',
  };

  test('finds the mounted routes', () {
    expect(mountedRoutes(), containsAll(['GET /health', 'POST /v1/worktrees']));
  });

  test('every mounted route is documented', () {
    expect(mountedRoutes().difference(documentedRoutes()), isEmpty);
  });

  test('every documented route is mounted', () {
    expect(documentedRoutes().difference(mountedRoutes()), isEmpty);
  });
}
