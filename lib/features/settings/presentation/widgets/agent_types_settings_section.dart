import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_form_fields.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/agents/domain/agent_type.dart';
import 'package:tree_launcher/features/agents/presentation/controllers/agents_controller.dart';
import 'package:tree_launcher/features/agents/presentation/widgets/agent_kind_style.dart';
import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';

/// Settings → Agents: the catalog of agent types (added, renamed, given an
/// icon and color, reordered and deleted here). Each repo switches the ones
/// it uses on in its settings.
class AgentTypesSettingsSection extends StatefulWidget {
  const AgentTypesSettingsSection({super.key});

  @override
  State<AgentTypesSettingsSection> createState() =>
      _AgentTypesSettingsSectionState();
}

class _AgentTypesSettingsSectionState extends State<AgentTypesSettingsSection> {
  final _newLabel = TextEditingController();
  final _newFocus = FocusNode();

  @override
  void dispose() {
    _newLabel.dispose();
    _newFocus.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final label = _newLabel.text.trim();
    if (label.isEmpty) return;
    await context.read<SettingsController>().addAgentType(label);
    _newLabel.clear();
    _newFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final types = settings.settings.agentTypes;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Agents',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'The types of agent, each a tab under the repos that switch it '
            'on (Repo settings → Agents) and have prompts or runs of it. '
            'Agents register with the id, so it stays when you rename a type. '
            'An agent that owns its worktree works on an issue in a worktree '
            'of its own, like a build agent.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 24),
          if (types.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'No agent types',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            )
          else
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorder: settings.reorderAgentTypes,
              children: [
                for (var i = 0; i < types.length; i++)
                  _AgentTypeRow(
                    key: ValueKey(types[i].kind),
                    index: i,
                    type: types[i],
                  ),
              ],
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              // Lines the field up with the labels above.
              const SizedBox(width: 96),
              Expanded(
                child: TextField(
                  controller: _newLabel,
                  focusNode: _newFocus,
                  style: appFormFieldTextStyle(context),
                  decoration: InputDecoration(
                    hintText: 'New agent type, e.g. Support',
                    hintStyle: appFormFieldHintStyle(context),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _add(),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 260,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _newLabel.text.trim().isEmpty ? null : _add,
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

/// One type: drag handle, icon, color, label (saved on Enter or when the
/// field loses focus), id, whether it owns its worktree, and delete.
class _AgentTypeRow extends StatefulWidget {
  final int index;
  final AgentType type;

  const _AgentTypeRow({super.key, required this.index, required this.type});

  @override
  State<_AgentTypeRow> createState() => _AgentTypeRowState();
}

class _AgentTypeRowState extends State<_AgentTypeRow> {
  late final _label = TextEditingController(text: widget.type.label);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commitLabel();
    });
  }

  @override
  void didUpdateWidget(_AgentTypeRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && _label.text != widget.type.label) {
      _label.text = widget.type.label;
    }
  }

  @override
  void dispose() {
    _label.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _update(AgentType type) =>
      context.read<SettingsController>().updateAgentType(type);

  void _commitLabel() {
    final label = _label.text.trim();
    if (label.isEmpty) {
      _label.text = widget.type.label;
      return;
    }
    if (label == widget.type.label) return;
    _update(widget.type.copyWith(label: label));
  }

  Future<void> _delete() async {
    final settings = context.read<SettingsController>();
    final kind = widget.type.kind;
    final runs =
        (Provider.of<AgentsController?>(context, listen: false)?.runs ??
                const [])
            .where((r) => r.kind == kind)
            .length;
    final prompts = context
        .read<WorkspaceController>()
        .repos
        .expand((r) => r.claudePrompts)
        .where((p) => p.kind == kind)
        .length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${widget.type.label}"?'),
        content: Text(
          '${_count(runs, 'agent run')} and ${_count(prompts, 'prompt')} are '
          'of this type. They keep it, but its tabs go away, its prompts '
          'no longer start agents, and agents can no longer register as '
          '"${kind.id}".',
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
    await settings.removeAgentType(kind);
  }

  static String _count(int n, String noun) => '$n $noun${n == 1 ? '' : 's'}';

  @override
  Widget build(BuildContext context) {
    final type = widget.type;
    final color = type.colorValue;
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
            tooltip: 'Icon',
            color: AppColors.surface1,
            initialValue: type.icon,
            onSelected: (icon) => _update(type.copyWith(icon: icon)),
            itemBuilder: (_) => [
              for (final icon in agentTypeIcons)
                PopupMenuItem<String>(
                  value: icon,
                  height: 32,
                  child: Icon(
                    type.copyWith(icon: icon).iconData,
                    size: 16,
                    color: color,
                  ),
                ),
            ],
            child: SizedBox(
              width: 32,
              height: 32,
              child: Icon(type.iconData, size: 18, color: color),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Color',
            color: AppColors.surface1,
            initialValue: type.color,
            onSelected: (c) => _update(type.copyWith(color: c)),
            itemBuilder: (_) => [
              for (final c in agentTypeColors)
                PopupMenuItem<String>(
                  value: c,
                  height: 32,
                  child: Row(
                    children: [
                      _ColorDot(color: agentTypeColor(c), size: 10),
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
              controller: _label,
              focusNode: _focus,
              style: appFormFieldTextStyle(context),
              onSubmitted: (_) => _commitLabel(),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 90,
            child: Tooltip(
              message: 'The id agents register with',
              child: Text(
                type.kind.id,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
          Tooltip(
            message:
                'Owns its worktree: works on an issue in a worktree of its '
                'own, like a build agent',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: type.ownsWorktree,
                  onChanged: (v) =>
                      _update(type.copyWith(ownsWorktree: v ?? false)),
                ),
                Text(
                  'Own worktree',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Delete ${type.label}',
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
