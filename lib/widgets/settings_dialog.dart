import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_settings.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<SettingsProvider>(),
        child: const SettingsDialog(),
      ),
    );
  }

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late final TextEditingController _customTerminalController;
  late final TextEditingController _branchPrefixController;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>().settings;
    _customTerminalController = TextEditingController(
      text: settings.customTerminalCommand ?? '',
    );
    _branchPrefixController = TextEditingController(
      text: settings.defaultBranchPrefix ?? '',
    );
  }

  @override
  void dispose() {
    _customTerminalController.dispose();
    _branchPrefixController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final settings = settingsProvider.settings;

    return AlertDialog(
      backgroundColor: AppColors.surface1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      title: const Text(
        'Settings',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.3,
        ),
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'TERMINAL APPLICATION',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            _buildTerminalOptions(settings, settingsProvider),
            if (settings.terminalApp == TerminalApp.custom) ...[
              const SizedBox(height: 16),
              TextField(
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
                decoration: InputDecoration(
                  labelText: 'Command path',
                  labelStyle: const TextStyle(color: AppColors.textMuted),
                  hintText: 'shortcuts run "My Shortcut" --input-path "{path}"',
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
                ),
                controller: _customTerminalController,
                onChanged: (value) {
                  settingsProvider.updateCustomTerminalCommand(
                    value.isEmpty ? null : value,
                  );
                },
              ),
            ],
            const SizedBox(height: 24),
            const Text(
              'DEFAULT BRANCH PREFIX',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontFamily: 'monospace',
              ),
              decoration: InputDecoration(
                labelText: 'Branch prefix',
                labelStyle: const TextStyle(color: AppColors.textMuted),
                hintText: 'e.g. feature, fix, username',
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
              ),
              controller: _branchPrefixController,
              onChanged: (value) {
                settingsProvider.updateDefaultBranchPrefix(
                  value.isEmpty ? null : value,
                );
              },
            ),
            const SizedBox(height: 6),
            Text(
              'New branches will be auto-filled as prefix/worktree-name',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.textMuted.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'EXTRA ACTIONS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface0,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: const Text(
                'Configurable per-repo actions coming soon.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Done',
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

  Widget _buildTerminalOptions(
      AppSettings settings, SettingsProvider provider) {
    return Row(
      children: [
        _TerminalOption(
          label: 'Terminal',
          icon: Icons.terminal_rounded,
          isSelected: settings.terminalApp == TerminalApp.terminal,
          onTap: () => provider.updateTerminalApp(TerminalApp.terminal),
        ),
        const SizedBox(width: 8),
        _TerminalOption(
          label: 'iTerm2',
          icon: Icons.terminal_rounded,
          isSelected: settings.terminalApp == TerminalApp.iterm2,
          onTap: () => provider.updateTerminalApp(TerminalApp.iterm2),
        ),
        const SizedBox(width: 8),
        _TerminalOption(
          label: 'Custom',
          icon: Icons.tune_rounded,
          isSelected: settings.terminalApp == TerminalApp.custom,
          onTap: () => provider.updateTerminalApp(TerminalApp.custom),
        ),
      ],
    );
  }
}

class _TerminalOption extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TerminalOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_TerminalOption> createState() => _TerminalOptionState();
}

class _TerminalOptionState extends State<_TerminalOption> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? AppColors.accentMuted
                  : _hovered
                      ? AppColors.surface2
                      : AppColors.surface0,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: widget.isSelected
                    ? AppColors.accent.withValues(alpha: 0.4)
                    : AppColors.border,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  widget.icon,
                  size: 18,
                  color: widget.isSelected
                      ? AppColors.accent
                      : AppColors.textMuted,
                ),
                const SizedBox(height: 6),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: widget.isSelected
                        ? AppColors.accent
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
