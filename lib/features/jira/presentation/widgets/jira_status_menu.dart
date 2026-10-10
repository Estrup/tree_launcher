import 'package:flutter/material.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/jira/domain/jira_transition.dart';
import 'package:tree_launcher/features/jira/presentation/widgets/jira_styles.dart';

/// Shows the statuses [moves] lead to in a menu below [anchorContext]'s
/// widget, for [issueCount] issues, and returns the one picked.
///
/// For a single issue, a transition named differently from its status shows
/// its name (e.g. "In Progress · Start Progress"). For several, a status not
/// every issue can move to shows how many can (e.g. "Done · 3 of 5").
Future<JiraStatusMove?> showJiraStatusMenu(
  BuildContext anchorContext,
  List<JiraStatusMove> moves, {
  required int issueCount,
}) {
  final anchor = anchorContext.findRenderObject() as RenderBox;
  final overlay =
      Overlay.of(anchorContext).context.findRenderObject() as RenderBox;
  final bottomLeft = anchor.localToGlobal(
    Offset(0, anchor.size.height + 4),
    ancestor: overlay,
  );
  return showMenu<JiraStatusMove>(
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
      for (final move in moves)
        PopupMenuItem<JiraStatusMove>(
          value: move,
          height: 36,
          child: _MoveRow(move: move, issueCount: issueCount),
        ),
    ],
  );
}

class _MoveRow extends StatelessWidget {
  final JiraStatusMove move;
  final int issueCount;

  const _MoveRow({required this.move, required this.issueCount});

  /// What to say after the status, if anything.
  String? get _detail {
    if (issueCount > 1) {
      final count = move.transitions.length;
      return count < issueCount ? '$count of $issueCount' : null;
    }
    final name = move.transitions.values.firstOrNull?.name;
    if (name == null || name.toLowerCase() == move.toStatus.toLowerCase()) {
      return null;
    }
    return name;
  }

  @override
  Widget build(BuildContext context) {
    final color = jiraStatusColor(move.toStatusCategory);
    final detail = _detail;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Text(
          move.toStatus,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        if (detail != null) ...[
          const SizedBox(width: 8),
          Text(
            detail,
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ],
    );
  }
}
