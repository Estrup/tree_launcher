import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/settings/domain/app_settings.dart';
import 'package:tree_launcher/features/workspace/domain/worktree.dart';
import 'package:tree_launcher/providers/repo_provider.dart';
import 'package:tree_launcher/providers/settings_provider.dart';
import 'worktree_card.dart';
import 'worktree_table.dart';

class WorktreeGrid extends StatelessWidget {
  const WorktreeGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final repoProvider = context.watch<RepoProvider>();

    if (repoProvider.selectedRepo == null) {
      return _EmptyState(
        icon: Icons.folder_open_rounded,
        title: 'No repository selected',
        subtitle: 'Add a repository to get started',
      );
    }

    if (repoProvider.loading) {
      return Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.accent,
          ),
        ),
      );
    }

    if (repoProvider.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: AppColors.error,
                size: 24,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load worktrees',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 320,
              child: Text(
                repoProvider.error!,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  fontFamily: 'monospace',
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            _RetryButton(onPressed: () => repoProvider.refreshWorktrees()),
          ],
        ),
      );
    }

    if (repoProvider.worktrees.isEmpty) {
      return _EmptyState(
        icon: Icons.account_tree_outlined,
        title: 'No worktrees found',
        subtitle: 'git worktree add <path> <branch>',
        isCode: true,
      );
    }

    final viewMode = context
        .watch<SettingsProvider>()
        .settings
        .worktreeViewMode;

    return viewMode == WorktreeViewMode.list
        ? WorktreeTable(worktrees: repoProvider.worktrees)
        : _WorktreeTileGrid(worktrees: repoProvider.worktrees);
  }
}

class _WorktreeTileGrid extends StatelessWidget {
  final List<Worktree> worktrees;

  const _WorktreeTileGrid({required this.worktrees});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const minTileWidth = 348.0;
        const spacing = 12.0;
        const horizontalPadding = 20.0;
        // Fit as many columns as possible while keeping each tile >= 348px wide.
        final available = constraints.maxWidth - horizontalPadding * 2;
        final crossAxisCount =
            ((available + spacing) / (minTileWidth + spacing)).floor().clamp(
              1,
              4,
            );
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisExtent: 170,
            crossAxisSpacing: spacing,
            mainAxisSpacing: 12,
          ),
          itemCount: worktrees.length,
          itemBuilder: (context, index) {
            return WorktreeCard(worktree: worktrees[index]);
          },
        );
      },
    );
  }
}

/// Grid/List segmented toggle for the Worktrees view. Placed in the tab row by
/// the home screen; reads/writes [SettingsController.updateWorktreeViewMode].
class WorktreeViewModeToggle extends StatelessWidget {
  const WorktreeViewModeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final mode = context.watch<SettingsProvider>().settings.worktreeViewMode;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface0,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ViewModeSegment(
            icon: Icons.grid_view_rounded,
            tooltip: 'Grid view',
            selected: mode == WorktreeViewMode.grid,
            onTap: () => context
                .read<SettingsProvider>()
                .updateWorktreeViewMode(WorktreeViewMode.grid),
          ),
          const SizedBox(width: 2),
          _ViewModeSegment(
            icon: Icons.view_list_rounded,
            tooltip: 'List view',
            selected: mode == WorktreeViewMode.list,
            onTap: () => context
                .read<SettingsProvider>()
                .updateWorktreeViewMode(WorktreeViewMode.list),
          ),
        ],
      ),
    );
  }
}

class _ViewModeSegment extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  const _ViewModeSegment({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? AppColors.surface2 : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              size: 16,
              color: selected ? AppColors.textPrimary : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isCode;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isCode = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.surface1,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Icon(icon, size: 24, color: AppColors.textMuted),
          ),
          const SizedBox(height: 0),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          if (isCode)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface1,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: AppColors.textMuted,
                ),
              ),
            )
          else
            Text(
              subtitle,
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
        ],
      ),
    );
  }
}

class _RetryButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _RetryButton({required this.onPressed});

  @override
  State<_RetryButton> createState() => _RetryButtonState();
}

class _RetryButtonState extends State<_RetryButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.surface2 : AppColors.surface1,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.refresh_rounded,
                size: 14,
                color: _hovered ? AppColors.textPrimary : AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                'Retry',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _hovered ? AppColors.textPrimary : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
