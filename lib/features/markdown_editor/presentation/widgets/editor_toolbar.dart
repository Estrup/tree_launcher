import 'package:flutter/material.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/markdown_editor/domain/markdown_document.dart';

class EditorToolbar extends StatelessWidget {
  final String? fileName;
  final bool isModified;
  final bool hasCopilotSession;
  final List<MarkdownDocument> openDocuments;
  final int activeDocumentIndex;
  final VoidCallback onOpen;
  final VoidCallback onSave;
  final VoidCallback? onSaveAs;
  final VoidCallback onClose;
  final VoidCallback? onNewFile;
  final VoidCallback? onOpenPlan;
  final VoidCallback? onSendToCopilot;
  final VoidCallback? onInsertPath;
  final ValueChanged<int>? onSwitchDocument;
  final ValueChanged<int>? onCloseDocument;

  const EditorToolbar({
    super.key,
    this.fileName,
    this.isModified = false,
    this.hasCopilotSession = false,
    this.openDocuments = const [],
    this.activeDocumentIndex = 0,
    required this.onOpen,
    required this.onSave,
    this.onSaveAs,
    required this.onClose,
    this.onNewFile,
    this.onOpenPlan,
    this.onSendToCopilot,
    this.onInsertPath,
    this.onSwitchDocument,
    this.onCloseDocument,
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
            enabled: fileName != null && (isModified || openDocuments.isNotEmpty && activeDocumentIndex < openDocuments.length && openDocuments[activeDocumentIndex].isUntitled),
          ),
          _ToolbarButton(
            icon: Icons.save_as_rounded,
            tooltip: 'Save As (⌘⇧S)',
            onTap: onSaveAs ?? () {},
            enabled: onSaveAs != null && fileName != null,
          ),
          const SizedBox(width: 4),
          Container(width: 1, height: 18, color: AppColors.borderSubtle),
          const SizedBox(width: 4),
          if (fileName != null) ...[
            if (openDocuments.length > 1)
              _DocumentDropdown(
                documents: openDocuments,
                activeIndex: activeDocumentIndex,
                onSelect: onSwitchDocument,
                onClose: onCloseDocument,
              )
            else ...[
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
            ],
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

/// Dropdown button that shows all open documents and lets the user switch.
class _DocumentDropdown extends StatefulWidget {
  final List<MarkdownDocument> documents;
  final int activeIndex;
  final ValueChanged<int>? onSelect;
  final ValueChanged<int>? onClose;

  const _DocumentDropdown({
    required this.documents,
    required this.activeIndex,
    this.onSelect,
    this.onClose,
  });

  @override
  State<_DocumentDropdown> createState() => _DocumentDropdownState();
}

class _DocumentDropdownState extends State<_DocumentDropdown> {
  bool _hovered = false;

  MarkdownDocument get _activeDoc =>
      widget.documents[widget.activeIndex.clamp(0, widget.documents.length - 1)];

  @override
  Widget build(BuildContext context) {
    final doc = _activeDoc;
    final label = doc.fileName + (doc.isModified ? ' •' : '');

    return Expanded(
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: _showMenu,
          child: Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: _hovered ? AppColors.surface1 : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 14,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: doc.isModified
                          ? AppColors.accent
                          : AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.unfold_more_rounded,
                  size: 14,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                _DocCountBadge(count: widget.documents.length),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMenu() {
    final renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    showMenu<int>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + size.height,
        offset.dx + size.width,
        offset.dy + size.height,
      ),
      color: AppColors.surface0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.borderSubtle),
      ),
      items: [
        for (int i = 0; i < widget.documents.length; i++)
          PopupMenuItem<int>(
            value: i,
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                if (i == widget.activeIndex)
                  Icon(Icons.chevron_right_rounded, size: 14, color: AppColors.accent)
                else
                  const SizedBox(width: 14),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    widget.documents[i].fileName +
                        (widget.documents[i].isModified ? ' •' : ''),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: i == widget.activeIndex
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: i == widget.activeIndex
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.documents.length > 1)
                  _SmallCloseButton(onTap: () {
                    Navigator.pop(context);
                    widget.onClose?.call(i);
                  }),
              ],
            ),
          ),
      ],
    ).then((index) {
      if (index != null) widget.onSelect?.call(index);
    });
  }
}

class _DocCountBadge extends StatelessWidget {
  final int count;
  const _DocCountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

class _SmallCloseButton extends StatefulWidget {
  final VoidCallback onTap;
  const _SmallCloseButton({required this.onTap});

  @override
  State<_SmallCloseButton> createState() => _SmallCloseButtonState();
}

class _SmallCloseButtonState extends State<_SmallCloseButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.surface1
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Icon(
              Icons.close_rounded,
              size: 12,
              color: _hovered ? AppColors.textPrimary : AppColors.textMuted,
            ),
          ),
        ),
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
