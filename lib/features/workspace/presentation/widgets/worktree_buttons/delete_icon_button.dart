import 'package:flutter/material.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';

class DeleteIconButton extends StatefulWidget {
  final VoidCallback onPressed;
  const DeleteIconButton({super.key, required this.onPressed});

  @override
  State<DeleteIconButton> createState() => _DeleteIconButtonState();
}

class _DeleteIconButtonState extends State<DeleteIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Tooltip(
          message: 'Delete worktree',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: _hovered
                  ? AppColors.error.withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.close_rounded,
              size: 14,
              color: _hovered ? AppColors.error : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Worktree options menu (Jira / copy path / hide / snooze / delete)
// ---------------------------------------------------------------------------
