import 'package:flutter/material.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';

/// Width and height reserved for a [SelectCheckbox].
const double selectCheckboxSize = 24;

/// Hand-rolled 16×16 checkbox matching the app's hover-container controls.
/// [value] null renders the header's partial (dash) state. While [visible] is
/// false the checkbox is faded out and ignores pointer events, but its space
/// stays reserved so columns never shift.
class SelectCheckbox extends StatelessWidget {
  final bool? value;
  final bool visible;
  final VoidCallback onTap;

  const SelectCheckbox({
    super.key,
    required this.value,
    required this.visible,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final checked = value != false;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 120),
      opacity: visible ? 1 : 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: SizedBox(
              width: selectCheckboxSize,
              height: selectCheckboxSize,
              child: Center(
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: checked ? AppColors.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: checked ? AppColors.accent : AppColors.border,
                    ),
                  ),
                  child: checked
                      ? Icon(
                          value == null
                              ? Icons.remove_rounded
                              : Icons.check_rounded,
                          size: 12,
                          color: AppColors.base,
                        )
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Outlined toolbar button for actions on a selection.
class BulkBarButton extends StatefulWidget {
  final IconData icon;
  final String label;

  /// Foreground while hovered; defaults to the standard text hover color.
  final Color? color;

  /// Disabled when null.
  final VoidCallback? onTap;
  final String? disabledTooltip;

  /// Shows a spinner in place of the icon, e.g. while the action loads.
  final bool busy;

  const BulkBarButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.disabledTooltip,
    this.busy = false,
  });

  @override
  State<BulkBarButton> createState() => BulkBarButtonState();
}

class BulkBarButtonState extends State<BulkBarButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final foreground = !enabled
        ? AppColors.textMuted.withValues(alpha: 0.5)
        : _hovered
        ? (widget.color ?? AppColors.textPrimary)
        : AppColors.textMuted;

    Widget button = MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _hovered && enabled
                ? AppColors.surface2
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.busy)
                SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: foreground,
                  ),
                )
              else
                Icon(widget.icon, size: 13, color: foreground),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!enabled && widget.disabledTooltip != null) {
      button = Tooltip(message: widget.disabledTooltip!, child: button);
    }
    return button;
  }
}
