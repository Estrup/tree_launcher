import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/features/github_prs/domain/pull_request.dart';
import 'package:tree_launcher/features/github_prs/presentation/pr_worktree_actions.dart';
import 'package:tree_launcher/models/app_settings.dart';

GithubPullRequest _pr({
  int number = 42,
  String title = 'Fix the thing (AU2-5555)',
  String htmlUrl = 'https://github.com/acme/repo/pull/42',
  String author = 'octocat',
  String headBranch = 'feature/thing',
  String baseBranch = 'main',
}) {
  return GithubPullRequest(
    number: number,
    title: title,
    htmlUrl: htmlUrl,
    createdAt: DateTime(2026, 1, 1),
    author: author,
    headBranch: headBranch,
    baseBranch: baseBranch,
  );
}

void main() {
  group('resolvePrPrompt', () {
    test('substitutes all placeholders from the PR', () {
      final result = resolvePrPrompt(
        'PR #{number} "{title}" {url} {branch}->{base} by {author} [{jira}]',
        _pr(),
      );

      expect(
        result,
        'PR #42 "Fix the thing (AU2-5555)" '
        'https://github.com/acme/repo/pull/42 feature/thing->main by octocat '
        '[AU2-5555]',
      );
    });

    test('replaces {jira} with empty string when the title has no key', () {
      final result = resolvePrPrompt('[{jira}]', _pr(title: 'No key here'));
      expect(result, '[]');
    });
  });

  group('buildClaudePrCommand', () {
    test('includes the configured model and single-quotes the prompt', () {
      final settings = AppSettings(
        prLaunchModel: 'opus',
        prLaunchPrompt: 'Review #{number}',
      );

      final command = buildClaudePrCommand(settings, _pr());

      expect(command, "claude --model 'opus' 'Review #42'");
    });

    test('omits --model when the model is empty', () {
      final settings = AppSettings(
        prLaunchModel: '   ',
        prLaunchPrompt: 'Review #{number}',
      );

      final command = buildClaudePrCommand(settings, _pr());

      expect(command, "claude 'Review #42'");
    });

    test('escapes single quotes in the prompt for the shell', () {
      final settings = AppSettings(
        prLaunchModel: '',
        prLaunchPrompt: "It's a prompt",
      );

      final command = buildClaudePrCommand(settings, _pr());

      // Single quote becomes the close-escape-reopen sequence: '\''
      expect(command, "claude 'It'\\''s a prompt'");
    });
  });
}
