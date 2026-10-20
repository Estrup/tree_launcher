import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/features/jira/presentation/controllers/jira_issues_controller.dart';
import 'package:tree_launcher/features/jira/presentation/controllers/jira_titles_controller.dart';
import 'package:tree_launcher/features/jira/presentation/widgets/jira_issue_dialog.dart';

class JiraBadge extends StatefulWidget {
  final String issueKey;
  final bool compact;

  /// A fixed height, to line up with buttons beside it; null fits the text.
  final double? height;

  const JiraBadge({
    super.key,
    required this.issueKey,
    this.compact = false,
    this.height,
  });

  @override
  State<JiraBadge> createState() => _JiraBadgeState();
}

class _JiraBadgeState extends State<JiraBadge> {
  static const Color _jiraColor = Color(0xFF2684FF);
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _requestTitle();
  }

  @override
  void didUpdateWidget(JiraBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.issueKey != oldWidget.issueKey) _requestTitle();
  }

  /// Asks for the issue's title for the tooltip; known keys are skipped by
  /// the controller. Without one (e.g. in tests) the tooltip has no title.
  void _requestTitle() {
    Provider.of<JiraTitlesController?>(
      context,
      listen: false,
    )?.ensureTitles([widget.issueKey]);
  }

  @override
  Widget build(BuildContext context) {
    final iconSize = widget.compact ? 11.0 : 12.0;
    final fontSize = widget.compact ? 11.0 : 12.0;
    final title = context.watch<JiraTitlesController?>()?.titleFor(
      widget.issueKey,
    );
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () {
          // Read before opening: this badge may be gone when the issue
          // changes, e.g. when its row is filtered out.
          final issues = Provider.of<JiraIssuesController?>(
            context,
            listen: false,
          );
          JiraIssueDialog.show(
            context,
            issueKey: widget.issueKey,
            onIssueChanged: issues == null ? null : () => issues.refresh(),
          );
        },
        child: Tooltip(
          message: title == null
              ? 'View ${widget.issueKey}'
              : '${widget.issueKey}: $title',
          child: Container(
            height: widget.height,
            padding: EdgeInsets.symmetric(
              horizontal: widget.compact ? 8 : 10,
              vertical: widget.compact ? 3 : 5,
            ),
            decoration: BoxDecoration(
              color: _jiraColor.withValues(alpha: _hovered ? 0.18 : 0.1),
              borderRadius: BorderRadius.circular(
                widget.height == null ? 6 : 7,
              ),
              border: Border.all(
                color: _jiraColor.withValues(alpha: _hovered ? 0.4 : 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.open_in_new_rounded,
                  size: iconSize,
                  color: _jiraColor,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.issueKey,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                    color: _jiraColor,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// GitHub PR badge (link)
// ---------------------------------------------------------------------------
