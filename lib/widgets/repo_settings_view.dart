import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/custom_command.dart';
import '../models/command_style.dart';
import '../models/vscode_config.dart';
import '../providers/repo_provider.dart';
import '../theme/app_theme.dart';

enum _SettingsSection { general, vscodeConfigs, customCommands }

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
          decoration: const BoxDecoration(
            color: AppColors.surface0,
            border: Border(
              bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
            ),
          ),
          child: Row(
            children: [
              _BackButton(
                onTap: () => repoProvider.closeSettings(),
              ),
              const SizedBox(width: 12),
              Text(
                repo != null ? repo.name : 'Repository Settings',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
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
                decoration: const BoxDecoration(
                  color: AppColors.surface0,
                  border: Border(
                    right:
                        BorderSide(color: AppColors.borderSubtle, width: 1),
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
                      isSelected:
                          _selectedSection == _SettingsSection.general,
                      onTap: () => setState(
                          () => _selectedSection = _SettingsSection.general),
                    ),
                    _NavItem(
                      icon: Icons.code_rounded,
                      label: 'VS Code Configs',
                      isSelected:
                          _selectedSection == _SettingsSection.vscodeConfigs,
                      onTap: () => setState(() =>
                          _selectedSection = _SettingsSection.vscodeConfigs),
                    ),
                    _NavItem(
                      icon: Icons.terminal_rounded,
                      label: 'Custom Commands',
                      isSelected:
                          _selectedSection == _SettingsSection.customCommands,
                      onTap: () => setState(() =>
                          _selectedSection = _SettingsSection.customCommands),
                    ),
                  ],
                ),
              ),
              // Right content area
              Expanded(
                child: _buildContent(context),
              ),
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
                  fontWeight:
                      widget.isSelected ? FontWeight.w600 : FontWeight.w500,
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
          const Text(
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
          const Text(
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
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Repository name',
                hintStyle: TextStyle(
                  color: AppColors.textMuted.withValues(alpha: 0.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.accent),
                ),
                filled: true,
                fillColor: AppColors.surface0,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              onChanged: _onNameChanged,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
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
              style: const TextStyle(
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
              const Expanded(
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
                  const Text(
                    'No VS Code configs',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'The VS Code button will open the worktree root by default.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
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

class _VscodeConfigCard extends StatelessWidget {
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
                const Text(
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
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. Frontend',
                    hintStyle: TextStyle(
                      color: AppColors.textMuted.withValues(alpha: 0.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: AppColors.vscode),
                    ),
                    filled: true,
                    fillColor: AppColors.surface1,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                  ),
                  controller: TextEditingController(text: config.name)
                    ..selection =
                        TextSelection.collapsed(offset: config.name.length),
                  onChanged: (v) =>
                      onChanged(VscodeConfig(name: v, path: config.path)),
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
                const Text(
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
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontFamily: 'monospace',
                  ),
                  decoration: InputDecoration(
                    hintText: 'Relative path (e.g. frontend/)',
                    hintStyle: TextStyle(
                      color: AppColors.textMuted.withValues(alpha: 0.5),
                      fontFamily: 'monospace',
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: AppColors.vscode),
                    ),
                    filled: true,
                    fillColor: AppColors.surface1,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                  ),
                  controller: TextEditingController(text: config.path)
                    ..selection =
                        TextSelection.collapsed(offset: config.path.length),
                  onChanged: (v) =>
                      onChanged(VscodeConfig(name: config.name, path: v)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Remove button
          Padding(
            padding: const EdgeInsets.only(top: 22),
            child: _RemoveButton(onTap: onRemove),
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
  State<_CustomCommandsSection> createState() =>
      _CustomCommandsSectionState();
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
          .where(
              (c) => c.name.trim().isNotEmpty || c.command.trim().isNotEmpty)
          .map((c) => CustomCommand(
                name: c.name.trim(),
                command: c.command.trim(),
                iconName: c.iconName,
                colorHex: c.colorHex,
              ))
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
              const Expanded(
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
                  const Text(
                    'No custom commands',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Add commands to run them directly from worktree cards.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
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

class _CustomCommandCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final effectiveIcon = getCommandIcon(command.iconName);
    final effectiveColor = getCommandColor(command.colorHex, index);

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
                iconName: command.iconName,
                colorHex: command.colorHex,
                onIconChanged: (name) =>
                    onChanged(command.copyWith(iconName: name)),
                onColorChanged: (hex) =>
                    onChanged(command.copyWith(colorHex: hex)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
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
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText: 'e.g. Start Dev Server',
                          hintStyle: TextStyle(
                            color: AppColors.textMuted.withValues(alpha: 0.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide:
                                const BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide:
                                const BorderSide(color: AppColors.terminal),
                          ),
                          filled: true,
                          fillColor: AppColors.surface1,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                        ),
                        controller: TextEditingController(text: command.name)
                          ..selection = TextSelection.collapsed(
                              offset: command.name.length),
                        onChanged: (v) =>
                            onChanged(command.copyWith(name: v)),
                      ),
                    ),
                  ],
                ),
              ),
              _RemoveButton(onTap: onRemove),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
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
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontFamily: 'monospace',
              height: 1.5,
            ),
            maxLines: 6,
            minLines: 3,
            decoration: InputDecoration(
              hintText:
                  'e.g. dotnet run --project ./src\nor a multi-line script...',
              hintStyle: TextStyle(
                color: AppColors.textMuted.withValues(alpha: 0.5),
                fontFamily: 'monospace',
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppColors.terminal),
              ),
              filled: true,
              fillColor: AppColors.surface1,
              contentPadding: const EdgeInsets.all(12),
            ),
            controller: TextEditingController(text: command.command)
              ..selection =
                  TextSelection.collapsed(offset: command.command.length),
            onChanged: (v) =>
                onChanged(command.copyWith(command: v)),
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
        side: const BorderSide(color: AppColors.border),
      ),
      title: const Text(
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
            const Text(
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
            const Text(
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
                        color:
                            isSelected ? AppColors.textPrimary : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: isSelected
                        ? const Center(
                            child: Icon(Icons.check_rounded,
                                size: 16, color: Colors.white),
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
          child: const Text(
            'Done',
            style: TextStyle(color: AppColors.accent),
          ),
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
