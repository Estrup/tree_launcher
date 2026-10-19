import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/features/agents/domain/agent_kind.dart';
import 'package:tree_launcher/features/agents/domain/claude_prompt.dart';
import 'package:tree_launcher/features/github_prs/domain/github_config.dart';
import 'package:tree_launcher/features/workspace/domain/repo_config.dart';

void main() {
  group('RepoConfig kickoffPrompts', () {
    test('survives a toJson/fromJson round-trip', () {
      final repo = RepoConfig(
        name: 'demo',
        path: '/repos/demo',
        kickoffPrompts: {
          '/repos/demo/feat-x':
              '/repos/demo/feat-x/.tree-launcher/kickoff-prompt.md',
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
      expect(
        repo.copyWith(name: 'renamed').kickoffPrompts,
        repo.kickoffPrompts,
      );

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

  group('RepoConfig agents', () {
    test('keeps a prompt\'s agent kind and the agent working directory', () {
      final repo = RepoConfig(
        name: 'demo',
        path: '/repos/demo',
        claudePrompts: [
          ClaudePrompt(
            name: 'Verify',
            prompt: 'Verify {issue}',
            kind: AgentKind.verify,
          ),
          ClaudePrompt(name: 'Plain', prompt: 'Hi'),
        ],
        agentWorkingDirectory: '/repos/develop',
      );

      final json = repo.toJson();
      expect(json['copilotPrompts'], [
        {'name': 'Verify', 'prompt': 'Verify {issue}', 'kind': 'verify'},
        {'name': 'Plain', 'prompt': 'Hi'},
      ]);
      final restored = RepoConfig.fromJson(json);
      expect(restored.claudePrompts.first.kind, AgentKind.verify);
      expect(restored.claudePrompts.last.kind, isNull);
      expect(restored.agentWorkingDirectory, '/repos/develop');
      expect(
        restored.claudePrompts.first.copyWith(clearKind: true).kind,
        isNull,
      );
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

  group('RepoConfig Jira settings', () {
    test('round-trip through JSON and are omitted when unset', () {
      final repo = RepoConfig(
        name: 'demo',
        path: '/repos/demo',
        jiraProjectKey: 'AU2',
        jiraFixVersionId: '29501',
      );
      final restored = RepoConfig.fromJson(repo.toJson());
      expect(restored.jiraProjectKey, 'AU2');
      expect(restored.jiraFixVersionId, '29501');

      final bare = RepoConfig(name: 'demo', path: '/repos/demo').toJson();
      expect(bare.containsKey('jiraProjectKey'), isFalse);
      expect(bare.containsKey('jiraFixVersionId'), isFalse);
    });

    test('copyWith keeps them unless cleared', () {
      final repo = RepoConfig(
        name: 'demo',
        path: '/repos/demo',
        jiraProjectKey: 'AU2',
        jiraFixVersionId: '29501',
      );
      expect(repo.copyWith(name: 'x').jiraProjectKey, 'AU2');
      final cleared = repo.copyWith(
        clearJiraProjectKey: true,
        clearJiraFixVersionId: true,
      );
      expect(cleared.jiraProjectKey, isNull);
      expect(cleared.jiraFixVersionId, isNull);
    });
  });

  group('RepoConfig GitHub issues', () {
    test('round-trip the Issues tab settings and issue links', () {
      final repo = RepoConfig(
        name: 'demo',
        path: '/repos/demo',
        githubConfig: GithubConfig(
          owner: 'acme',
          repo: 'app',
          token: 't',
          issuesEnabled: true,
        ),
        githubMilestoneNumber: 3,
        githubIssues: const {'/w/login': 482},
      );
      final restored = RepoConfig.fromJson(repo.toJson());
      expect(restored.githubConfig!.issuesEnabled, isTrue);
      expect(restored.githubConfig!.showsIssues, isTrue);
      expect(restored.githubMilestoneNumber, 3);
      expect(restored.githubIssues, {'/w/login': 482});

      final bare = RepoConfig.fromJson(
        RepoConfig(
          name: 'demo',
          path: '/repos/demo',
          githubConfig: GithubConfig(owner: 'acme', repo: 'app', token: 't'),
        ).toJson(),
      );
      expect(bare.githubConfig!.showsIssues, isFalse);
      expect(bare.githubMilestoneNumber, isNull);
      expect(bare.githubIssues, isEmpty);
    });

    test('copyWith keeps the milestone unless cleared', () {
      final repo = RepoConfig(
        name: 'demo',
        path: '/repos/demo',
        githubMilestoneNumber: 3,
      );
      expect(repo.copyWith(name: 'x').githubMilestoneNumber, 3);
      expect(
        repo.copyWith(clearGithubMilestoneNumber: true).githubMilestoneNumber,
        isNull,
      );
    });
  });
}
