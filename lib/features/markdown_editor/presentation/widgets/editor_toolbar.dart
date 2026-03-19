import 'package:flutter/material.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';

class EditorToolbar extends StatelessWidget {
  final String? fileName;
  final bool isModified;
  final bool hasCopilotSession;
  final VoidCallback onOpen;
  final VoidCallback onSave;
  final VoidCallback onClose;
  final VoidCallback? onNewFile;
  final VoidCallback? onOpenPlan;
  final VoidCallback? onSendToCopilot;
  final VoidCallback? onInsertPath;

  const EditorToolbar({
    super.key,
    this.fileName,
    this.isModified = false,
    this.hasCopilotSession = false,
    required this.onOpen,
    required this.onSave,
    required this.onClose,
    this.onNewFile,
    this.onOpenPlan,
    this.onSendToCopilot,
    this.onInsertPath,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface0,
        border: Border(
          bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: Row(
        children: [
          if (hasCopilotSession) ...[
            _ToolbarButton(
              icon: Icons.note_add_rounded,
              tooltip: 'New document',
              onTap: onNewFile ?? () {},
              enabled: onNewFile != null,
            ),
            _ToolbarButton(
              icon: Icons.assignment_rounded,
              tooltip: 'Open plan.md',
              onTap: onOpenPlan ?? () {},
              enabled: onOpenPlan != null,
            ),
            const SizedBox(width: 4),
            Container(width: 1, height: 18, color: AppColors.borderSubtle),
            const SizedBox(width: 4),
          ],
          _ToolbarButton(
            icon: Icons.folder_open_rounded,
            tooltip: 'Open file (⌘O)',
            onTap: onOpen,
          ),
          _ToolbarButton(
            icon: Icons.save_rounded,
            tooltip: 'Save (⌘S)',
            onTap: onSave,
            enabled: isModified,
          ),
          const SizedBox(width: 4),
          Container(width: 1, height: 18, color: AppColors.borderSubtle),
          const SizedBox(width: 4),
          if (fileName != null) ...[
            Icon(
              Icons.description_outlined,
              size: 14,
              color: AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                fileName! + (isModified ? ' •' : ''),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isModified
                      ? AppColors.accent
                      : AppColors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasCopilotSession) ...[
              _ToolbarButton(
                icon: Icons.send_rounded,
                tooltip: 'Send contents to copilot',
                onTap: onSendToCopilot ?? () {},
                enabled: onSendToCopilot != null,
                size: 16,
              ),
              _ToolbarButton(
                icon: Icons.link_rounded,
                tooltip: 'Insert file path in copilot',
                onTap: onInsertPath ?? () {},
                enabled: onInsertPath != null,
                size: 16,
              ),
            ],
            _ToolbarButton(
              icon: Icons.close_rounded,
              tooltip: 'Close file',
              onTap: onClose,
              size: 16,
            ),
          ] else
            Expanded(
              child: Text(
                'No file open',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool enabled;
  final double size;

  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.enabled = true,
    this.size = 18,
  });

  @override
  State<_ToolbarButton> createState() => _ToolbarButtonState();
}

class _ToolbarButtonState extends State<_ToolbarButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.enabled
        ? (_hovered ? AppColors.textPrimary : AppColors.textSecondary)
        : AppColors.textMuted.withValues(alpha: 0.3);

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: widget.enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: widget.enabled ? widget.onTap : null,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _hovered && widget.enabled
                  ? AppColors.surface1
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Icon(icon, size: widget.size, color: color),
            ),
          ),
        ),
      ),
    );
  }

  IconData get icon => widget.icon;
}
