import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_form_fields.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/builds/domain/azure_devops_config.dart';
import 'package:tree_launcher/features/builds/presentation/controllers/builds_controller.dart';
import 'package:tree_launcher/features/workspace/domain/command_style.dart';
import 'package:tree_launcher/features/workspace/domain/copilot_prompt.dart';
import 'package:tree_launcher/features/workspace/domain/custom_command.dart';
import 'package:tree_launcher/features/workspace/domain/custom_link.dart';
import 'package:tree_launcher/features/workspace/domain/vscode_config.dart';
import 'package:tree_launcher/providers/repo_provider.dart';

enum _SettingsSection { general, vscodeConfigs, customCommands, customLinks, copilotPrompts, builds }

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
                      icon: Icons.link_rounded,
                      label: 'Custom Links',
                      isSelected:
                          _selectedSection == _SettingsSection.customLinks,
                      onTap: () => setState(
                        () =>
                            _selectedSection = _SettingsSection.customLinks,
                      ),
                    ),
                    _NavItem(
                      icon: Icons.auto_awesome_rounded,
                      label: 'Copilot Prompts',
                      isSelected:
                          _selectedSection == _SettingsSection.copilotPrompts,
                      onTap: () => setState(
                        () =>
                            _selectedSection = _SettingsSection.copilotPrompts,
                      ),
                    ),
                    _NavItem(
                      icon: Icons.build_circle_outlined,
                      label: 'Builds',
                      isSelected:
                          _selectedSection == _SettingsSection.builds,
                      onTap: () => setState(
                        () =>
                            _selectedSection = _SettingsSection.builds,
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
      case _SettingsSection.customLinks:
        return const _CustomLinksSection();
      case _SettingsSection.copilotPrompts:
        return const _CopilotPromptsSection();
      case _SettingsSection.builds:
        return const _BuildsSection();
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

// --- Custom Links Section ---

class _CustomLinksSection extends StatefulWidget {
  const _CustomLinksSection();

  @override
  State<_CustomLinksSection> createState() => _CustomLinksSectionState();
}

class _CustomLinksSectionState extends State<_CustomLinksSection> {
  late List<CustomLink> _links;
  String? _lastRepoPath;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final repo = context.read<RepoProvider>().selectedRepo;
    _lastRepoPath = repo?.path;
    _links = List.from(repo?.customLinks ?? []);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repo = context.read<RepoProvider>().selectedRepo;
    if (repo != null && repo.path != _lastRepoPath) {
      _lastRepoPath = repo.path;
      _links = List.from(repo.customLinks);
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
      final cleaned = _links
          .where((l) => l.name.trim().isNotEmpty || l.url.trim().isNotEmpty)
          .map(
            (l) => CustomLink(
              name: l.name.trim(),
              url: l.url.trim(),
              iconName: l.iconName,
              colorHex: l.colorHex,
            ),
          )
          .toList();
      provider.updateRepoCustomLinks(repo, cleaned);
    });
  }

  void _addLink() {
    setState(() {
      _links.add(CustomLink(name: '', url: ''));
    });
  }

  void _removeLink(int index) {
    setState(() {
      _links.removeAt(index);
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
                      'Custom Links',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'URLs that open in your browser with {{SLOT}} substitution',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              _AddButton(
                label: 'Add Link',
                color: AppColors.accent,
                bgColor: AppColors.accentMuted,
                onTap: _addLink,
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_links.isEmpty)
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
                    Icons.link_rounded,
                    size: 32,
                    color: AppColors.textMuted.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No custom links',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add links to open them directly from worktree cards.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            )
          else
            ...List.generate(_links.length, (index) {
              return _CustomLinkCard(
                key: ValueKey('link_$index'),
                link: _links[index],
                index: index,
                onChanged: (link) {
                  setState(() => _links[index] = link);
                  _save();
                },
                onRemove: () => _removeLink(index),
              );
            }),
        ],
      ),
    );
  }
}

class _CustomLinkCard extends StatefulWidget {
  final CustomLink link;
  final int index;
  final ValueChanged<CustomLink> onChanged;
  final VoidCallback onRemove;

