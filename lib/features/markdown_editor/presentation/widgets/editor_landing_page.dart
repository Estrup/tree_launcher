import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:path/path.dart' as p;

class EditorLandingPage extends StatelessWidget {
  final List<String> recentFiles;
  final VoidCallback onOpenFile;
  final ValueChanged<String> onOpenRecentFile;
  final ValueChanged<String> onRemoveRecentFile;

  const EditorLandingPage({
    super.key,
    required this.recentFiles,
    required this.onOpenFile,
    required this.onOpenRecentFile,
    required this.onRemoveRecentFile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.base,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.edit_note_rounded,
                size: 48,
                color: AppColors.textMuted.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'Markdown Editor',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Open a markdown file to get started',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 24),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: onOpenFile,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.folder_open_rounded,
                          size: 16,
                          color: AppColors.base,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Open File',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.base,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (recentFiles.isNotEmpty) ...[
                const SizedBox(height: 32),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'RECENTLY OPENED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: recentFiles.length,
                    itemBuilder: (context, index) {
                      final path = recentFiles[index];
                      final exists = File(path).existsSync();
                      return _RecentFileItem(
                        path: path,
                        exists: exists,
                        onTap: exists ? () => onOpenRecentFile(path) : null,
                        onRemove: () => onRemoveRecentFile(path),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentFileItem extends StatefulWidget {
  final String path;
  final bool exists;
  final VoidCallback? onTap;
  final VoidCallback onRemove;

  const _RecentFileItem({
    required this.path,
    required this.exists,
    this.onTap,
    required this.onRemove,
  });

  @override
  State<_RecentFileItem> createState() => _RecentFileItemState();
}

class _RecentFileItemState extends State<_RecentFileItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final fileName = p.basename(widget.path);
    final dirPath = p.dirname(widget.path);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.exists
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.surface1 : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(
                Icons.description_outlined,
                size: 16,
                color: widget.exists
                    ? AppColors.accent
                    : AppColors.textMuted.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: widget.exists
                            ? AppColors.textPrimary
                            : AppColors.textMuted.withValues(alpha: 0.5),
                        decoration: widget.exists
                            ? null
                            : TextDecoration.lineThrough,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      dirPath,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted.withValues(alpha: 0.6),
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (_hovered)
                GestureDetector(
                  onTap: widget.onRemove,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
