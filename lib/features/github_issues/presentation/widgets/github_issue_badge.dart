import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:tree_launcher/features/github_issues/presentation/controllers/github_issues_controller.dart';
import 'package:tree_launcher/features/github_issues/presentation/widgets/github_issue_dialog.dart';
import 'package:tree_launcher/features/github_issues/presentation/widgets/github_issue_styles.dart';
import 'package:tree_launcher/features/github_prs/domain/github_config.dart';
import 'package:tree_launcher/core/platform/open_external.dart';

/// `#123` for the GitHub issue a worktree was made for. Opens the issue
/// dialog, or github.com while ⌘ is held.
class GithubIssueBadge extends StatelessWidget {
  final GithubConfig config;
  final int number;

  const GithubIssueBadge({
    super.key,
    required this.config,
    required this.number,
  });

  @override
  Widget build(BuildContext context) {
    return GithubIssueNumberBadge(
      number: number,
      onTap: () {
        if (HardwareKeyboard.instance.isMetaPressed) {
          openExternal(
            'https://github.com/${config.owner}/${config.repo}/issues/$number',
          );
          return;
        }
        // Read before opening: this badge may be gone when the list changes.
        final issues = Provider.of<GithubIssuesController?>(
          context,
          listen: false,
        );
        GithubIssueDialog.show(
          context,
          config: config,
          number: number,
          service: issues?.service,
          onIssueChanged: issues == null ? null : () => issues.refresh(),
        );
      },
    );
  }
}
