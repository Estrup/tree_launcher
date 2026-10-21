import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_form_fields.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/jira/domain/jira_trigger.dart';
import 'package:tree_launcher/features/jira/domain/jira_version.dart';
import 'package:tree_launcher/features/terminal/domain/claude_cli_command.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/repo_settings/settings_controls.dart';

/// The selected repo's Jira triggers, each editable in place, and a button
/// to add one. Changes are saved at once (a typed status after a pause).
class JiraTriggersList extends StatelessWidget {
  const JiraTriggersList({super.key, required this.versions});

  /// The project's fixVersions.
  final List<JiraVersion> versions;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<WorkspaceController>().selectedRepo;
    if (repo == null) return const SizedBox.shrink();
    final unreleased = [
      for (final v in orderVersionsForPicker(versions))
        if (!v.released) v,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final trigger in repo.jiraTriggers)
          _TriggerCard(
            key: ValueKey(trigger.id),
            trigger: trigger,
            versions: [
              ...unreleased,
              // A released or deleted version stays pickable while used.
              if (!unreleased.any((v) => v.id == trigger.fixVersionId))
                versions
                        .where((v) => v.id == trigger.fixVersionId)
                        .firstOrNull ??
                    JiraVersion(
                      id: trigger.fixVersionId,
                      name: trigger.fixVersionId,
                    ),
            ],
          ),
        if (repo.jiraTriggers.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'No triggers.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
        if (unreleased.isNotEmpty)
          SettingsAddButton(
            label: 'Add Trigger',
            color: AppColors.accent,
            bgColor: AppColors.accent.withValues(alpha: 0.12),
            onTap: () => _save(context, [
              ...repo.jiraTriggers,
              JiraTrigger.create(fixVersionId: unreleased.first.id),
            ]),
          ),
      ],
    );
  }
}

void _save(BuildContext context, List<JiraTrigger> triggers) {
  final workspace = context.read<WorkspaceController>();
  final repo = workspace.selectedRepo;
  if (repo != null) workspace.updateJiraTriggers(repo, triggers);
}

/// Replaces [trigger] in the selected repo's triggers with [updated].
void _replace(BuildContext context, JiraTrigger trigger, JiraTrigger? updated) {
  final repo = context.read<WorkspaceController>().selectedRepo;
  if (repo == null) return;
  _save(context, [
    for (final t in repo.jiraTriggers)
      if (t.id != trigger.id) t else ?updated,
  ]);
}

class _TriggerCard extends StatefulWidget {
  const _TriggerCard({
    super.key,
    required this.trigger,
    required this.versions,
  });

  final JiraTrigger trigger;
  final List<JiraVersion> versions;

  @override
  State<_TriggerCard> createState() => _TriggerCardState();
}

class _TriggerCardState extends State<_TriggerCard> {
  late final _status = TextEditingController(text: widget.trigger.status);
  Timer? _statusTimer;

  @override
  void dispose() {
    _statusTimer?.cancel();
    _status.dispose();
    super.dispose();
  }

  JiraTrigger get _trigger => widget.trigger;

  /// Saves [updated]. A change to what the rule matches restarts it from
  /// now, so issues that changed before don't fire.
  void _update(JiraTrigger updated, {bool restart = false}) => _replace(
    context,
    _trigger,
    restart ? updated.copyWith(since: DateTime.now()) : updated,
  );

