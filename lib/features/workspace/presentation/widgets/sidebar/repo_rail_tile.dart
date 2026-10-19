import 'package:flutter/material.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/workspace/domain/repo_config.dart';

class RepoRailTile extends StatefulWidget {
  final RepoConfig repo;
  final bool isSelected;
  final VoidCallback onTap;
  final void Function(Offset position) onContextMenu;

  const RepoRailTile({
    super.key,
    required this.repo,
    required this.isSelected,
    required this.onTap,
    required this.onContextMenu,
  });

  @override
  State<RepoRailTile> createState() => _RepoRailTileState();
}

class _RepoRailTileState extends State<RepoRailTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final letter = widget.repo.name.isNotEmpty
        ? widget.repo.name[0].toUpperCase()
        : '?';

    return Tooltip(
      message: widget.repo.name,
      waitDuration: const Duration(milliseconds: 300),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          onSecondaryTapDown: (d) => widget.onContextMenu(d.globalPosition),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            margin: const EdgeInsets.symmetric(vertical: 3),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? AppColors.accentMuted
                  : _hovered
                  ? AppColors.surface1
                  : AppColors.surface0,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.isSelected
                    ? AppColors.accent
                    : AppColors.border,
                width: widget.isSelected ? 1.5 : 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              letter,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: widget.isSelected
                    ? AppColors.accent
                    : _hovered
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- Collapsed rail icon button ---
