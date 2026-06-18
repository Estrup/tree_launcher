import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/models/repo_config.dart';

void main() {
  group('RepoConfig kickoffPrompts', () {
    test('survives a toJson/fromJson round-trip', () {
      final repo = RepoConfig(
        name: 'demo',
        path: '/repos/demo',
        kickoffPrompts: {
          '/repos/demo/feat-x': '/repos/demo/feat-x/.tree-launcher/kickoff-prompt.md',
        },
      );

      final restored = RepoConfig.fromJson(repo.toJson());

      expect(restored.kickoffPrompts, repo.kickoffPrompts);
    });

    test('defaults to empty when absent from JSON', () {
      final restored = RepoConfig.fromJson({
        'name': 'demo',
        'path': '/repos/demo',
      });

      expect(restored.kickoffPrompts, isEmpty);
    });

    test('copyWith carries it forward and replaces it', () {
      final repo = RepoConfig(
        name: 'demo',
        path: '/repos/demo',
        kickoffPrompts: const {'/a': '/a/file.md'},
      );

      // Unrelated copyWith keeps the map.
      expect(repo.copyWith(name: 'renamed').kickoffPrompts, repo.kickoffPrompts);

      // Explicit copyWith replaces it.
      final updated = repo.copyWith(kickoffPrompts: const {'/b': '/b/file.md'});
      expect(updated.kickoffPrompts, const {'/b': '/b/file.md'});
    });
  });
}
