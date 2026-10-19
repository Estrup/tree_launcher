import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/workspace/domain/worktree.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:tree_launcher/core/design_system/app_snackbar.dart';
import 'package:tree_launcher/core/errors/user_message.dart';

/// Fetches and fast-forwards a worktree's current branch to its upstream.
/// Shows a spinner while running and reports the outcome (or why the pull
/// wasn't possible) in a snackbar. Disabled for detached-HEAD worktrees.
class PullButton extends StatefulWidget {
  final Worktree worktree;
  final bool compact;

  const PullButton({super.key, required this.worktree, this.compact = false});

  @override
  State<PullButton> createState() => _PullButtonState();
}

class _PullButtonState extends State<PullButton> {
  bool _hovered = false;
  bool _busy = false;

  bool get _detached => widget.worktree.branch.startsWith('detached');

  Future<void> _pull() async {
    if (_busy || _detached) return;
    final repoProvider = context.read<WorkspaceController>();
    setState(() => _busy = true);
    try {
      final result = await repoProvider.pullWorktree(widget.worktree);
      showAppSnackBar(
        result.updated
            ? 'Pulled ${result.commits} '
                  '${result.commits == 1 ? 'commit' : 'commits'} into '
                  '${result.branch}'
            : '${result.branch} is already up to date',
        duration: const Duration(milliseconds: 1800),
      );
    } catch (e) {
      showAppSnackBar(userMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.compact ? 28.0 : 36.0;
    final glyphSize = widget.compact ? 14.0 : 16.0;
    final enabled = !_detached && !_busy;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: _pull,
        child: Tooltip(
          message: _detached ? 'No branch checked out' : 'Pull latest',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: _hovered && enabled
                  ? AppColors.surface2
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: _busy
                  ? SizedBox(
                      width: glyphSize,
                      height: glyphSize,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textMuted,
                      ),
                    )
                  : Icon(
                      Icons.sync_rounded,
                      size: glyphSize,
                      color: _detached
                          ? AppColors.textMuted.withValues(alpha: 0.4)
                          : (_hovered
                                ? AppColors.textPrimary
                                : AppColors.textMuted),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Generic action button (claude, vscode-no-configs)
// ---------------------------------------------------------------------------
