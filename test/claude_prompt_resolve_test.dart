import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/worktree_actions.dart';
import 'package:tree_launcher/models/claude_prompt.dart';

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
}
