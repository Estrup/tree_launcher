import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_form_fields.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/github_prs/domain/github_config.dart';
import 'package:tree_launcher/features/workspace/domain/command_style.dart';
import 'package:tree_launcher/features/workspace/domain/claude_prompt.dart';
import 'package:tree_launcher/features/workspace/domain/custom_command.dart';
import 'package:tree_launcher/features/workspace/domain/vscode_config.dart';
import 'package:tree_launcher/models/predefined_issue.dart';
import 'package:tree_launcher/providers/repo_provider.dart';

enum _SettingsSection {
  general,
  vscodeConfigs,
  customCommands,
  claudePrompts,
  predefinedIssues,
  github,
  jira,
}

class RepoSettingsView extends StatefulWidget {
  const RepoSettingsView({super.key});

  @override
  State<RepoSettingsView> createState() => _RepoSettingsViewState();
}

class _RepoSettingsViewState extends State<RepoSettingsView> {
  _SettingsSection _selectedSection = _SettingsSection.general;

  @override
  Widget build(BuildContext context) {
    final repoProvider = context.watch<RepoProvider>();
    final repo = repoProvider.selectedRepo;

    return Column(
      children: [
        // Full-width header
        Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: AppColors.surface0,
            border: Border(
              bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
            ),
          ),
          child: Row(
            children: [
              _BackButton(onTap: () => repoProvider.closeSettings()),
              const SizedBox(width: 12),
              Text(
                repo != null ? repo.name : 'Repository Settings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Body: nav + content
        Expanded(
          child: Row(
            children: [
              // Left nav menu
              Container(
                width: 200,
                decoration: BoxDecoration(
                  color: AppColors.surface0,
                  border: Border(
                    right: BorderSide(color: AppColors.borderSubtle, width: 1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                      child: Text(
                        'SETTINGS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted.withValues(alpha: 0.7),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    _NavItem(
                      icon: Icons.info_outline_rounded,
                      label: 'General',
                      isSelected: _selectedSection == _SettingsSection.general,
                      onTap: () => setState(
                        () => _selectedSection = _SettingsSection.general,
                      ),
                    ),
                    _NavItem(
                      icon: Icons.code_rounded,
                      label: 'VS Code Configs',
                      isSelected:
                          _selectedSection == _SettingsSection.vscodeConfigs,
                      onTap: () => setState(
                        () => _selectedSection = _SettingsSection.vscodeConfigs,
                      ),
                    ),
                    _NavItem(
                      icon: Icons.terminal_rounded,
                      label: 'Custom Commands',
                      isSelected:
                          _selectedSection == _SettingsSection.customCommands,
                      onTap: () => setState(
                        () =>
                            _selectedSection = _SettingsSection.customCommands,
                      ),
                    ),
                    _NavItem(
                      icon: Icons.auto_awesome_rounded,
                      label: 'Claude Prompts',
                      isSelected:
                          _selectedSection == _SettingsSection.claudePrompts,
                      onTap: () => setState(
                        () =>
                            _selectedSection = _SettingsSection.claudePrompts,
                      ),
                    ),
                    _NavItem(
                      icon: Icons.confirmation_number_outlined,
                      label: 'Issue Keys',
                      isSelected:
                          _selectedSection == _SettingsSection.predefinedIssues,
                      onTap: () => setState(
                        () => _selectedSection =
                            _SettingsSection.predefinedIssues,
                      ),
                    ),
                    _NavItem(
                      icon: Icons.merge_type_rounded,
                      label: 'GitHub',
                      isSelected:
                          _selectedSection == _SettingsSection.github,
                      onTap: () => setState(
                        () =>
                            _selectedSection = _SettingsSection.github,
                      ),
                    ),
                    _NavItem(
                      icon: Icons.confirmation_number_rounded,
                      label: 'Jira',
                      isSelected: _selectedSection == _SettingsSection.jira,
                      onTap: () => setState(
                        () => _selectedSection = _SettingsSection.jira,
                      ),
                    ),
                  ],
                ),
              ),
              // Right content area
              Expanded(child: _buildContent(context)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (_selectedSection) {
      case _SettingsSection.general:
        return const _GeneralSection();
      case _SettingsSection.vscodeConfigs:
        return const _VscodeConfigsSection();
      case _SettingsSection.customCommands:
        return const _CustomCommandsSection();
      case _SettingsSection.claudePrompts:
        return const _ClaudePromptsSection();
      case _SettingsSection.predefinedIssues:
        return const _PredefinedIssuesSection();
      case _SettingsSection.github:
        return const _GithubSection();
      case _SettingsSection.jira:
        return const _JiraSection();
    }
  }
}

// --- Nav Item ---

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppColors.surface2
                : _hovered
                ? AppColors.surface1
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 16,
                color: widget.isSelected
                    ? AppColors.accent
                    : AppColors.textMuted,
              ),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: widget.isSelected
                      ? FontWeight.w600
                      : FontWeight.w500,
                  color: widget.isSelected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- General Section ---

class _GeneralSection extends StatefulWidget {
  const _GeneralSection();

  @override
  State<_GeneralSection> createState() => _GeneralSectionState();
}

class _GeneralSectionState extends State<_GeneralSection> {
  late TextEditingController _nameController;
  Timer? _debounce;
  String? _lastRepoPath;

  @override
  void initState() {
    super.initState();
    final repo = context.read<RepoProvider>().selectedRepo;
    _lastRepoPath = repo?.path;
    _nameController = TextEditingController(text: repo?.name ?? '');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repo = context.read<RepoProvider>().selectedRepo;
    if (repo != null && repo.path != _lastRepoPath) {
      _lastRepoPath = repo.path;
      _nameController.text = repo.name;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    super.dispose();
  }

  void _onNameChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final name = value.trim();
      if (name.isEmpty) return;
      final provider = context.read<RepoProvider>();
      final repo = provider.selectedRepo;
      if (repo != null && name != repo.name) {
        provider.renameRepo(repo, name);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<RepoProvider>().selectedRepo;
    if (repo == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'General',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Basic repository configuration',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'DISPLAY NAME',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 400,
            child: TextField(
              controller: _nameController,
              style: appFormFieldTextStyle(context),
              decoration: const InputDecoration(hintText: 'Repository name'),
              onChanged: _onNameChanged,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'PATH',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 400,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface0,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Text(
              repo.path,
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'WORKTREE LOCATION',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 400,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nest worktrees in .worktrees/ subfolder',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'When on, new worktrees are created inside the repo '
                        'and kept out of git status. When off, they are created '
                        'alongside the repo. Does not apply to bare repos.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Switch.adaptive(
                  value: repo.useNestedWorktrees,
                  onChanged: (value) {
                    context.read<RepoProvider>().updateUseNestedWorktrees(
                      repo,
                      value,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- VS Code Configs Section ---

class _VscodeConfigsSection extends StatefulWidget {
  const _VscodeConfigsSection();

  @override
  State<_VscodeConfigsSection> createState() => _VscodeConfigsSectionState();
}

class _VscodeConfigsSectionState extends State<_VscodeConfigsSection> {
  late List<VscodeConfig> _configs;
  String? _lastRepoPath;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final repo = context.read<RepoProvider>().selectedRepo;
    _lastRepoPath = repo?.path;
    _configs = List.from(repo?.vscodeConfigs ?? []);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repo = context.read<RepoProvider>().selectedRepo;
    if (repo != null && repo.path != _lastRepoPath) {
      _lastRepoPath = repo.path;
      _configs = List.from(repo.vscodeConfigs);
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
      final provider = context.read<RepoProvider>();
      final repo = provider.selectedRepo;
      if (repo == null) return;
      final cleaned = _configs
          .where((c) => c.name.trim().isNotEmpty || c.path.trim().isNotEmpty)
          .map((c) => VscodeConfig(name: c.name.trim(), path: c.path.trim()))
          .toList();
      provider.updateRepoVscodeConfigs(repo, cleaned);
    });
  }

  void _addConfig() {
    setState(() {
      _configs.add(VscodeConfig(name: '', path: ''));
    });
  }

  void _removeConfig(int index) {
    setState(() {
      _configs.removeAt(index);
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
                      'VS Code Configs',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Configure VS Code workspace paths relative to the worktree directory',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              _AddButton(
                label: 'Add Config',
                color: AppColors.vscode,
                bgColor: AppColors.vscodeBg,
                onTap: _addConfig,
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_configs.isEmpty)
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
                    Icons.code_rounded,
                    size: 32,
                    color: AppColors.textMuted.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No VS Code configs',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'The VS Code button will open the worktree root by default.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            )
          else
            ...List.generate(_configs.length, (index) {
              return _VscodeConfigCard(
                key: ValueKey('vsc_$index'),
                config: _configs[index],
                onChanged: (config) {
                  setState(() => _configs[index] = config);
                  _save();
                },
                onRemove: () => _removeConfig(index),
              );
            }),
        ],
      ),
    );
  }
}

class _VscodeConfigCard extends StatefulWidget {
  final VscodeConfig config;
  final ValueChanged<VscodeConfig> onChanged;
  final VoidCallback onRemove;

  const _VscodeConfigCard({
    super.key,
    required this.config,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_VscodeConfigCard> createState() => _VscodeConfigCardState();
}

class _VscodeConfigCardState extends State<_VscodeConfigCard> {
  late final TextEditingController _nameController;
  late final TextEditingController _pathController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.config.name);
    _pathController = TextEditingController(text: widget.config.path);
  }

  @override
  void didUpdateWidget(_VscodeConfigCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Cards are keyed by index, so removing one reuses State for a different
    // config. Re-sync controllers when the underlying config differs.
    if (widget.config.name != _nameController.text) {
      _nameController.text = widget.config.name;
    }
    if (widget.config.path != _pathController.text) {
      _pathController.text = widget.config.path;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface0,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name field
          SizedBox(
            width: 180,
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
                TextField(
                  style: appFormFieldTextStyle(context),
                  decoration: const InputDecoration(hintText: 'e.g. Frontend'),
                  controller: _nameController,
                  onChanged: (v) => widget.onChanged(
                    VscodeConfig(name: v, path: widget.config.path),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Path field
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PATH',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  style: appFormFieldTextStyle(context, monospace: true),
                  decoration: InputDecoration(
                    hintText: 'Relative path (e.g. frontend/)',
                    hintStyle: appFormFieldHintStyle(context, monospace: true),
                  ),
                  controller: _pathController,
                  onChanged: (v) => widget.onChanged(
                    VscodeConfig(name: widget.config.name, path: v),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Remove button
          Padding(
            padding: const EdgeInsets.only(top: 22),
            child: _RemoveButton(onTap: widget.onRemove),
          ),
        ],
      ),
    );
  }
}

// --- Custom Commands Section ---

class _CustomCommandsSection extends StatefulWidget {
  const _CustomCommandsSection();

  @override
  State<_CustomCommandsSection> createState() => _CustomCommandsSectionState();
}

class _CustomCommandsSectionState extends State<_CustomCommandsSection> {
  late List<CustomCommand> _commands;
  String? _lastRepoPath;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final repo = context.read<RepoProvider>().selectedRepo;
    _lastRepoPath = repo?.path;
    _commands = List.from(repo?.customCommands ?? []);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repo = context.read<RepoProvider>().selectedRepo;
    if (repo != null && repo.path != _lastRepoPath) {
      _lastRepoPath = repo.path;
      _commands = List.from(repo.customCommands);
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
      final provider = context.read<RepoProvider>();
      final repo = provider.selectedRepo;
      if (repo == null) return;
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
              _AddButton(
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
              _IconColorPicker(
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
              _RemoveButton(onTap: widget.onRemove),
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

// --- Claude Prompts Section ---

class _ClaudePromptsSection extends StatefulWidget {
  const _ClaudePromptsSection();

  @override
  State<_ClaudePromptsSection> createState() => _ClaudePromptsSectionState();
}

class _ClaudePromptsSectionState extends State<_ClaudePromptsSection> {
  late List<ClaudePrompt> _prompts;
  String? _lastRepoPath;
  Timer? _debounce;

  /// Index of the prompt open in the editor; null shows the list.
  int? _editingIndex;

  @override
  void initState() {
    super.initState();
    final repo = context.read<RepoProvider>().selectedRepo;
    _lastRepoPath = repo?.path;
    _prompts = List.from(repo?.claudePrompts ?? []);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repo = context.read<RepoProvider>().selectedRepo;
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
      final provider = context.read<RepoProvider>();
      final repo = provider.selectedRepo;
      if (repo == null) return;
      final cleaned = _prompts
          .where((p) => p.name.trim().isNotEmpty || p.prompt.trim().isNotEmpty)
          .map(
            (p) => ClaudePrompt(name: p.name.trim(), prompt: p.prompt.trim()),
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
                      'Substitutions: {issue}, {pr}, {base_branch}, {worktree}, {path}, {repo}.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              _AddButton(
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
              _RemoveButton(onTap: widget.onRemove),
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
              _BackButton(onTap: widget.onBack),
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

// --- Predefined Issues Section ---

class _PredefinedIssuesSection extends StatefulWidget {
  const _PredefinedIssuesSection();

  @override
  State<_PredefinedIssuesSection> createState() =>
      _PredefinedIssuesSectionState();
}

class _PredefinedIssuesSectionState extends State<_PredefinedIssuesSection> {
  late List<PredefinedIssue> _issues;
  String? _lastRepoPath;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final repo = context.read<RepoProvider>().selectedRepo;
    _lastRepoPath = repo?.path;
    _issues = List.from(repo?.predefinedIssues ?? []);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repo = context.read<RepoProvider>().selectedRepo;
    if (repo != null && repo.path != _lastRepoPath) {
      _lastRepoPath = repo.path;
      _issues = List.from(repo.predefinedIssues);
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
      final provider = context.read<RepoProvider>();
      final repo = provider.selectedRepo;
      if (repo == null) return;
      final cleaned = _issues
          .where(
            (i) => i.key.trim().isNotEmpty || i.description.trim().isNotEmpty,
          )
          .map(
            (i) => PredefinedIssue(
              key: i.key.trim(),
              description: i.description.trim(),
            ),
          )
          .toList();
      provider.updateRepoPredefinedIssues(repo, cleaned);
    });
  }

  void _addIssue() {
    setState(() {
      _issues.add(PredefinedIssue(key: '', description: ''));
    });
  }

  void _removeIssue(int index) {
    setState(() {
      _issues.removeAt(index);
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
                      'Issue Keys',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Reusable issue keys and descriptions. Pick from these '
                      'when logging a manual activity post.',
                      style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              _AddButton(
                label: 'Add Issue',
                color: AppColors.accent,
                bgColor: AppColors.accent.withValues(alpha: 0.12),
                onTap: _addIssue,
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_issues.isEmpty)
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
                    Icons.confirmation_number_outlined,
                    size: 32,
                    color: AppColors.textMuted.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No issue keys',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add issue keys to pick from when logging manual posts.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            )
          else
            ...List.generate(_issues.length, (index) {
              return _PredefinedIssueCard(
                key: ValueKey('issue_$index'),
                issue: _issues[index],
                onChanged: (i) {
                  setState(() => _issues[index] = i);
                  _save();
                },
                onRemove: () => _removeIssue(index),
              );
            }),
        ],
      ),
    );
  }
}

class _PredefinedIssueCard extends StatefulWidget {
  final PredefinedIssue issue;
  final ValueChanged<PredefinedIssue> onChanged;
  final VoidCallback onRemove;

  const _PredefinedIssueCard({
    super.key,
    required this.issue,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_PredefinedIssueCard> createState() => _PredefinedIssueCardState();
}

class _PredefinedIssueCardState extends State<_PredefinedIssueCard> {
  late final TextEditingController _keyController;
  late final TextEditingController _descController;

  @override
  void initState() {
    super.initState();
    _keyController = TextEditingController(text: widget.issue.key);
    _descController = TextEditingController(text: widget.issue.description);
  }

  @override
  void didUpdateWidget(_PredefinedIssueCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Cards are keyed by index, so removing one reuses State for a different
    // issue. Re-sync controllers when the underlying issue differs.
    if (widget.issue.key != _keyController.text) {
      _keyController.text = widget.issue.key;
    }
    if (widget.issue.description != _descController.text) {
      _descController.text = widget.issue.description;
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface0,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'KEY',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 160,
                child: TextField(
                  style: appFormFieldTextStyle(context),
                  decoration: const InputDecoration(hintText: 'e.g. AU2-1234'),
                  controller: _keyController,
                  onChanged: (v) =>
                      widget.onChanged(widget.issue.copyWith(key: v)),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DESCRIPTION',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  style: appFormFieldTextStyle(context),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Fix login redirect loop',
                  ),
                  controller: _descController,
                  onChanged: (v) =>
                      widget.onChanged(widget.issue.copyWith(description: v)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(top: 22),
            child: _RemoveButton(onTap: widget.onRemove),
          ),
        ],
      ),
    );
  }
}

/// Combined icon + color picker displayed as a clickable icon button.
class _IconColorPicker extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String? iconName;
  final String? colorHex;
  final ValueChanged<String> onIconChanged;
  final ValueChanged<String> onColorChanged;

  const _IconColorPicker({
    required this.icon,
    required this.color,
    required this.iconName,
    required this.colorHex,
    required this.onIconChanged,
    required this.onColorChanged,
  });

  @override
  State<_IconColorPicker> createState() => _IconColorPickerState();
}

class _IconColorPickerState extends State<_IconColorPicker> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Change icon & color',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: () => _showPicker(context),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _hovered
                  ? widget.color.withValues(alpha: 0.2)
                  : widget.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: widget.color.withValues(alpha: _hovered ? 0.5 : 0.25),
              ),
            ),
            child: Center(
              child: Icon(widget.icon, size: 20, color: widget.color),
            ),
          ),
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _IconColorPickerDialog(
        currentIconName: widget.iconName,
        currentColorHex: widget.colorHex,
        onIconChanged: widget.onIconChanged,
        onColorChanged: widget.onColorChanged,
      ),
    );
  }
}

class _IconColorPickerDialog extends StatefulWidget {
  final String? currentIconName;
  final String? currentColorHex;
  final ValueChanged<String> onIconChanged;
  final ValueChanged<String> onColorChanged;

  const _IconColorPickerDialog({
    required this.currentIconName,
    required this.currentColorHex,
    required this.onIconChanged,
    required this.onColorChanged,
  });

  @override
  State<_IconColorPickerDialog> createState() => _IconColorPickerDialogState();
}

class _IconColorPickerDialogState extends State<_IconColorPickerDialog> {
  late String? _selectedIcon;
  late String? _selectedColor;

  @override
  void initState() {
    super.initState();
    _selectedIcon = widget.currentIconName;
    _selectedColor = widget.currentColorHex;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border),
      ),
      title: Text(
        'Icon & Color',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ICON',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: commandIconMap.entries.map((entry) {
                final isSelected = entry.key == _selectedIcon;
                final previewColor = getCommandColor(_selectedColor, 0);
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedIcon = entry.key);
                    widget.onIconChanged(entry.key);
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? previewColor.withValues(alpha: 0.2)
                          : AppColors.surface0,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected
                            ? previewColor
                            : AppColors.borderSubtle,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        entry.value,
                        size: 18,
                        color: isSelected
                            ? previewColor
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Text(
              'COLOR',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(commandColorHexPalette.length, (i) {
                final hex = commandColorHexPalette[i];
                final color = commandColorPalette[i];
                final isSelected = hex == _selectedColor;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedColor = hex);
                    widget.onColorChanged(hex);
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.textPrimary
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: isSelected
                        ? const Center(
                            child: Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                );
              }),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Done', style: TextStyle(color: AppColors.accent)),
        ),
      ],
    );
  }
}

// --- Shared widgets ---

class _AddButton extends StatefulWidget {
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _AddButton({
    required this.label,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _hovered
                ? widget.color.withValues(alpha: 0.15)
                : widget.bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.color.withValues(alpha: _hovered ? 0.4 : 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, size: 14, color: widget.color),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RemoveButton extends StatefulWidget {
  final VoidCallback onTap;
  const _RemoveButton({required this.onTap});

  @override
  State<_RemoveButton> createState() => _RemoveButtonState();
}

class _RemoveButtonState extends State<_RemoveButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.error.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            Icons.close_rounded,
            size: 16,
            color: _hovered ? AppColors.error : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatefulWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.surface2 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.arrow_back_rounded,
            size: 20,
            color: _hovered ? AppColors.textPrimary : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _GithubSection extends StatefulWidget {
  const _GithubSection();

  @override
  State<_GithubSection> createState() => _GithubSectionState();
}

class _GithubSectionState extends State<_GithubSection> {
  late TextEditingController _ownerController;
  late TextEditingController _repoController;
  late TextEditingController _tokenController;
  late TextEditingController _intervalController;
  String? _lastRepoPath;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final repo = context.read<RepoProvider>().selectedRepo;
    _lastRepoPath = repo?.path;
    final config = repo?.githubConfig;
    _ownerController = TextEditingController(text: config?.owner ?? '');
    _repoController = TextEditingController(text: config?.repo ?? '');
    _tokenController = TextEditingController(text: config?.token ?? '');
    _intervalController = TextEditingController(
      text: (config?.prRefreshIntervalMinutes ?? 5).toString(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repo = context.read<RepoProvider>().selectedRepo;
    if (repo != null && repo.path != _lastRepoPath) {
      _lastRepoPath = repo.path;
      final config = repo.githubConfig;
      _ownerController.text = config?.owner ?? '';
      _repoController.text = config?.repo ?? '';
      _tokenController.text = config?.token ?? '';
      _intervalController.text =
          (config?.prRefreshIntervalMinutes ?? 5).toString();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ownerController.dispose();
    _repoController.dispose();
    _tokenController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  void _saveConfig() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final provider = context.read<RepoProvider>();
      final repo = provider.selectedRepo;
      if (repo == null) return;

      var owner = _ownerController.text.trim();
      final repoName = _repoController.text.trim();
      final token = _tokenController.text.trim();
      final interval =
          (int.tryParse(_intervalController.text.trim()) ?? 5).clamp(1, 1440);

      // Auto-parse if user pastes a full GitHub URL into the owner field
      if (owner.contains('github.com') && repoName.isEmpty) {
        final parsed = _parseGithubUrl(owner);
        if (parsed != null) {
          owner = parsed.$1;
          _ownerController.text = parsed.$1;
          _repoController.text = parsed.$2;
          final config = GithubConfig(
            owner: parsed.$1,
            repo: parsed.$2,
            token: token,
            prRefreshIntervalMinutes: interval,
          );
          provider.updateGithubConfig(repo, config);
          return;
        }
      }

      final config = (owner.isEmpty && repoName.isEmpty && token.isEmpty)
          ? null
          : GithubConfig(
              owner: owner,
              repo: repoName,
              token: token,
              prRefreshIntervalMinutes: interval,
            );
      provider.updateGithubConfig(repo, config);
    });
  }

  (String, String)? _parseGithubUrl(String input) {
    final uri = Uri.tryParse(input);
    if (uri != null && uri.host.contains('github.com')) {
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.length >= 2) {
        return (segments[0], segments[1]);
      }
    }
    // Try pattern: github.com/owner/repo
    final match = RegExp(r'github\.com/([^/]+)/([^/]+)').firstMatch(input);
    if (match != null) {
      return (match.group(1)!, match.group(2)!.replaceAll('.git', ''));
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GitHub Pull Requests',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Configure GitHub connection to view pull requests',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 24),

          // Owner
          Text(
            'OWNER',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _ownerController,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
              hintText: 'owner (or paste full GitHub URL)',
              hintStyle: TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                fontFamily: 'monospace',
              ),
            ),
            onChanged: (_) => _saveConfig(),
          ),
          const SizedBox(height: 16),

          // Repo
          Text(
            'REPOSITORY',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _repoController,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
              hintText: 'repository-name',
              hintStyle: TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                fontFamily: 'monospace',
              ),
            ),
            onChanged: (_) => _saveConfig(),
          ),
          const SizedBox(height: 16),

          // Token
          Text(
            'PERSONAL ACCESS TOKEN',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _tokenController,
            obscureText: true,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
              hintText: 'ghp_...',
              hintStyle: TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                fontFamily: 'monospace',
              ),
            ),
            onChanged: (_) => _saveConfig(),
          ),
          const SizedBox(height: 16),
          Text(
            'Create a token at GitHub → Settings → Developer settings → Personal access tokens.\n'
            'Requires the "repo" scope for private repositories.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          // Auto-refresh interval
          Text(
            'AUTO-REFRESH INTERVAL (MINUTES)',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 120,
            child: TextField(
              controller: _intervalController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                fontFamily: 'monospace',
              ),
              decoration: InputDecoration(
                hintText: '5',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                  fontFamily: 'monospace',
                ),
              ),
              onChanged: (_) => _saveConfig(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'How often the pull request list refreshes (minimum 1 minute). '
            'Refreshing runs in the background even when this tab is not open.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// --- Jira Section ---

class _JiraSection extends StatefulWidget {
  const _JiraSection();

  @override
  State<_JiraSection> createState() => _JiraSectionState();
}

class _JiraSectionState extends State<_JiraSection> {
  static final _projectKeyPattern = RegExp(r'^[A-Z][A-Z0-9_]+$');

  late TextEditingController _keyController;
  String? _lastRepoPath;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final repo = context.read<RepoProvider>().selectedRepo;
    _lastRepoPath = repo?.path;
    _keyController = TextEditingController(text: repo?.jiraProjectKey ?? '');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repo = context.read<RepoProvider>().selectedRepo;
    if (repo != null && repo.path != _lastRepoPath) {
      _lastRepoPath = repo.path;
      _keyController.text = repo.jiraProjectKey ?? '';
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _keyController.dispose();
    super.dispose();
  }

  String? get _keyError {
    final key = _keyController.text.trim();
    if (key.isEmpty || _projectKeyPattern.hasMatch(key)) return null;
    return 'Use the project key, e.g. AU2';
  }

  void _save() {
    setState(() {});
    _debounce?.cancel();
    if (_keyError != null) return;
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final provider = context.read<RepoProvider>();
      final repo = provider.selectedRepo;
      if (repo == null) return;
      provider.updateJiraProjectKey(repo, _keyController.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    final error = _keyError;
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
            'Show a Jira tab listing the project\'s issues by fixVersion',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),
          Text(
            'PROJECT KEY',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 200,
            child: TextField(
              controller: _keyController,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                TextInputFormatter.withFunction(
                  (oldValue, newValue) =>
                      newValue.copyWith(text: newValue.text.toUpperCase()),
                ),
              ],
              style: appFormFieldTextStyle(context, monospace: true),
              decoration: InputDecoration(
                hintText: 'e.g. AU2',
                hintStyle: appFormFieldHintStyle(context, monospace: true),
                errorText: error,
              ),
              onChanged: (_) => _save(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Leave empty to hide the Jira tab. Uses the token in '
            '~/.config/jira-pat.txt.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
