import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_form_fields.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/jira/presentation/widgets/jira_styles.dart';
import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';
import 'package:tree_launcher/models/jira_tag.dart';

/// Settings → Jira: the tags issues can get in the Jira tab. They are added,
/// renamed, recolored, reordered and deleted here.
class JiraSettingsSection extends StatefulWidget {
  const JiraSettingsSection({super.key});

  @override
  State<JiraSettingsSection> createState() => _JiraSettingsSectionState();
}

class _JiraSettingsSectionState extends State<JiraSettingsSection> {
  final _newName = TextEditingController();
  final _newFocus = FocusNode();

  @override
  void dispose() {
    _newName.dispose();
    _newFocus.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = _newName.text.trim();
    if (name.isEmpty) return;
    await context.read<SettingsController>().addJiraTag(name);
    _newName.clear();
    _newFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final tags = settings.settings.jiraTags;
    final byIssue = settings.settings.jiraTagsByIssue;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Jira',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your own tags for Jira issues, set in the Jira tab. Saved on '
            'this Mac only, never sent to Jira.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'TAGS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          if (tags.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'No tags yet',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            )
          else
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorder: settings.reorderJiraTags,
              children: [
                for (var i = 0; i < tags.length; i++)
                  _TagRow(
                    key: ValueKey(tags[i].id),
                    index: i,
                    tag: tags[i],
                    issueCount: byIssue.values
                        .where((ids) => ids.contains(tags[i].id))
                        .length,
                  ),
              ],
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              // Lines the field up with the names above.
              const SizedBox(width: 64),
              Expanded(
                child: TextField(
                  controller: _newName,
                  focusNode: _newFocus,
                  style: appFormFieldTextStyle(context),
                  decoration: InputDecoration(
                    hintText: 'New tag, e.g. Blocked',
                    hintStyle: appFormFieldHintStyle(context),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _add(),
                ),
              ),
              // Same width as a row's issue count and delete button.
              const SizedBox(width: 12),
              SizedBox(
                width: 120,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _newName.text.trim().isEmpty ? null : _add,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Add'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One tag: drag handle, color, name (saved on Enter or when the
/// field loses focus), how many issues have it, and delete.
class _TagRow extends StatefulWidget {
  final int index;
  final JiraTag tag;
  final int issueCount;

  const _TagRow({
    super.key,
    required this.index,
    required this.tag,
    required this.issueCount,
  });

  @override
  State<_TagRow> createState() => _TagRowState();
}

class _TagRowState extends State<_TagRow> {
  late final _name = TextEditingController(text: widget.tag.name);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commitName();
    });
  }

  @override
  void didUpdateWidget(_TagRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && _name.text != widget.tag.name) {
      _name.text = widget.tag.name;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commitName() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _name.text = widget.tag.name;
      return;
    }
    if (name == widget.tag.name) return;
    context.read<SettingsController>().updateJiraTag(
      widget.tag.copyWith(name: name),
    );
  }

  Future<void> _delete() async {
    final settings = context.read<SettingsController>();
    final count = widget.issueCount;
    if (count > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Delete "${widget.tag.name}"?'),
          content: Text(
            count == 1
                ? '1 issue has this tag. It will be taken off it.'
                : '$count issues have this tag. It will be taken off them.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await settings.removeJiraTag(widget.tag.id);
  }

  @override
  Widget build(BuildContext context) {
    final color = jiraTagColor(widget.tag.color);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: widget.index,
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: SizedBox(
                width: 24,
                child: Icon(
                  Icons.drag_indicator_rounded,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            tooltip: 'Color',
            color: AppColors.surface1,
            initialValue: widget.tag.color,
            onSelected: (c) => context.read<SettingsController>().updateJiraTag(
              widget.tag.copyWith(color: c),
            ),
            itemBuilder: (_) => [
              for (final c in jiraTagColors)
                PopupMenuItem<String>(
                  value: c,
                  height: 32,
                  child: Row(
                    children: [
                      _ColorDot(color: jiraTagColor(c), size: 10),
                      const SizedBox(width: 10),
                      Text(
                        '${c[0].toUpperCase()}${c.substring(1)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            child: SizedBox(
              width: 32,
              height: 32,
              child: Center(child: _ColorDot(color: color, size: 14)),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: _name,
              focusNode: _focus,
              style: appFormFieldTextStyle(context),
              onSubmitted: (_) => _commitName(),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 68,
            child: Text(
              widget.issueCount == 1
                  ? '1 issue'
                  : '${widget.issueCount} issues',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Delete ${widget.tag.name}',
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: AppColors.textMuted,
            ),
            onPressed: _delete,
          ),
        ],
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  final double size;

  const _ColorDot({required this.color, required this.size});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
