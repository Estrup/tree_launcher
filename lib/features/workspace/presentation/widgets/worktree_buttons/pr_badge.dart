import 'dart:io';
import 'package:flutter/material.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/worktree_buttons/jira_badge.dart';

/// Clickable pill linking to a GitHub pull request. Mirrors [JiraBadge]'s
/// styling and launch mechanism, showing `#<number>` and opening [htmlUrl].
class PrBadge extends StatefulWidget {
  final int number;
  final String htmlUrl;
  final bool compact;

  const PrBadge({
    super.key,
    required this.number,
    required this.htmlUrl,
    this.compact = false,
  });

  @override
  State<PrBadge> createState() => _PrBadgeState();
}

class _PrBadgeState extends State<PrBadge> {
  static const Color _prColor = Color(0xFF8957E5);
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final iconSize = widget.compact ? 11.0 : 12.0;
    final fontSize = widget.compact ? 11.0 : 12.0;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => Process.run('open', [widget.htmlUrl]),
        child: Tooltip(
          message: 'Open PR #${widget.number}',
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: widget.compact ? 8 : 10,
              vertical: widget.compact ? 3 : 5,
            ),
            decoration: BoxDecoration(
              color: _prColor.withValues(alpha: _hovered ? 0.18 : 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _prColor.withValues(alpha: _hovered ? 0.4 : 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.merge_type_rounded, size: iconSize, color: _prColor),
                const SizedBox(width: 6),
                Text(
                  '#${widget.number}',
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                    color: _prColor,
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
