import 'package:flutter/material.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/jira/presentation/widgets/jira_styles.dart';
import 'package:tree_launcher/models/jira_tag.dart';

/// An issue's tags as chips, the first [maxShown] and then "+N", that open a
/// menu of every tag to tick on and off; it stays open for several. Without
/// tags it shows an "Add tag" hint only while [showHint] (e.g. while the row
/// is hovered) or the menu is open.
class IssueTags extends StatelessWidget {
  /// The issue's tags.
  final List<JiraTag> tags;

  /// Every tag, as offered in the menu.
  final List<JiraTag> allTags;
  final bool showHint;

  /// Called when a tag is ticked on ([tagged]) or off in the menu.
  final void Function(String tagId, bool tagged) onChanged;

  static const maxShown = 3;

  const IssueTags({
    super.key,
    required this.tags,
    required this.allTags,
    required this.showHint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ids = {for (final tag in tags) tag.id};
    return MenuAnchor(
      alignmentOffset: const Offset(0, 4),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(AppColors.surface1),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: AppColors.border),
          ),
        ),
      ),
      menuChildren: [
        for (final tag in allTags)
          CheckboxMenuButton(
            value: ids.contains(tag.id),
            closeOnActivate: false,
            onChanged: (value) => onChanged(tag.id, value ?? false),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TagDot(color: jiraTagColor(tag.color)),
                const SizedBox(width: 8),
                Text(
                  tag.name,
                  style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
      ],
      builder: (context, controller, _) {
        final open = controller.isOpen;
        if (tags.isEmpty && !showHint && !open) return const SizedBox.shrink();
        final shown = tags.take(maxShown).toList();
        final hidden = tags.skip(maxShown).toList();
        return Padding(
          padding: const EdgeInsets.only(left: 8),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: open ? controller.close : controller.open,
              child: tags.isEmpty
                  ? const _AddTagHint()
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < shown.length; i++) ...[
                          if (i > 0) const SizedBox(width: 4),
                          Flexible(child: _TagChip(tag: shown[i])),
                        ],
                        if (hidden.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Tooltip(
                            message: hidden.map((t) => t.name).join(', '),
                            child: _Chip(
                              color: AppColors.textMuted,
                              child: Text(
                                '+${hidden.length}',
                                style: _chipTextStyle(AppColors.textSecondary),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}

TextStyle _chipTextStyle(Color color) =>
    TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color);

class _TagChip extends StatelessWidget {
  final JiraTag tag;

  const _TagChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    final color = jiraTagColor(tag.color);
    return _Chip(
      color: color,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TagDot(color: color, size: 6),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              tag.name,
              overflow: TextOverflow.ellipsis,
              style: _chipTextStyle(AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddTagHint extends StatelessWidget {
  const _AddTagHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sell_outlined, size: 11, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text('Add tag', style: _chipTextStyle(AppColors.textMuted)),
        ],
      ),
    );
  }
}

/// A small rounded chip tinted with [color].
class _Chip extends StatelessWidget {
  final Color color;
  final Widget child;

  const _Chip({required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Center(widthFactor: 1, child: child),
    );
  }
}

class _TagDot extends StatelessWidget {
  final Color color;
  final double size;

  const _TagDot({required this.color, this.size = 8});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
