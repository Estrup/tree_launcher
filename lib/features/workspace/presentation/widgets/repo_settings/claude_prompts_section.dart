import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_form_fields.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/agents/domain/agent_kind.dart';
import 'package:tree_launcher/features/agents/domain/claude_prompt.dart';
import 'package:tree_launcher/features/agents/presentation/widgets/agent_kind_style.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/repo_settings/settings_controls.dart';

class RepoClaudePromptsSection extends StatefulWidget {
  const RepoClaudePromptsSection({super.key});

  @override
  State<RepoClaudePromptsSection> createState() => _ClaudePromptsSectionState();
}

class _ClaudePromptsSectionState extends State<RepoClaudePromptsSection> {
  late List<ClaudePrompt> _prompts;
  String? _lastRepoPath;
  Timer? _debounce;

  /// Index of the prompt open in the editor; null shows the list.
  int? _editingIndex;

  @override
  void initState() {
    super.initState();
    final repo = context.read<WorkspaceController>().selectedRepo;
    _lastRepoPath = repo?.path;
    _prompts = List.from(repo?.claudePrompts ?? []);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repo = context.read<WorkspaceController>().selectedRepo;
    if (repo != null && repo.path != _lastRepoPath) {
      _lastRepoPath = repo.path;
      _prompts = List.from(repo.claudePrompts);
      _editingIndex = null;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _save() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final provider = context.read<WorkspaceController>();
      final repo = provider.selectedRepo;
      if (repo == null) return;
      final cleaned = _prompts
          .where((p) => p.name.trim().isNotEmpty || p.prompt.trim().isNotEmpty)
          .map(
            (p) => p.copyWith(name: p.name.trim(), prompt: p.prompt.trim()),
          )
          .toList();
      provider.updateRepoClaudePrompts(repo, cleaned);
    });
  }

  void _addPrompt() {
    setState(() {
      _prompts.add(ClaudePrompt(name: '', prompt: ''));
      _editingIndex = _prompts.length - 1;
    });
  }

  void _removePrompt(int index) {
    setState(() {
      _prompts.removeAt(index);
    });
    _save();
  }

  void _closeEditor() {
    final index = _editingIndex;
    setState(() {
      _editingIndex = null;
      // Drop a freshly added prompt that was left blank.
      if (index != null &&
          index < _prompts.length &&
          _prompts[index].name.trim().isEmpty &&
          _prompts[index].prompt.trim().isEmpty) {
        _prompts.removeAt(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final editingIndex = _editingIndex;
    if (editingIndex != null && editingIndex < _prompts.length) {
      return _ClaudePromptEditor(
        key: ValueKey('prompt_editor_$editingIndex'),
        prompt: _prompts[editingIndex],
        onChanged: (p) {
          setState(() => _prompts[editingIndex] = p);
          _save();
        },
        onBack: _closeEditor,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Claude Prompts',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Prompt templates offered by the Claude button on a worktree. '
                      'A prompt with an agent kind starts that kind of agent from its tab. '
                      'Substitutions: {issue}, {pr}, {base_branch}, {worktree}, {path}, {repo}.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              SettingsAddButton(
                label: 'Add Prompt',
                color: AppColors.claude,
                bgColor: AppColors.claudeBg,
                onTap: _addPrompt,
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_prompts.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface0,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 32,
                    color: AppColors.textMuted.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No Claude prompts',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add prompt templates to pick from when launching Claude.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            )
          else
            ...List.generate(_prompts.length, (index) {
              return _ClaudePromptRow(
                key: ValueKey('prompt_$index'),
                prompt: _prompts[index],
                onTap: () => setState(() => _editingIndex = index),
                onRemove: () => _removePrompt(index),
              );
            }),
        ],
      ),
    );
  }
}

/// A prompt in the Claude Prompts list: just the name; tap to edit.
class _ClaudePromptRow extends StatefulWidget {
  final ClaudePrompt prompt;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _ClaudePromptRow({
    super.key,
    required this.prompt,
    required this.onTap,
    required this.onRemove,
  });

  @override
  State<_ClaudePromptRow> createState() => _ClaudePromptRowState();
}

class _ClaudePromptRowState extends State<_ClaudePromptRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final name = widget.prompt.name.trim();
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.surface1 : AppColors.surface0,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: AppColors.claude,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name.isEmpty ? 'Untitled prompt' : name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: name.isEmpty
                        ? AppColors.textMuted
                        : AppColors.textPrimary,
                    fontStyle: name.isEmpty
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
              ),
              if (widget.prompt.kind case final kind?) ...[
                AgentKindChip(kind: kind),
                const SizedBox(width: 8),
              ],
              SettingsRemoveButton(onTap: widget.onRemove),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: _hovered ? AppColors.textPrimary : AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-pane editor for a single Claude prompt, so long prompts get room.
class _ClaudePromptEditor extends StatefulWidget {
  final ClaudePrompt prompt;
  final ValueChanged<ClaudePrompt> onChanged;
  final VoidCallback onBack;

  const _ClaudePromptEditor({
    super.key,
    required this.prompt,
    required this.onChanged,
    required this.onBack,
  });

  @override
  State<_ClaudePromptEditor> createState() => _ClaudePromptEditorState();
}

class _ClaudePromptEditorState extends State<_ClaudePromptEditor> {
  late final TextEditingController _nameController;
  late final TextEditingController _promptController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.prompt.name);
    _promptController = TextEditingController(text: widget.prompt.prompt);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  Widget _label(String text) => Text(
    text,
    style: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: AppColors.textMuted,
      letterSpacing: 1.0,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SettingsBackButton(onTap: widget.onBack),
              const SizedBox(width: 8),
              Text(
                'Claude Prompts',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 44),
            child: Text(
              'Substitutions: {issue}, {pr}, {base_branch}, {worktree}, {path}, {repo}.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 24),
          _label('NAME'),
          const SizedBox(height: 6),
          SizedBox(
            width: 400,
            child: TextField(
              autofocus: widget.prompt.name.isEmpty,
              style: appFormFieldTextStyle(context),
              decoration: const InputDecoration(
                hintText: 'e.g. Analyse Jira Issue',
              ),
              controller: _nameController,
              onChanged: (v) =>
                  widget.onChanged(widget.prompt.copyWith(name: v)),
            ),
          ),
          const SizedBox(height: 20),
          _label('AGENT KIND'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _KindOption(
                label: 'None',
                icon: Icons.auto_awesome_rounded,
                color: AppColors.claude,
                selected: widget.prompt.kind == null,
                onTap: () =>
                    widget.onChanged(widget.prompt.copyWith(clearKind: true)),
              ),
              for (final kind in AgentKind.values)
                _KindOption(
                  label: kind.label,
                  icon: kind.icon,
                  color: kind.color,
                  selected: widget.prompt.kind == kind,
                  onTap: () =>
                      widget.onChanged(widget.prompt.copyWith(kind: kind)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            widget.prompt.kind == null
                ? 'An ordinary prompt, offered when starting Claude.'
                : 'Starts a ${widget.prompt.kind!.label.toLowerCase()} agent: '
                      'offered in the ${widget.prompt.kind!.label} tab, which '
                      'shows what the agent reports.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          _label('PROMPT'),
          const SizedBox(height: 6),
          Expanded(
            child: TextField(
              style: appFormFieldTextStyle(
                context,
                monospace: true,
                height: 1.5,
              ),
              expands: true,
              maxLines: null,
              minLines: null,
              textAlignVertical: TextAlignVertical.top,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                hintText:
                    'e.g. Retrieve the jira issue {issue} with comments and files.\n'
                    'Analyse the issue on branch {base_branch} and find a solution.',
                hintStyle: appFormFieldHintStyle(context, monospace: true),
              ),
              controller: _promptController,
              onChanged: (v) =>
                  widget.onChanged(widget.prompt.copyWith(prompt: v)),
            ),
          ),
        ],
      ),
    );
  }
}

/// One choice in the prompt editor's agent-kind picker.
class _KindOption extends StatelessWidget {
  const _KindOption({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.15)
                : AppColors.surface0,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.5)
                  : AppColors.borderSubtle,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: selected ? color : AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? color : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Predefined Issues Section ---
