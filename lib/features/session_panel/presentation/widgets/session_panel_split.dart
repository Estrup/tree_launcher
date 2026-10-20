import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/session_panel/presentation/controllers/session_panel_controller.dart';

/// [terminal] with [panel] at its right, behind a handle that resizes the
/// panel. Without a [panel] (or room for one) the terminal fills the view.
///
/// Dragging moves a guide line and the panel takes its width on release:
/// resizing the terminal makes the program in it redraw, and a resize per
/// drag step makes the Claude CLI leave copies of its screen in the
/// scrollback.
class SessionPanelSplit extends StatefulWidget {
  const SessionPanelSplit({super.key, required this.terminal, this.panel});

  final Widget terminal;
  final Widget? panel;

  static const handleWidth = 6.0;

  @override
  State<SessionPanelSplit> createState() => _SessionPanelSplitState();
}

class _SessionPanelSplitState extends State<SessionPanelSplit> {
  /// The panel width under the guide line while dragging; null otherwise.
  double? _dragWidth;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SessionPanelController>();
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final panelWidth = widget.panel == null
            ? 0.0
            : SessionPanelController.fit(controller.width, available);
        // The terminal stays the first child of the same Row with or without
        // the panel, so showing the panel doesn't rebuild the terminal view.
        final dragWidth = _dragWidth;
        final active = _hovered || dragWidth != null;
        return Stack(
          children: [
            Row(
              children: [
                Expanded(child: widget.terminal),
                if (panelWidth > 0) ...[
                  MouseRegion(
                    cursor: SystemMouseCursors.resizeColumn,
                    onEnter: (_) => setState(() => _hovered = true),
                    onExit: (_) => setState(() => _hovered = false),
                    child: GestureDetector(
                      key: const ValueKey('session-panel-handle'),
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragStart: (_) =>
                          setState(() => _dragWidth = panelWidth),
                      onHorizontalDragUpdate: (details) => setState(
                        () => _dragWidth = SessionPanelController.fit(
                          (_dragWidth ?? panelWidth) - details.delta.dx,
                          available,
                        ),
                      ),
                      onHorizontalDragEnd: (_) => _endDrag(controller),
                      onHorizontalDragCancel: () =>
                          setState(() => _dragWidth = null),
                      onDoubleTap: () => controller.setWidth(
                        SessionPanelController.defaultWidth,
                      ),
                      child: SizedBox(
                        width: SessionPanelSplit.handleWidth,
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            width: active ? 2 : 1,
                            color: active
                                ? AppColors.accent.withValues(alpha: 0.6)
                                : AppColors.borderSubtle,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: panelWidth, child: widget.panel),
                ],
              ],
            ),
            if (dragWidth != null)
              Positioned(
                top: 0,
                bottom: 0,
                right: dragWidth + SessionPanelSplit.handleWidth / 2 - 1,
                width: 2,
                child: IgnorePointer(
                  child: ColoredBox(color: AppColors.accent),
                ),
              ),
          ],
        );
      },
    );
  }

  void _endDrag(SessionPanelController controller) {
    final width = _dragWidth;
    setState(() => _dragWidth = null);
    if (width != null) controller.setWidth(width);
  }
}
