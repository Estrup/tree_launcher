import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/models/claude_prompt.dart';
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

  group('RepoConfig claudePrompts', () {
    test('loads prompts saved under the legacy copilotPrompts key', () {
      final restored = RepoConfig.fromJson({
        'name': 'demo',
        'path': '/repos/demo',
        'copilotPrompts': [
          {'name': 'Review', 'prompt': 'Review {issue}'},
        ],
      });

      expect(restored.claudePrompts, hasLength(1));
      expect(restored.claudePrompts.single.name, 'Review');
      expect(restored.claudePrompts.single.prompt, 'Review {issue}');
    });

    test('round-trips under the legacy key so older builds still see them', () {
      final repo = RepoConfig(
        name: 'demo',
        path: '/repos/demo',
        claudePrompts: [ClaudePrompt(name: 'Plan', prompt: 'Plan {worktree}')],
      );

      final json = repo.toJson();
      expect(json['copilotPrompts'], [
        {'name': 'Plan', 'prompt': 'Plan {worktree}'},
      ]);
      expect(RepoConfig.fromJson(json).claudePrompts.single.name, 'Plan');
    });
  });

  group('RepoConfig removed features', () {
    test('ignores legacy links, builds, Copilot sessions and run defaults', () {
      final restored = RepoConfig.fromJson({
        'name': 'demo',
        'path': '/repos/demo',
        'customLinks': [
          {'name': 'Docs', 'url': 'https://example.com'},
        ],
        'defaultRunCommands': ['run auth'],
        'copilotSessions': [
          {
            'id': '1',
            'name': 's',
            'repoPath': '/repos/demo',
            'workingDirectory': '/repos/demo',
            'createdAt': '2026-01-01T00:00:00.000',
          },
        ],
        'azureDevopsConfig': {'orgUrl': 'https://dev.azure.com/x'},
        'lastAzureDevopsBranch': 'main',
      });

      final json = restored.toJson();
      for (final key in [
        'customLinks',
        'defaultRunCommands',
        'copilotSessions',
        'azureDevopsConfig',
        'lastAzureDevopsBranch',
      ]) {
        expect(json.containsKey(key), isFalse, reason: key);
      }
    });
  });
}
