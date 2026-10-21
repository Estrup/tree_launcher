import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_form_fields.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/jira/domain/jira_tag.dart';
import 'package:tree_launcher/features/jira/domain/jira_trigger_schedule.dart';
import 'package:tree_launcher/features/jira/presentation/widgets/jira_styles.dart';
import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';

/// Settings → Jira: when Jira is checked for the repos' triggers, and the
/// tags issues can get in the Jira tab (added, renamed, recolored,
/// reordered and deleted here).
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
            'When Jira is checked for triggers, and your own tags for Jira '
            'issues.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'TRIGGER CHECKS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "The repos' triggers (Repo settings → Jira) run when Jira is "
            'checked. A change made while checks are off or outside the hours '
            'fires at the next check.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          const _TriggerScheduleEditor(),
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
          const SizedBox(height: 4),
          Text(
            'Your own tags for Jira issues, set in the Jira tab. Saved on '
            'this Mac only, never sent to Jira.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
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

/// Whether, how often and between which times Jira is checked for triggers.
/// The interval and hours save after a pause, once they are valid.
class _TriggerScheduleEditor extends StatefulWidget {
  const _TriggerScheduleEditor();

  @override
  State<_TriggerScheduleEditor> createState() => _TriggerScheduleEditorState();
}

class _TriggerScheduleEditorState extends State<_TriggerScheduleEditor> {
  late final JiraTriggerSchedule _saved = context
      .read<SettingsController>()
      .settings
      .jiraTriggerSchedule;
  late final _interval = TextEditingController(
    text: '${_saved.intervalMinutes}',
  );
  late final _from = TextEditingController(
    text: _saved.from == null ? '' : formatTimeOfDay(_saved.from!),
  );
  late final _until = TextEditingController(
    text: _saved.until == null ? '' : formatTimeOfDay(_saved.until!),
  );
  Timer? _saveTimer;

  @override
  void dispose() {
    _saveTimer?.cancel();
    _interval.dispose();
    _from.dispose();
    _until.dispose();
    super.dispose();
  }

  int? get _intervalMinutes {
    final minutes = int.tryParse(_interval.text.trim());
    return minutes != null && minutes >= 1 && minutes <= 1440 ? minutes : null;
  }

  /// What is wrong with the typed values; null when they can be saved.
  String? get _error {
    if (_intervalMinutes == null) return 'Check every 1 to 1440 minutes.';
    final from = _from.text.trim();
    final until = _until.text.trim();
    if (from.isEmpty && until.isEmpty) return null;
    if (parseTimeOfDay(from) == null || parseTimeOfDay(until) == null) {
      return 'Give both times as HH:mm, or leave both empty for all day.';
    }
    return null;
  }

  void _changed() {
    setState(() {});
    _saveTimer?.cancel();
    if (_error != null) return;
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      final settings = context.read<SettingsController>();
      final from = parseTimeOfDay(_from.text);
      final until = parseTimeOfDay(_until.text);
      settings.updateJiraTriggerSchedule(
        settings.settings.jiraTriggerSchedule.copyWith(
          intervalMinutes: _intervalMinutes,
          from: from,
          until: until,
          clearHours: from == null,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final schedule = settings.settings.jiraTriggerSchedule;
    final label = TextStyle(fontSize: 13, color: AppColors.textSecondary);
    final error = _error;
    Widget field(
      TextEditingController controller, {
      required double width,
      required String hint,
      bool digitsOnly = false,
    }) => SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        enabled: schedule.enabled,
        style: appFormFieldTextStyle(context, monospace: true),
        inputFormatters: [
          digitsOnly
              ? FilteringTextInputFormatter.digitsOnly
              : FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
        ],
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: appFormFieldHintStyle(context, monospace: true),
        ),
        onChanged: (_) => _changed(),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => settings.updateJiraTriggerSchedule(
              schedule.copyWith(enabled: !schedule.enabled),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: Checkbox(
                    value: schedule.enabled,
                    onChanged: (on) => settings.updateJiraTriggerSchedule(
                      schedule.copyWith(enabled: on ?? false),
                    ),
                    activeColor: AppColors.accent,
                    side: BorderSide(color: AppColors.textMuted),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
                Text('Check Jira for triggers', style: label),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Every', style: label),
            field(_interval, width: 70, hint: '10', digitsOnly: true),
            Text('minutes, between', style: label),
            field(_from, width: 90, hint: '07:00'),
            Text('and', style: label),
            field(_until, width: 90, hint: '17:00'),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          error ?? 'Leave the times empty to check all day.',
          style: TextStyle(
            fontSize: 12,
            color: error != null ? AppColors.error : AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}