  const _CustomLinkCard({
    super.key,
    required this.link,
    required this.index,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_CustomLinkCard> createState() => _CustomLinkCardState();
}

class _CustomLinkCardState extends State<_CustomLinkCard> {
  late final TextEditingController _nameController;
  late final TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.link.name);
    _urlController = TextEditingController(text: widget.link.url);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveIcon = getCommandIcon(widget.link.iconName);
    final effectiveColor = getCommandColor(
      widget.link.colorHex,
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
              _IconColorPicker(
                icon: effectiveIcon,
                color: effectiveColor,
                iconName: widget.link.iconName,
                colorHex: widget.link.colorHex,
                onIconChanged: (name) =>
                    widget.onChanged(widget.link.copyWith(iconName: name)),
                onColorChanged: (hex) =>
                    widget.onChanged(widget.link.copyWith(colorHex: hex)),
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
                          hintText: 'e.g. Dashboard',
                        ),
                        controller: _nameController,
                        onChanged: (v) =>
                            widget.onChanged(widget.link.copyWith(name: v)),
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
            'URL',
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
            maxLines: 2,
            minLines: 1,
            decoration: InputDecoration(
              hintText: 'e.g. https://example.com/{{SLOT}}/dashboard',
              hintStyle: appFormFieldHintStyle(context, monospace: true),
            ),
            controller: _urlController,
            onChanged: (v) =>
                widget.onChanged(widget.link.copyWith(url: v)),
          ),
        ],
      ),
    );
  }
}

// --- Copilot Prompts Section ---

class _CopilotPromptsSection extends StatefulWidget {
  const _CopilotPromptsSection();

  @override
  State<_CopilotPromptsSection> createState() => _CopilotPromptsSectionState();
}

class _CopilotPromptsSectionState extends State<_CopilotPromptsSection> {
  late List<CopilotPrompt> _prompts;
  String? _lastRepoPath;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final repo = context.read<RepoProvider>().selectedRepo;
    _lastRepoPath = repo?.path;
    _prompts = List.from(repo?.copilotPrompts ?? []);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repo = context.read<RepoProvider>().selectedRepo;
    if (repo != null && repo.path != _lastRepoPath) {
      _lastRepoPath = repo.path;
      _prompts = List.from(repo.copilotPrompts);
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
            (p) => CopilotPrompt(name: p.name.trim(), prompt: p.prompt.trim()),
          )
          .toList();
      provider.updateRepoCopilotPrompts(repo, cleaned);
    });
  }

  void _addPrompt() {
    setState(() {
      _prompts.add(CopilotPrompt(name: '', prompt: ''));
    });
  }

  void _removePrompt(int index) {
    setState(() {
      _prompts.removeAt(index);
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
                      'Copilot Prompts',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Prompt templates for Copilot sessions. Use {issue} for JIRA issue substitution.',
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
                color: AppColors.copilot,
                bgColor: AppColors.copilotBg,
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
                    'No copilot prompts',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add prompt templates to use when creating worktrees.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            )
          else
            ...List.generate(_prompts.length, (index) {
              return _CopilotPromptCard(
                key: ValueKey('prompt_$index'),
                prompt: _prompts[index],
                onChanged: (p) {
                  setState(() => _prompts[index] = p);
                  _save();
                },
                onRemove: () => _removePrompt(index),
              );
            }),
        ],
      ),
    );
  }
}

class _CopilotPromptCard extends StatefulWidget {
  final CopilotPrompt prompt;
  final ValueChanged<CopilotPrompt> onChanged;
  final VoidCallback onRemove;

  const _CopilotPromptCard({
    super.key,
    required this.prompt,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_CopilotPromptCard> createState() => _CopilotPromptCardState();
}

class _CopilotPromptCardState extends State<_CopilotPromptCard> {
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
                          hintText: 'e.g. Analyse Jira Issue',
                        ),
                        controller: _nameController,
                        onChanged: (v) =>
                            widget.onChanged(widget.prompt.copyWith(name: v)),
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
            'PROMPT',
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
                  'e.g. Retrieve the jira issue {issue} with comments and files.\n'
                  'Analyse the issue and find a solution.',
              hintStyle: appFormFieldHintStyle(context, monospace: true),
            ),
            controller: _promptController,
            onChanged: (v) =>
                widget.onChanged(widget.prompt.copyWith(prompt: v)),
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

// --- Builds Section ---

class _BuildsSection extends StatefulWidget {
  const _BuildsSection();

  @override
  State<_BuildsSection> createState() => _BuildsSectionState();
}

class _BuildsSectionState extends State<_BuildsSection> {
  late TextEditingController _serverUrlController;
  late TextEditingController _projectController;
  late TextEditingController _patController;
  String? _lastRepoPath;
  Timer? _debounce;
  Set<int> _selectedPipelineIds = {};
  bool _pipelinesLoaded = false;

