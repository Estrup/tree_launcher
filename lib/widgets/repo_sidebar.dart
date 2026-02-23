import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/custom_command.dart';
import '../models/repo_config.dart';
import '../models/vscode_config.dart';
import '../providers/repo_provider.dart';
import '../theme/app_theme.dart';

class RepoSidebar extends StatelessWidget {
  final VoidCallback onAddRepo;
  final VoidCallback onOpenSettings;

  const RepoSidebar({
    super.key,
    required this.onAddRepo,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final repoProvider = context.watch<RepoProvider>();

    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: AppColors.surface0,
        border: Border(
          right: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Logo / brand
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.accentMuted,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Icon(
                    Icons.account_tree_rounded,
                    size: 16,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'TreeLauncher',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),

          // Section label
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Row(
              children: [
                Text(
                  'REPOSITORIES',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted.withValues(alpha: 0.7),
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),

          // Repo list
          Expanded(
            child: repoProvider.repos.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 24),
                        Icon(
                          Icons.folder_open_rounded,
                          size: 36,
                          color: AppColors.textMuted.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No repos yet',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: repoProvider.repos.length,
                    itemBuilder: (context, index) {
                      final repo = repoProvider.repos[index];
                      final isSelected = repo == repoProvider.selectedRepo;
                      return _RepoTile(
                        repo: repo,
                        isSelected: isSelected,
                        onTap: () => repoProvider.selectRepo(repo),
                        onRemove: () =>
                            _confirmRemove(context, repoProvider, repo),
                        onSettings: () =>
                            _showRepoSettings(context, repoProvider, repo),
                      );
                    },
                  ),
          ),

          // Bottom bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.borderSubtle, width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _AddRepoButton(onPressed: onAddRepo),
                ),
                const SizedBox(width: 8),
                _SettingsButton(onPressed: onOpenSettings),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmRemove(
      BuildContext context, RepoProvider provider, RepoConfig repo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Repository'),
        content: Text('Remove "${repo.name}" from TreeLauncher?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              provider.removeRepo(repo);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showRepoSettings(
      BuildContext context, RepoProvider provider, RepoConfig repo) {
    showDialog(
      context: context,
      builder: (ctx) => _RepoSettingsDialog(repo: repo, provider: provider),
    );
  }
}

// --- Repo settings dialog ---

class _RepoSettingsDialog extends StatefulWidget {
  final RepoConfig repo;
  final RepoProvider provider;

  const _RepoSettingsDialog({required this.repo, required this.provider});

  @override
  State<_RepoSettingsDialog> createState() => _RepoSettingsDialogState();
}

class _RepoSettingsDialogState extends State<_RepoSettingsDialog> {
  late TextEditingController _nameController;
  late List<VscodeConfig> _vscodeConfigs;
  late List<CustomCommand> _customCommands;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.repo.name);
    _vscodeConfigs = List.from(widget.repo.vscodeConfigs);
    _customCommands = List.from(widget.repo.customCommands);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _addConfig() {
    setState(() {
      _vscodeConfigs.add(VscodeConfig(name: '', path: ''));
    });
  }

  void _removeConfig(int index) {
    setState(() {
      _vscodeConfigs.removeAt(index);
    });
  }

  void _addCommand() {
    setState(() {
      _customCommands.add(CustomCommand(name: '', command: ''));
    });
  }

  void _removeCommand(int index) {
    setState(() {
      _customCommands.removeAt(index);
    });
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final configs = _vscodeConfigs
        .where((c) => c.name.trim().isNotEmpty && c.path.trim().isNotEmpty)
        .map((c) => VscodeConfig(name: c.name.trim(), path: c.path.trim()))
        .toList();

    final commands = _customCommands
        .where(
            (c) => c.name.trim().isNotEmpty && c.command.trim().isNotEmpty)
        .map((c) =>
            CustomCommand(name: c.name.trim(), command: c.command.trim()))
        .toList();

    if (name != widget.repo.name) {
      widget.provider.renameRepo(widget.repo, name);
    }

    // Re-fetch the repo after potential rename
    final currentRepo = widget.provider.repos.firstWhere(
      (r) => r.path == widget.repo.path,
      orElse: () => widget.repo,
    );
    widget.provider.updateRepoVscodeConfigs(currentRepo, configs);

    // Re-fetch again after vscode config update
    final latestRepo = widget.provider.repos.firstWhere(
      (r) => r.path == widget.repo.path,
      orElse: () => currentRepo,
    );
    widget.provider.updateRepoCustomCommands(latestRepo, commands);

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      title: const Text(
        'Repository Settings',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.3,
        ),
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Display name
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
              TextField(
                controller: _nameController,
                autofocus: true,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
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
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // VS Code configs
              Row(
                children: [
                  const Text(
                    'VS CODE CONFIGURATIONS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _addConfig,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.vscodeBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.vscode.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded,
                              size: 12, color: AppColors.vscode),
                          SizedBox(width: 4),
                          Text(
                            'Add',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.vscode,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_vscodeConfigs.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface0,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: const Text(
                    'No VS Code configs. The button will open the worktree root.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              else
                ...List.generate(_vscodeConfigs.length, (index) {
                  return _VscodeConfigRow(
                    key: ValueKey(index),
                    config: _vscodeConfigs[index],
                    onChanged: (config) {
                      setState(() => _vscodeConfigs[index] = config);
                    },
                    onRemove: () => _removeConfig(index),
                  );
                }),

              const SizedBox(height: 4),
              const Text(
                'Paths are relative to the worktree directory.',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textMuted,
                  fontStyle: FontStyle.italic,
                ),
              ),

              const SizedBox(height: 24),

              // Custom commands
              Row(
                children: [
                  const Text(
                    'CUSTOM COMMANDS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _addCommand,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.terminalBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.terminal.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded,
                              size: 12, color: AppColors.terminal),
                          SizedBox(width: 4),
                          Text(
                            'Add',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.terminal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_customCommands.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface0,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: const Text(
                    'No custom commands configured.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              else
                ...List.generate(_customCommands.length, (index) {
                  return _CustomCommandRow(
                    key: ValueKey('cmd_$index'),
                    command: _customCommands[index],
                    onChanged: (cmd) {
                      setState(() => _customCommands[index] = cmd);
                    },
                    onRemove: () => _removeCommand(index),
                  );
                }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        GestureDetector(
          onTap: _save,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Save',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.base,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _VscodeConfigRow extends StatelessWidget {
  final VscodeConfig config;
  final ValueChanged<VscodeConfig> onChanged;
  final VoidCallback onRemove;

  const _VscodeConfigRow({
    super.key,
    required this.config,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Name field
          SizedBox(
            width: 140,
            child: TextField(
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
              ),
              decoration: InputDecoration(
                hintText: 'Name',
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
                fillColor: AppColors.surface0,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
              controller: TextEditingController(text: config.name)
                ..selection = TextSelection.collapsed(
                    offset: config.name.length),
              onChanged: (v) =>
                  onChanged(VscodeConfig(name: v, path: config.path)),
            ),
          ),
          const SizedBox(width: 8),
          // Path field
          Expanded(
            child: TextField(
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
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
                fillColor: AppColors.surface0,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
              controller: TextEditingController(text: config.path)
                ..selection = TextSelection.collapsed(
                    offset: config.path.length),
              onChanged: (v) =>
                  onChanged(VscodeConfig(name: config.name, path: v)),
            ),
          ),
          const SizedBox(width: 4),
          // Remove button
          GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 14,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomCommandRow extends StatelessWidget {
  final CustomCommand command;
  final ValueChanged<CustomCommand> onChanged;
  final VoidCallback onRemove;

  const _CustomCommandRow({
    super.key,
    required this.command,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Name field
          SizedBox(
            width: 140,
            child: TextField(
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
              ),
              decoration: InputDecoration(
                hintText: 'Name',
                hintStyle: TextStyle(
                  color: AppColors.textMuted.withValues(alpha: 0.5),
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
                fillColor: AppColors.surface0,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
              controller: TextEditingController(text: command.name)
                ..selection =
                    TextSelection.collapsed(offset: command.name.length),
              onChanged: (v) =>
                  onChanged(CustomCommand(name: v, command: command.command)),
            ),
          ),
          const SizedBox(width: 8),
          // Command field
          Expanded(
            child: TextField(
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
              decoration: InputDecoration(
                hintText: 'e.g. dotnet run --project ./src',
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
                fillColor: AppColors.surface0,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
              controller: TextEditingController(text: command.command)
                ..selection =
                    TextSelection.collapsed(offset: command.command.length),
              onChanged: (v) =>
                  onChanged(CustomCommand(name: command.name, command: v)),
            ),
          ),
          const SizedBox(width: 4),
          // Remove button
          GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 14,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Repo tile with left accent bar ---

class _RepoTile extends StatefulWidget {
  final RepoConfig repo;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final VoidCallback onSettings;

  const _RepoTile({
    required this.repo,
    required this.isSelected,
    required this.onTap,
    required this.onRemove,
    required this.onSettings,
  });

  @override
  State<_RepoTile> createState() => _RepoTileState();
}

class _RepoTileState extends State<_RepoTile> {
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
          margin: const EdgeInsets.only(bottom: 2),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppColors.surface2
                : _hovered
                    ? AppColors.surface1
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Left accent bar
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 3,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: widget.isSelected
                        ? AppColors.accent
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.repo.name,
                          overflow: TextOverflow.ellipsis,
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
                        const SizedBox(height: 2),
                        Text(
                          widget.repo.path
                              .replaceFirst(RegExp(r'^/Users/[^/]+'), '~'),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textMuted,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Action icons (only on hover)
                if (_hovered || widget.isSelected)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _TinyIconButton(
                        icon: Icons.edit_rounded,
                        onTap: widget.onSettings,
                      ),
                      _TinyIconButton(
                        icon: Icons.close_rounded,
                        onTap: widget.onRemove,
                      ),
                    ],
                  ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TinyIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TinyIconButton({required this.icon, required this.onTap});

  @override
  State<_TinyIconButton> createState() => _TinyIconButtonState();
}

class _TinyIconButtonState extends State<_TinyIconButton> {
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
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.surfaceHover : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            widget.icon,
            size: 14,
            color: _hovered ? AppColors.textPrimary : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

// --- Bottom bar buttons ---

class _AddRepoButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _AddRepoButton({required this.onPressed});

  @override
  State<_AddRepoButton> createState() => _AddRepoButtonState();
}

class _AddRepoButtonState extends State<_AddRepoButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 36,
          decoration: BoxDecoration(
            color: _hovered ? AppColors.accent : AppColors.accentMuted,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hovered
                  ? AppColors.accent
                  : AppColors.accent.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_rounded,
                size: 16,
                color: _hovered ? AppColors.base : AppColors.accent,
              ),
              const SizedBox(width: 6),
              Text(
                'Add Repo',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _hovered ? AppColors.base : AppColors.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _SettingsButton({required this.onPressed});

  @override
  State<_SettingsButton> createState() => _SettingsButtonState();
}

class _SettingsButtonState extends State<_SettingsButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _hovered ? AppColors.surface2 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(
            Icons.tune_rounded,
            size: 16,
            color: _hovered ? AppColors.textPrimary : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
