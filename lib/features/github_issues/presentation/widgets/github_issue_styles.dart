import 'package:flutter/material.dart';

import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/github_issues/domain/github_issue.dart';

/// GitHub's purple for closed (completed) issues; mid-tone, so it reads on
/// light and dark palettes.
const _closedPurple = Color(0xFF8957E5);

/// Colour for an issue [state], as GitHub colours them.
Color githubIssueStateColor(GithubIssueState state) => switch (state) {
  GithubIssueState.open => AppColors.success,
  GithubIssueState.closed => _closedPurple,
  GithubIssueState.notPlanned => AppColors.textMuted,
};

/// Icon for an issue [state], after GitHub's own glyphs.
IconData githubIssueStateIcon(GithubIssueState state) => switch (state) {
  GithubIssueState.open => Icons.adjust_rounded,
  GithubIssueState.closed => Icons.check_circle_outline_rounded,
  GithubIssueState.notPlanned => Icons.block_rounded,
};

/// What moving an issue to [state] is called in the state menu.
String githubStateActionLabel(GithubIssueState state) => switch (state) {
  GithubIssueState.open => 'Reopen',
  GithubIssueState.closed => 'Close as completed',
  GithubIssueState.notPlanned => 'Close as not planned',
};

/// Shows [targets] in a menu below [anchorContext]'s widget and returns the
/// state picked. For several issues, [counts] says how many of
/// [issueCount] each target applies to (e.g. "3 of 5").
Future<GithubIssueState?> showGithubStateMenu(
  BuildContext anchorContext,
  List<GithubIssueState> targets, {
  Map<GithubIssueState, int> counts = const {},
  int issueCount = 1,
}) {
  final anchor = anchorContext.findRenderObject() as RenderBox;
  final overlay =
      Overlay.of(anchorContext).context.findRenderObject() as RenderBox;
  final bottomLeft = anchor.localToGlobal(
    Offset(0, anchor.size.height + 4),
    ancestor: overlay,
  );
  return showMenu<GithubIssueState>(
    context: anchorContext,
    position: RelativeRect.fromRect(
      bottomLeft & Size(anchor.size.width, 0),
      Offset.zero & overlay.size,
    ),
    color: AppColors.surface1,
    constraints: const BoxConstraints(minWidth: 220),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(color: AppColors.border),
    ),
    items: [
      for (final target in targets)
        PopupMenuItem<GithubIssueState>(
          value: target,
          height: 36,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                githubIssueStateIcon(target),
                size: 15,
                color: githubIssueStateColor(target),
              ),
              const SizedBox(width: 10),
              Text(
                githubStateActionLabel(target),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              if (issueCount > 1 &&
                  (counts[target] ?? issueCount) < issueCount) ...[
                const SizedBox(width: 8),
                Text(
                  '${counts[target]} of $issueCount',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ],
          ),
        ),
    ],
  );
}

/// An issue's state, as a pill that opens the state menu when [onTap] is
/// given.
class GithubStatePill extends StatefulWidget {
  final GithubIssueState state;
  final bool busy;
  final VoidCallback? onTap;

  const GithubStatePill({
    super.key,
    required this.state,
    this.busy = false,
    this.onTap,
  });

  @override
  State<GithubStatePill> createState() => _GithubStatePillState();
}

class _GithubStatePillState extends State<GithubStatePill> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = githubIssueStateColor(widget.state);
    final enabled = widget.onTap != null && !widget.busy;
    return Tooltip(
      message: 'Change state',
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: enabled ? widget.onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.fromLTRB(8, 3, 4, 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: _hovered ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: color.withValues(alpha: _hovered ? 0.5 : 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  githubIssueStateIcon(widget.state),
                  size: 13,
                  color: color,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    widget.state.label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                SizedBox(
                  width: 14,
                  height: 14,
                  child: widget.busy
                      ? Padding(
                          padding: const EdgeInsets.all(2),
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: color,
                          ),
                        )
                      : Icon(Icons.expand_more_rounded, size: 14, color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `#123` as a clickable pill, for opening a GitHub issue.
class GithubIssueNumberBadge extends StatefulWidget {
  final int number;
  final VoidCallback onTap;
  final String? tooltip;

  const GithubIssueNumberBadge({
    super.key,
    required this.number,
    required this.onTap,
    this.tooltip,
  });

  @override
  State<GithubIssueNumberBadge> createState() => _GithubIssueNumberBadgeState();
}

class _GithubIssueNumberBadgeState extends State<GithubIssueNumberBadge> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = _hovered ? AppColors.accent : AppColors.textSecondary;
    return Tooltip(
      message: widget.tooltip ?? 'View #${widget.number} (⌘-click: GitHub)',
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: _hovered ? 0.16 : 0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: color.withValues(alpha: _hovered ? 0.4 : 0.2),
              ),
            ),
            child: Text(
              '#${widget.number}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