  @override
  void initState() {
    super.initState();
    final repo = context.read<RepoProvider>().selectedRepo;
    _lastRepoPath = repo?.path;
    final config = repo?.azureDevopsConfig;
    _serverUrlController = TextEditingController(text: config?.serverUrl ?? '');
    _projectController = TextEditingController(text: config?.project ?? '');
    _patController = TextEditingController(text: config?.pat ?? '');
    _selectedPipelineIds = config?.selectedPipelines.map((p) => p.id).toSet() ?? {};
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repo = context.read<RepoProvider>().selectedRepo;
    if (repo != null && repo.path != _lastRepoPath) {
      _lastRepoPath = repo.path;
      final config = repo.azureDevopsConfig;
      _serverUrlController.text = config?.serverUrl ?? '';
      _projectController.text = config?.project ?? '';
      _patController.text = config?.pat ?? '';
      _selectedPipelineIds = config?.selectedPipelines.map((p) => p.id).toSet() ?? {};
      _pipelinesLoaded = false;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _serverUrlController.dispose();
    _projectController.dispose();
    _patController.dispose();
    super.dispose();
  }

  void _saveConfig() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final provider = context.read<RepoProvider>();
      final repo = provider.selectedRepo;
      if (repo == null) return;

      final builds = context.read<BuildsController>();
      final currentPipelines = builds.availableDefinitions
          .where((d) => _selectedPipelineIds.contains(d.id))
          .map((d) => BuildPipelineRef(id: d.id, name: d.name))
          .toList();

      // Keep previously saved pipelines that are still selected but not in availableDefinitions
      final existingPipelines = repo.azureDevopsConfig?.selectedPipelines ?? [];
      final fetchedIds = builds.availableDefinitions.map((d) => d.id).toSet();
      for (final p in existingPipelines) {
        if (_selectedPipelineIds.contains(p.id) && !fetchedIds.contains(p.id)) {
          currentPipelines.add(p);
        }
      }

      final config = AzureDevopsConfig(
        serverUrl: _serverUrlController.text.trim(),
        project: _projectController.text.trim(),
        pat: _patController.text.trim(),
        selectedPipelines: currentPipelines,
      );
      provider.updateAzureDevopsConfig(repo, config);
    });
  }

  void _fetchPipelines() {
    final config = AzureDevopsConfig(
      serverUrl: _serverUrlController.text.trim(),
      project: _projectController.text.trim(),
      pat: _patController.text.trim(),
    );
    if (!config.isConfigured) return;
    context.read<BuildsController>().fetchDefinitions(config).then((_) {
      setState(() => _pipelinesLoaded = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final builds = context.watch<BuildsController>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Azure DevOps Builds',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Configure Azure DevOps connection and select build pipelines',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 24),

          // Server URL
          Text(
            'SERVER URL',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _serverUrlController,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
              hintText: 'https://dev.azure.com/your-org',
              hintStyle: TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                fontFamily: 'monospace',
              ),
            ),
            onChanged: (_) => _saveConfig(),
          ),
          const SizedBox(height: 16),

          // Project
          Text(
            'PROJECT',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _projectController,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
              hintText: 'MyProject',
              hintStyle: TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                fontFamily: 'monospace',
              ),
            ),
            onChanged: (_) => _saveConfig(),
          ),
          const SizedBox(height: 16),

          // PAT Token
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
            controller: _patController,
            obscureText: true,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
              hintText: 'PAT token with Build read & execute scope',
              hintStyle: TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                fontFamily: 'monospace',
              ),
            ),
            onChanged: (_) => _saveConfig(),
          ),
          const SizedBox(height: 24),

          // Fetch Pipelines button
          Row(
            children: [
              GestureDetector(
                onTap: builds.isFetchingDefinitions ? null : _fetchPipelines,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: builds.isFetchingDefinitions
                        ? AppColors.accent.withValues(alpha: 0.5)
                        : AppColors.accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: builds.isFetchingDefinitions
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.base,
                          ),
                        )
                      : Text(
                          'Fetch Pipelines',
                          style: TextStyle(
                            color: AppColors.base,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              if (builds.definitionsError != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    builds.definitionsError!,
                    style: TextStyle(color: AppColors.error, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Pipeline selection list
          if (_pipelinesLoaded && builds.availableDefinitions.isNotEmpty) ...[
            Text(
              'SELECT PIPELINES',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 400),
              decoration: BoxDecoration(
                color: AppColors.surface0,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: builds.availableDefinitions.length,
                itemBuilder: (context, index) {
                  final def = builds.availableDefinitions[index];
                  final isSelected = _selectedPipelineIds.contains(def.id);
                  return InkWell(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedPipelineIds.remove(def.id);
                        } else {
                          _selectedPipelineIds.add(def.id);
                        }
                      });
                      _saveConfig();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        border: index < builds.availableDefinitions.length - 1
                            ? Border(
                                bottom: BorderSide(
                                    color: AppColors.borderSubtle, width: 0.5),
                              )
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.check_box_rounded
                                : Icons.check_box_outline_blank_rounded,
                            size: 18,
                            color: isSelected
                                ? AppColors.accent
                                : AppColors.textMuted,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  def.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                if (def.path != null &&
                                    def.path!.isNotEmpty &&
                                    def.path != '\\')
                                  Text(
                                    def.path!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],

          if (_pipelinesLoaded && builds.availableDefinitions.isEmpty && builds.definitionsError == null) ...[
            const SizedBox(height: 8),
            Text(
              'No pipeline definitions found in this project.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}
