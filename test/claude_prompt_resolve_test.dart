import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/features/agents/domain/claude_prompt.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_prompts.dart';

void main() {
  final prompt = ClaudePrompt(
    name: 'Review',
    prompt: 'Review pull request {pr} ({issue}) in {repo}',
  );

  String? resolve({int? prNumber}) => resolveClaudePrompt(
    prompt,
    issue: 'AU2-5928',
    worktreeName: 'au2-wt',
    worktreePath: '/tmp/au2-wt',
    repoName: 'au2office',
    prNumber: prNumber,
  );

  test('fills {pr} with the pull request number', () {
    expect(
      resolve(prNumber: 7073),
      'Review pull request 7073 (AU2-5928) in au2office',
    );
  });

  test('leaves {pr} empty when there is no pull request', () {
    expect(resolve(), 'Review pull request (AU2-5928) in au2office');
  });

  group('{github_issue}', () {
    final ghPrompt = ClaudePrompt(
      name: 'Fix',
      prompt: 'Fix GitHub issue #{github_issue} in {repo}',
    );

    test('is filled with the GitHub issue number', () {
      expect(
        resolveClaudePrompt(
          ghPrompt,
          githubIssue: 42,
          worktreeName: 'wt',
          worktreePath: '/tmp/wt',
          repoName: 'tree_launcher',
        ),
        'Fix GitHub issue #42 in tree_launcher',
      );
    });

    test('is missing without a GitHub issue', () {
      expect(
        missingPlaceholderValue(ghPrompt.prompt, issue: 'AU2-1'),
        'the prompt uses {github_issue}, but there is no GitHub issue',
      );
      expect(missingPlaceholderValue(ghPrompt.prompt, githubIssue: 42), isNull);
    });
  });
}
