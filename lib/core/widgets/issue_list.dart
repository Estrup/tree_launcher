import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tree_launcher/core/design_system/app_form_fields.dart';
import 'package:tree_launcher/theme/app_theme.dart';

/// Pieces shared by the issue tabs (Jira, GitHub) and their issue dialogs.

/// Searches as you type (after a pause), or at once on Enter. Clearing it, or
/// Escape, searches for nothing.
class IssueSearchField extends StatefulWidget {
  /// The controller's query; the field follows it when it's cleared from
  /// outside (e.g. a version picked, another repo selected).
  final String query;
  final ValueChanged<String> onSearch;
  final String hintText;

  const IssueSearchField({
    super.key,
    required this.query,
    required this.onSearch,
    required this.hintText,
  });

  @override
  State<IssueSearchField> createState() => _IssueSearchFieldState();
}

class _IssueSearchFieldState extends State<IssueSearchField> {
  static const _pause = Duration(milliseconds: 400);

  late final _text = TextEditingController(text: widget.query);
  Timer? _timer;

  @override
  void didUpdateWidget(IssueSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != oldWidget.query &&
        widget.query != _text.text.trim() &&
        !(_timer?.isActive ?? false)) {
      _text.text = widget.query;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _changed(String value) {
    setState(() {}); // Shows or hides the clear button.
    _timer?.cancel();
    _timer = Timer(_pause, () => widget.onSearch(value));
  }

  void _submit(String value) {
    _timer?.cancel();
    widget.onSearch(value);
  }

  void _clear() {
    _text.clear();
    _submit('');
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _clear},
      child: TextField(
        controller: _text,
        onChanged: _changed,
        onSubmitted: _submit,
        style: appFormFieldTextStyle(context),
        decoration: InputDecoration(
          hintText: widget.hintText,
          prefixIcon: Icon(Icons.search, size: 16, color: AppColors.textMuted),
          suffixIcon: _text.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  icon: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  onPressed: _clear,
                ),
        ),
      ),
    );
  }
}

/// A filter chip with a label and a count, tinted [color] while selected.
class IssueFilterChip extends StatefulWidget {
  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const IssueFilterChip({
    super.key,
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  State<IssueFilterChip> createState() => _IssueFilterChipState();
}

class _IssueFilterChipState extends State<IssueFilterChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    final selected = widget.selected;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.18)
                : _hovered
                ? AppColors.surface2
                : AppColors.surface1,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.5)
                  : AppColors.borderSubtle,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? color : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${widget.count}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? color.withValues(alpha: 0.8)
                      : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The accent-coloured count next to a tab's picker.
class IssueCountBadge extends StatelessWidget {
  final String text;
  final String? tooltip;

  const IssueCountBadge({super.key, required this.text, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accentMuted,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.accent,
        ),
      ),
    );
    return tooltip == null ? badge : Tooltip(message: tooltip, child: badge);
  }
}

/// A red box with an error [message].
class IssueErrorBanner extends StatelessWidget {
  final String message;

  /// Text size; the dialogs use a smaller one than the tabs.
  final double fontSize;

  const IssueErrorBanner({
    super.key,
    required this.message,
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 16, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: AppColors.error, fontSize: fontSize),
            ),
          ),
        ],
      ),
    );
  }
}

/// A large muted icon with a line of text, centred.
class IssueCenteredMessage extends StatelessWidget {
  final IconData icon;
  final String text;

  const IssueCenteredMessage({
    super.key,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(
            text,
            style: TextStyle(color: AppColors.textMuted, fontSize: 17),
          ),
        ],
      ),
    );
  }
}

/// A circle with the initials of [name], tinted [color].
class InitialsAvatar extends StatelessWidget {
  final String name;
  final Color color;

  const InitialsAvatar({super.key, required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    final initials = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// A dialog section heading, with a count after it when given.
class IssueSectionLabel extends StatelessWidget {
  final String text;
  final int? count;

  const IssueSectionLabel(this.text, {super.key, this.count});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: AppColors.textMuted,
      letterSpacing: 1.2,
    );
    if (count == null) return Text(text, style: style);
    return Row(
      children: [
        Text(text, style: style),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// How long ago a list was refreshed, e.g. `3m ago`.
String formatLastRefreshed(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  return '${diff.inHours}h ago';
}

/// How long ago [t] was, e.g. `5d ago`.
String formatRelativeTime(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.isNegative) return 'just now';
  if (d.inSeconds < 60) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 30) return '${d.inDays}d ago';
  if (d.inDays < 365) return '${(d.inDays / 30).floor()}mo ago';
  return '${(d.inDays / 365).floor()}y ago';
}

/// [t] as local date and time, e.g. `9 Oct 2026, 14:05`.
String formatAbsoluteTime(DateTime t) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final local = t.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.day} ${months[local.month - 1]} ${local.year}, '
      '${two(local.hour)}:${two(local.minute)}';
}
