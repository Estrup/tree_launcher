import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/markdown_editor/presentation/controllers/markdown_editor_controller.dart';
import 'package:tree_launcher/features/markdown_editor/presentation/widgets/markdown_editor_view.dart';

/// A resizable horizontal split view that places a widget alongside
/// the markdown editor. Used to show the editor next to a Copilot terminal.
class EditorSplitPanel extends StatefulWidget {
  final Widget child;

  const EditorSplitPanel({
    super.key,
    required this.child,
  });

  @override
  State<EditorSplitPanel> createState() => _EditorSplitPanelState();
}

class _EditorSplitPanelState extends State<EditorSplitPanel> {
  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MarkdownEditorController>();

    if (!controller.isSidePanelOpen) {
      return widget.child;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final editorWidth = totalWidth * controller.sidePanelRatio;
        final childWidth = totalWidth - editorWidth - 6; // 6px for divider

        return Row(
          children: [
            SizedBox(
              width: childWidth,
              child: widget.child,
            ),
            _ResizeDivider(
              onDrag: (dx) {
                final newRatio = controller.sidePanelRatio - (dx / totalWidth);
                controller.setSidePanelRatio(newRatio);
              },
            ),
            SizedBox(
              width: editorWidth,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: AppColors.borderSubtle,
                      width: 1,
                    ),
                  ),
                ),
                child: const MarkdownEditorView(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ResizeDivider extends StatefulWidget {
  final ValueChanged<double> onDrag;

  const _ResizeDivider({required this.onDrag});

  @override
  State<_ResizeDivider> createState() => _ResizeDividerState();
}

class _ResizeDividerState extends State<_ResizeDivider> {
  bool _hovered = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final isActive = _hovered || _dragging;

    return GestureDetector(
      onHorizontalDragStart: (_) => setState(() => _dragging = true),
      onHorizontalDragUpdate: (d) => widget.onDrag(d.delta.dx),
      onHorizontalDragEnd: (_) => setState(() => _dragging = false),
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Container(
          width: 6,
          color: Colors.transparent,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: isActive ? 3 : 1,
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.accent.withValues(alpha: 0.6)
                    : AppColors.borderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