  void _statusChanged(String value) {
    _statusTimer?.cancel();
    _statusTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) _update(_trigger.copyWith(status: value), restart: true);
    });
  }

  /// Where the session runs, in words.
  String _whereItRuns(WorkspaceController workspace) {
    final path = _trigger.worktreePath;
    if (path != null) {
      final name =
          workspace.worktrees.where((w) => w.path == path).firstOrNull?.name ??
          p.basename(path);
      return 'Every issue runs in $name.';
    }
    final branch =
        workspace.selectedRepo?.jiraVersionBranches[_trigger.fixVersionId];
    return branch != null
        ? "Runs in the issue's worktree, or in a new one from $branch when it "
              'has none.'
        : "Runs in the issue's worktree. Map the version to a default branch "
              "above, or an issue without a worktree won't start.";
  }

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<WorkspaceController>();
    final prompts = workspace.selectedRepo?.claudePrompts ?? const [];
    final worktrees = workspace.worktrees;
    final trigger = _trigger;
    final label = TextStyle(fontSize: 12, color: AppColors.textMuted);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.surface0,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Check(
                label: 'Enabled',
                value: trigger.enabled,
                onChanged: (on) =>
                    _update(trigger.copyWith(enabled: on), restart: on),
              ),
              const Spacer(),
              SettingsRemoveButton(
                onTap: () => _replace(context, trigger, null),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('When an issue in', style: label),
              SizedBox(
                width: 260,
                child: AppDropdownField<String>(
                  initialValue: trigger.fixVersionId,
                  items: [
                    for (final v in widget.versions)
                      DropdownMenuItem(
                        value: v.id,
                        child: Text(v.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (id) => _update(
                    trigger.copyWith(fixVersionId: id),
                    restart: true,
                  ),
                ),
              ),
              SizedBox(
                width: 200,
                child: AppDropdownField<JiraTriggerEvent>(
                  initialValue: trigger.event,
                  items: [
                    for (final e in JiraTriggerEvent.values)
                      DropdownMenuItem(value: e, child: Text(e.label)),
                  ],
                  onChanged: (e) =>
                      _update(trigger.copyWith(event: e), restart: true),
                ),
              ),
              if (trigger.event == JiraTriggerEvent.status)
                SizedBox(
                  width: 170,
                  child: TextField(
                    controller: _status,
                    style: appFormFieldTextStyle(context),
                    decoration: InputDecoration(
                      hintText: 'e.g. QA Rejected',
                      hintStyle: appFormFieldHintStyle(context),
                    ),
                    onChanged: _statusChanged,
                  ),
                ),
              _Check(
                label: 'assigned to me',
                value: trigger.assignedToMe,
                onChanged: (on) =>
                    _update(trigger.copyWith(assignedToMe: on), restart: true),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('start', style: label),
              SizedBox(
                width: 200,
                child: AppDropdownField<String>(
                  initialValue: prompts.any((p) => p.name == trigger.promptName)
                      ? trigger.promptName
                      : null,
                  decoration: const InputDecoration(hintText: 'Saved prompt'),
                  items: [
                    for (final prompt in prompts)
                      DropdownMenuItem(
                        value: prompt.name,
                        child: Text(
                          prompt.kind == null
                              ? prompt.name
                              : '${prompt.name} (${prompt.kind!.label})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (name) =>
                      _update(trigger.copyWith(promptName: name)),
                ),
              ),
              Text('in', style: label),
              SizedBox(
                width: 260,
                child: AppDropdownField<String>(
                  initialValue: trigger.worktreePath ?? '',
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text(
                        "the issue's worktree (or a new one)",
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    for (final w in worktrees)
                      DropdownMenuItem(
                        value: w.path,
                        child: Text(w.name, overflow: TextOverflow.ellipsis),
                      ),
                    if (trigger.worktreePath != null &&
                        !worktrees.any((w) => w.path == trigger.worktreePath))
                      DropdownMenuItem(
                        value: trigger.worktreePath,
                        child: Text(
                          p.basename(trigger.worktreePath!),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (path) => _update(
                    path == null || path.isEmpty
                        ? trigger.copyWith(clearWorktreePath: true)
                        : trigger.copyWith(worktreePath: path),
                  ),
                ),
              ),
              Text('with', style: label),
              SizedBox(
                width: 130,
                child: AppDropdownField<String>(
                  initialValue: trigger.model,
                  items: [
                    for (final model in claudeModelAliases)
                      DropdownMenuItem(value: model, child: Text(model)),
                  ],
                  onChanged: (model) => _update(trigger.copyWith(model: model)),
                ),
              ),
              SizedBox(
                width: 130,
                child: AppDropdownField<String>(
                  initialValue: trigger.effort,
                  items: [
                    for (final effort in claudeEffortLevels)
                      DropdownMenuItem(value: effort, child: Text(effort)),
                  ],
                  onChanged: (effort) =>
                      _update(trigger.copyWith(effort: effort)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(_whereItRuns(workspace), style: label),
          if (!trigger.isComplete) ...[
            const SizedBox(height: 8),
            Text(
              trigger.promptName == null
                  ? 'Pick a saved prompt to turn the trigger on.'
                  : 'Enter the status to turn the trigger on.',
              style: TextStyle(fontSize: 12, color: AppColors.error),
            ),
          ],
        ],
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    child: GestureDetector(
      onTap: () => onChanged(!value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              activeColor: AppColors.accent,
              side: BorderSide(color: AppColors.textMuted),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );
}
