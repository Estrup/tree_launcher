import 'package:flutter/material.dart';
import 'package:tree_launcher/core/design_system/app_form_fields.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/workspace/domain/custom_command.dart';
import 'package:tree_launcher/features/workspace/presentation/command_style.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/repo_settings/settings_controls.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/repo_settings/repo_settings_section_state.dart';
import 'package:tree_launcher/features/workspace/domain/repo_config.dart';

class RepoCustomCommandsSection extends StatefulWidget {
  const RepoCustomCommandsSection({super.key});

  @override
  State<RepoCustomCommandsSection> createState() => _CustomCommandsSectionState();
}

class _CustomCommandsSectionState extends State<RepoCustomCommandsSection>
    with RepoSettingsSectionState {
  late List<CustomCommand> _commands;

  @override
  void loadFrom(RepoConfig? repo) {
    _commands = List.from(repo?.customCommands ?? []);
  }

  void _save() {
    saveLater((provider, repo) {
      final cleaned = _commands
          .where((c) => c.name.trim().isNotEmpty || c.command.trim().isNotEmpty)
          .map(
            (c) => CustomCommand(
              name: c.name.trim(),
              command: c.command.trim(),
              iconName: c.iconName,
              colorHex: c.colorHex,
            ),
          )
          .toList();
      provider.updateRepoCustomCommands(repo, cleaned);
    });
  }

  void _addCommand() {
    setState(() {
      _commands.add(CustomCommand(name: '', command: ''));
    });
  }

  void _removeCommand(int index) {
    setState(() {
      _commands.removeAt(index);
    });
    _save();
  }

  @override
  Widget build(BuildContext context) {
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
                      'Custom Commands',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Commands that run in the worktree directory',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              SettingsAddButton(
                label: 'Add Command',
                color: AppColors.terminal,
                bgColor: AppColors.terminalBg,
                onTap: _addCommand,
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_commands.isEmpty)
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
                    Icons.terminal_rounded,
                    size: 32,
                    color: AppColors.textMuted.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No custom commands',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add commands to run them directly from worktree cards.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            )
          else
            ...List.generate(_commands.length, (index) {
              return _CustomCommandCard(
                key: ValueKey('cmd_$index'),
                command: _commands[index],
                index: index,
                onChanged: (cmd) {
                  setState(() => _commands[index] = cmd);
                  _save();
                },
                onRemove: () => _removeCommand(index),
              );
            }),
        ],
      ),
    );
  }
}

class _CustomCommandCard extends StatefulWidget {
  final CustomCommand command;
  final int index;
  final ValueChanged<CustomCommand> onChanged;
  final VoidCallback onRemove;

  const _CustomCommandCard({
    super.key,
    required this.command,
    required this.index,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_CustomCommandCard> createState() => _CustomCommandCardState();
}

class _CustomCommandCardState extends State<_CustomCommandCard> {
  late final TextEditingController _nameController;
  late final TextEditingController _commandController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.command.name);
    _commandController = TextEditingController(text: widget.command.command);
  }

  @override
  void didUpdateWidget(_CustomCommandCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The parent keys these cards by index, so when a command is removed the
    // surviving State objects are reused for different commands. Re-sync the
    // controllers whenever the underlying command no longer matches.
    if (widget.command.name != _nameController.text) {
      _nameController.text = widget.command.name;
    }
    if (widget.command.command != _commandController.text) {
      _commandController.text = widget.command.command;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _commandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveIcon = getCommandIcon(widget.command.iconName);
    final effectiveColor = getCommandColor(
      widget.command.colorHex,
      widget.index,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface0,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Icon + color pickers
              IconColorPicker(
                icon: effectiveIcon,
                color: effectiveColor,
                iconName: widget.command.iconName,
                colorHex: widget.command.colorHex,
                onIconChanged: (name) =>
                    widget.onChanged(widget.command.copyWith(iconName: name)),
                onColorChanged: (hex) =>
                    widget.onChanged(widget.command.copyWith(colorHex: hex)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NAME',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 300,
                      child: TextField(
                        style: appFormFieldTextStyle(context),
                        decoration: const InputDecoration(
                          hintText: 'e.g. Start Dev Server',
                        ),
                        controller: _nameController,
                        onChanged: (v) =>
                            widget.onChanged(widget.command.copyWith(name: v)),
                      ),
                    ),
                  ],
                ),
              ),
              SettingsRemoveButton(onTap: widget.onRemove),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'COMMAND',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            style: appFormFieldTextStyle(context, monospace: true, height: 1.5),
            maxLines: 6,
            minLines: 3,
            decoration: InputDecoration(
              hintText:
                  'e.g. dotnet run --project ./src\nor a multi-line script...',
              hintStyle: appFormFieldHintStyle(context, monospace: true),
            ),
            controller: _commandController,
            onChanged: (v) =>
                widget.onChanged(widget.command.copyWith(command: v)),
          ),
        ],
      ),
    );
  }
}
