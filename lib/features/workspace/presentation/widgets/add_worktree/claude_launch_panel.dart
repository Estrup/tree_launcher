import 'package:flutter/material.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/agents/domain/agent_kind.dart';
import 'package:tree_launcher/features/terminal/domain/claude_cli_command.dart';

/// The Claude part of the Start Claude dialog: the prompt to start with, the
/// model and the effort, and the command they add up to.
class ClaudeLaunchPanel extends StatelessWidget {
  const ClaudeLaunchPanel({
    super.key,
    required this.options,
    required this.activeKey,
    required this.model,
    required this.effort,
    required this.enabled,
    required this.cliArgs,
    required this.agentKind,
    required this.onPickPrompt,
    required this.onModel,
    required this.onEffort,
  });

  /// The prompts to pick from.
  final List<PromptOption> options;

  /// The key of the picked prompt among [options], or null for none.
  final String? activeKey;

  /// The picked `--model` alias and `--effort` level.
  final String model;
  final String effort;

  /// False while the worktree is being created.
  final bool enabled;

  /// The extra arguments for `claude` from the settings.
  final String cliArgs;

  /// The kind of agent the picked prompt starts, when it is an agent prompt.
  final AgentKind? agentKind;

  final ValueChanged<PromptOption> onPickPrompt;
  final ValueChanged<String> onModel;
  final ValueChanged<String> onEffort;

  @override
  Widget build(BuildContext context) {
    final active = activeKey;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface0,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('CLAUDE PROMPT'),
          const SizedBox(height: 10),
          for (final option in options) ...[
            _PromptToggle(
              option: option,
              selected: option.key == active,
              enabled: enabled,
              onTap: () => onPickPrompt(option),
            ),
            const SizedBox(height: 6),
          ],
          if (active == null)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 4),
              child: Text(
                'No prompt — Claude starts without a first message.',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ),
          const SizedBox(height: 14),
          _sectionLabel('MODEL'),
          const SizedBox(height: 8),
          _choiceChips(
            values: claudeModelAliases,
            selected: model,
            onSelected: onModel,
          ),
          const SizedBox(height: 14),
          _sectionLabel('EFFORT'),
          const SizedBox(height: 8),
          _choiceChips(
            values: claudeEffortLevels,
            selected: effort,
            onSelected: onEffort,
          ),
          const SizedBox(height: 14),
          Text(
            'Runs ${buildClaudeCliCommand(extraArgs: cliArgs, model: model, effort: effort)} '
            'in the built-in terminal'
            '${agentKind == null ? '' : ' as a ${agentKind!.label.toLowerCase()} agent'}.',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textMuted.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  /// A row of single-select chips for [values].
  Widget _choiceChips({
    required List<String> values,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    String label(String v) =>
        v == 'xhigh' ? 'XHigh' : '${v[0].toUpperCase()}${v.substring(1)}';
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final value in values)
          _LaunchChoiceChip(
            label: label(value),
            selected: value == selected,
            enabled: enabled,
            onTap: () => onSelected(value),
          ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
        letterSpacing: 1.2,
      ),
    );
  }
}

/// One entry of the Claude prompt toggles.
class PromptOption {
  final String key;
  final String label;
  final IconData icon;

  /// First line of the prompt text, shown under the label.
  final String? preview;

  const PromptOption({
    required this.key,
    required this.label,
    required this.icon,
    this.preview,
  });
}

/// A toggle button for one Claude prompt. Selected tiles are tinted in the
/// Claude color with a check mark.
class _PromptToggle extends StatefulWidget {
  final PromptOption option;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _PromptToggle({
    required this.option,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  State<_PromptToggle> createState() => _PromptToggleState();
}

class _PromptToggleState extends State<_PromptToggle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final color = AppColors.claude;
    final preview = widget.option.preview;

    return MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.12)
                : _hovered
                ? AppColors.surface2
                : AppColors.surface1,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.55)
                  : AppColors.borderSubtle,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.15),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                widget.option.icon,
                size: 16,
                color: selected ? color : AppColors.textMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.option.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                    if (preview != null && preview.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 140),
                child: Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  key: ValueKey(selected),
                  size: 16,
                  color: selected
                      ? color
                      : AppColors.textMuted.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small single-select chip in the Claude panel's model / effort rows.
class _LaunchChoiceChip extends StatefulWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _LaunchChoiceChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  State<_LaunchChoiceChip> createState() => _LaunchChoiceChipState();
}

class _LaunchChoiceChipState extends State<_LaunchChoiceChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final color = AppColors.claude;
    return MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.14)
                : _hovered
                ? AppColors.surface2
                : AppColors.surface1,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.55)
                  : AppColors.borderSubtle,
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? color : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
