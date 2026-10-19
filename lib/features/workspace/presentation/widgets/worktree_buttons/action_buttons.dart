import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';

/// Opens a dropdown menu positioned below [anchorContext]'s render box.
Future<T?> showMenuBelow<T>(
  BuildContext anchorContext, {
  required List<PopupMenuEntry<T>> items,
  double minWidth = 200,
}) {
  final RenderBox button = anchorContext.findRenderObject() as RenderBox;
  final overlay =
      Overlay.of(anchorContext).context.findRenderObject() as RenderBox;
  final position = RelativeRect.fromRect(
    Rect.fromPoints(
      button.localToGlobal(Offset(0, button.size.height)),
      button.localToGlobal(Offset(button.size.width, button.size.height)),
    ),
    Offset.zero & overlay.size,
  );

  return showMenu<T>(
    context: anchorContext,
    position: position,
    color: AppColors.surface1,
    constraints: BoxConstraints(minWidth: minWidth),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(color: AppColors.border),
    ),
    items: items,
  );
}

// ---------------------------------------------------------------------------
// Terminal button
// ---------------------------------------------------------------------------
/// A compact (table-mode) single-icon button. Tapping it opens the dropdown
/// when [onDropdown] is non-null (the default action is the first menu item),
/// otherwise it runs [onPrimary] directly. No caret — the whole button is the
/// icon.
class CompactActionButton extends StatefulWidget {
  final Color color;
  final Color bgColor;
  final String tooltip;
  final Widget icon;
  final VoidCallback onPrimary;
  final VoidCallback? onDropdown;

  const CompactActionButton({
    super.key,
    required this.color,
    required this.bgColor,
    required this.tooltip,
    required this.icon,
    required this.onPrimary,
    required this.onDropdown,
  });

  @override
  State<CompactActionButton> createState() => _CompactActionButtonState();
}

class _CompactActionButtonState extends State<CompactActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onDropdown ?? widget.onPrimary,
        child: Tooltip(
          message: widget.tooltip,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _hovered
                  ? widget.color.withValues(alpha: 0.2)
                  : widget.bgColor,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: _hovered
                    ? widget.color.withValues(alpha: 0.4)
                    : widget.color.withValues(alpha: 0.15),
              ),
            ),
            child: Center(child: widget.icon),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Custom commands button
// ---------------------------------------------------------------------------
class ActionButton extends StatefulWidget {
  final IconData? icon;
  final String? svgAsset;
  final Color color;
  final Color bgColor;
  final VoidCallback onPressed;
  final bool compact;

  const ActionButton({
    super.key,
    this.icon,
    this.svgAsset,
    required this.color,
    required this.bgColor,
    required this.onPressed,
    this.compact = false,
  }) : assert(icon != null || svgAsset != null);

  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final size = widget.compact ? 28.0 : 36.0;
    final glyphSize = widget.compact ? 13.0 : 14.0;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: _hovered
                ? widget.color.withValues(alpha: 0.2)
                : widget.bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hovered
                  ? widget.color.withValues(alpha: 0.4)
                  : widget.color.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              widget.svgAsset != null
                  ? SvgPicture.asset(
                      widget.svgAsset!,
                      width: glyphSize,
                      height: glyphSize,
                      colorFilter: ColorFilter.mode(
                        widget.color,
                        BlendMode.srcIn,
                      ),
                    )
                  : Icon(widget.icon, size: glyphSize, color: widget.color),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// JIRA badge (link)
// ---------------------------------------------------------------------------
