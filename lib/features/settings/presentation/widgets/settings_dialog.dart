import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_form_fields.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/copilot/data/sound_service.dart';
import 'package:tree_launcher/features/settings/domain/app_settings.dart';
import 'package:tree_launcher/providers/settings_provider.dart';
import 'package:tree_launcher/services/config_service.dart';

enum _SettingsSection { theme, terminals, copilot, aiAssistant, markdownEditor, remoteControl, help }

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
  _SettingsSection _selectedSection = _SettingsSection.theme;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 800,
        height: 600,
        child: Column(
          children: [
            // Header
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
                  Icon(
                    Icons.settings_outlined,
                    size: 20,
                    color: AppColors.textPrimary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => Navigator.pop(context),
                    splashRadius: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            // Body
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Nav
                  Container(
                    width: 200,
                    decoration: BoxDecoration(
                      color: AppColors.surface0,
                      border: Border(
                        right: BorderSide(
                          color: AppColors.borderSubtle,
                          width: 1,
                        ),
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
                          icon: Icons.palette_outlined,
                          label: 'Theme',
                          isSelected:
                              _selectedSection == _SettingsSection.theme,
                          onTap: () => setState(
                            () => _selectedSection = _SettingsSection.theme,
                          ),
                        ),
                        _NavItem(
                          icon: Icons.terminal_rounded,
                          label: 'Terminals',
                          isSelected:
                              _selectedSection == _SettingsSection.terminals,
                          onTap: () => setState(
                            () => _selectedSection = _SettingsSection.terminals,
                          ),
                        ),
                        _NavItem(
                          icon: Icons.auto_awesome_rounded,
                          label: 'Copilot',
                          isSelected:
                              _selectedSection == _SettingsSection.copilot,
                          onTap: () => setState(
                            () => _selectedSection = _SettingsSection.copilot,
                          ),
                        ),
                        _NavItem(
                          icon: Icons.smart_toy_outlined,
                          label: 'AI Assistant',
                          isSelected:
                              _selectedSection == _SettingsSection.aiAssistant,
                          onTap: () => setState(
                            () =>
                                _selectedSection = _SettingsSection.aiAssistant,
                          ),
                        ),
                        _NavItem(
                          icon: Icons.edit_note_rounded,
                          label: 'Markdown Editor',
                          isSelected:
                              _selectedSection == _SettingsSection.markdownEditor,
                          onTap: () => setState(
                            () =>
                                _selectedSection = _SettingsSection.markdownEditor,
                          ),
                        ),
                        _NavItem(
                          icon: Icons.cast_connected_rounded,
                          label: 'Remote Control',
                          isSelected:
                              _selectedSection ==
                              _SettingsSection.remoteControl,
                          onTap: () => setState(
                            () => _selectedSection =
                                _SettingsSection.remoteControl,
                          ),
                        ),
                        const Spacer(),
                        _NavItem(
                          icon: Icons.help_outline_rounded,
                          label: 'Help',
                          isSelected:
                              _selectedSection == _SettingsSection.help,
                          onTap: () => setState(
                            () => _selectedSection = _SettingsSection.help,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: _buildConfigFileLink(),
                        ),
                      ],
                    ),
                  ),
                  // Right Options
                  Expanded(
                    child: Container(
                      color: AppColors.surface0,
                      child: _buildContent(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (_selectedSection) {
      case _SettingsSection.theme:
        return const _ThemeSection();
      case _SettingsSection.terminals:
        return const _TerminalsSection();
      case _SettingsSection.copilot:
        return const _CopilotSection();
      case _SettingsSection.aiAssistant:
        return const _AiAssistantSection();
      case _SettingsSection.markdownEditor:
        return const _MarkdownEditorSection();
      case _SettingsSection.remoteControl:
        return const _RemoteControlSection();
      case _SettingsSection.help:
        return const _HelpSection();
    }
  }

  Widget _buildConfigFileLink() {
    return FutureBuilder<String>(
      future: ConfigService().getConfigPath(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final path = snapshot.data!;
        return GestureDetector(
          onTap: () => Process.run('open', [path]),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Text(
              path,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.accent,
                fontFamily: 'monospace',
                decoration: TextDecoration.underline,
                decorationColor: AppColors.accent.withValues(alpha: 0.4),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }
}

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

class _ThemeSection extends StatelessWidget {
  const _ThemeSection();

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final settings = settingsProvider.settings;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Theme',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Select your preferred color palette',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'THEME',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: palettes.entries.map((entry) {
              final name = entry.key;
              final palette = entry.value;
              final isSelected = settings.themeName == name;
              return _ThemeCard(
                label: paletteDisplayNames[name] ?? name,
                palette: palette,
                isSelected: isSelected,
                onTap: () => settingsProvider.updateTheme(name),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _TerminalsSection extends StatefulWidget {
  const _TerminalsSection();

  @override
  State<_TerminalsSection> createState() => _TerminalsSectionState();
}

class _TerminalsSectionState extends State<_TerminalsSection> {
  late final TextEditingController _customTerminalController;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>().settings;
    _customTerminalController = TextEditingController(
      text: settings.customTerminalCommand ?? '',
    );
  }

  @override
  void dispose() {
    _customTerminalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final settings = settingsProvider.settings;

    const fonts = [
      'SF Mono',
      'Menlo',
      'Monaco',
      'JetBrains Mono',
      'Fira Code',
      'monospace',
    ];
    const sizes = [11.0, 12.0, 13.0, 14.0, 15.0, 16.0];
    final currentFont = settings.terminalFontFamily ?? 'SF Mono';
    final currentSize = settings.terminalFontSize ?? 13.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Terminals',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Configure terminal behavior and appearance',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'TERMINAL APPLICATION',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _OptionCard(
                label: 'Terminal',
                icon: Icons.terminal_rounded,
                isSelected: settings.terminalApp == TerminalApp.terminal,
                onTap: () =>
                    settingsProvider.updateTerminalApp(TerminalApp.terminal),
              ),
              const SizedBox(width: 8),
              _OptionCard(
                label: 'Ghostty',
                icon: Icons.terminal_rounded,
                isSelected: settings.terminalApp == TerminalApp.ghostty,
                onTap: () =>
                    settingsProvider.updateTerminalApp(TerminalApp.ghostty),
              ),
              const SizedBox(width: 8),
              _OptionCard(
                label: 'Custom',
                icon: Icons.tune_rounded,
                isSelected: settings.terminalApp == TerminalApp.custom,
                onTap: () =>
                    settingsProvider.updateTerminalApp(TerminalApp.custom),
              ),
            ],
          ),
          if (settings.terminalApp == TerminalApp.custom) ...[
            const SizedBox(height: 16),
            TextField(
              style: appFormFieldTextStyle(context, monospace: true),
              decoration: InputDecoration(
                labelText: 'Command path',
                hintText: 'shortcuts run "My Shortcut" --input-path "{path}"',
                hintStyle: appFormFieldHintStyle(context, monospace: true),
              ),
              controller: _customTerminalController,
              onChanged: (value) => settingsProvider
                  .updateCustomTerminalCommand(value.isEmpty ? null : value),
            ),
          ],
          const SizedBox(height: 32),
          Text(
            'BUILT-IN TERMINAL',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _DropdownField<String>(
                  label: 'Font',
                  value: currentFont,
                  items: fonts
                      .map(
                        (f) => DropdownMenuItem(
                          value: f,
                          child: Text(
                            f,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textPrimary,
                              fontFamily: f,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) =>
                      settingsProvider.updateTerminalFontFamily(v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _DropdownField<double>(
                  label: 'Size',
                  value: currentSize,
                  items: sizes
                      .map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(
                            '${s.toInt()} px',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => settingsProvider.updateTerminalFontSize(v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CopilotSection extends StatefulWidget {
  const _CopilotSection();

  @override
  State<_CopilotSection> createState() => _CopilotSectionState();
}

class _CopilotSectionState extends State<_CopilotSection> {
  static const _dirPickerChannel =
      MethodChannel('tree_launcher/directory_picker');
  final SoundService _soundService = SoundService();
  late final TextEditingController _branchPrefixController;
  late final TextEditingController _copilotModelController;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>().settings;
    _branchPrefixController = TextEditingController(
      text: settings.defaultBranchPrefix ?? '',
    );
    _copilotModelController = TextEditingController(
      text: settings.copilotModel ?? '',
    );
  }

  @override
  void dispose() {
    _branchPrefixController.dispose();
    _copilotModelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final settings = settingsProvider.settings;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Copilot',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Configure Copilot integrations and behaviors',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'COPILOT BUTTON',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _OptionCard(
                label: 'In-App',
                icon: Icons.auto_awesome_rounded,
                isSelected:
                    settings.copilotButtonMode == CopilotButtonMode.inApp,
                onTap: () => settingsProvider.updateCopilotButtonMode(
                  CopilotButtonMode.inApp,
                ),
              ),
              const SizedBox(width: 8),
              _OptionCard(
                label: 'External',
                icon: Icons.open_in_new_rounded,
                isSelected:
                    settings.copilotButtonMode == CopilotButtonMode.external,
                onTap: () => settingsProvider.updateCopilotButtonMode(
                  CopilotButtonMode.external,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            'COPILOT ATTENTION',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          if (!Platform.isMacOS)
            Text(
              'Copilot attention sounds are currently available on macOS only.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Play a system sound when Copilot needs your attention',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Transform.scale(
                  scale: 0.75,
                  child: Switch(
                    value: settings.copilotAttentionSoundEnabled,
                    activeTrackColor: AppColors.accent,
                    onChanged: (value) => settingsProvider
                        .updateCopilotAttentionSoundEnabled(value),
                  ),
                ),
              ],
            ),
            if (settings.copilotAttentionSoundEnabled) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _DropdownField<CopilotAttentionSound>(
                      label: 'Sound',
                      value: settings.copilotAttentionSound,
                      items: _soundService.supportedCopilotAttentionSounds
                          .map(
                            (sound) => DropdownMenuItem(
                              value: sound,
                              child: Text(
                                sound.displayName,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          settingsProvider.updateCopilotAttentionSound(value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: () => _previewCopilotAttentionSound(settings),
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.surface0,
                      foregroundColor: AppColors.textPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: AppColors.border),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 16),
                    label: const Text(
                      'Preview',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
          const SizedBox(height: 32),
          Text(
            'DEFAULT BRANCH PREFIX',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            style: appFormFieldTextStyle(context, monospace: true),
            decoration: InputDecoration(
              hintText: 'e.g. feature, fix, username',
              hintStyle: appFormFieldHintStyle(context, monospace: true),
            ),
            controller: _branchPrefixController,
            onChanged: (value) => settingsProvider.updateDefaultBranchPrefix(
              value.isEmpty ? null : value,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'New branches will be auto-filled as prefix/worktree-name',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textMuted.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'COPILOT CLI',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            style: appFormFieldTextStyle(context, monospace: true),
            decoration: InputDecoration(
              hintText: 'e.g. claude-sonnet-4-20250514',
              hintStyle: appFormFieldHintStyle(context, monospace: true),
            ),
            controller: _copilotModelController,
            onChanged: (value) => settingsProvider.updateCopilotModel(
              value.isEmpty ? null : value,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Override the default AI model. Leave empty for default.',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textMuted.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 20),
          _buildCliToggle(
            label: 'Allow all (bypass all permission prompts)',
            value: settings.copilotAllowAll,
            onChanged: (value) =>
                settingsProvider.updateCopilotAllowAll(value),
          ),
          _buildCliToggle(
            label: 'Allow all tools',
            value: settings.copilotAllowAllTools,
            enabled: !settings.copilotAllowAll,
            onChanged: (value) =>
                settingsProvider.updateCopilotAllowAllTools(value),
          ),
          _buildCliToggle(
            label: 'Allow all URLs',
            value: settings.copilotAllowAllUrls,
            enabled: !settings.copilotAllowAll,
            onChanged: (value) =>
                settingsProvider.updateCopilotAllowAllUrls(value),
          ),
          _buildCliToggle(
            label: 'Allow all paths',
            value: settings.copilotAllowAllPaths,
            enabled: !settings.copilotAllowAll,
            onChanged: (value) =>
                settingsProvider.updateCopilotAllowAllPaths(value),
          ),
          const SizedBox(height: 8),
          _buildCliToggle(
            label: 'Autopilot mode',
            value: settings.copilotAutopilot,
            onChanged: (value) =>
                settingsProvider.updateCopilotAutopilot(value),
          ),
          const SizedBox(height: 20),
          Text(
            'ADDITIONAL DIRECTORIES',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          ...settings.copilotAddDirs.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    onPressed: () {
                      final dirs = List<String>.from(settings.copilotAddDirs)
                        ..removeAt(entry.key);
                      settingsProvider.updateCopilotAddDirs(dirs);
                    },
                    splashRadius: 14,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: () => _pickAddDir(settingsProvider, settings),
            style: TextButton.styleFrom(
              backgroundColor: AppColors.surface0,
              foregroundColor: AppColors.textPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: AppColors.border),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text(
              'Add Directory',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Include extra directories in Copilot\'s context via --add-dir',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textMuted.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCliToggle({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: enabled
                    ? AppColors.textSecondary
                    : AppColors.textMuted.withValues(alpha: 0.5),
              ),
            ),
          ),
          Transform.scale(
            scale: 0.75,
            child: Switch(
              value: value,
              activeTrackColor: AppColors.accent,
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAddDir(
    SettingsProvider provider,
    AppSettings settings,
  ) async {
    try {
      final result =
          await _dirPickerChannel.invokeMethod<String>('pickDirectory');
      if (result != null) {
        final dirs = [...settings.copilotAddDirs, result];
        provider.updateCopilotAddDirs(dirs);
      }
    } on PlatformException {
      // Picker cancelled or unavailable
    }
  }

  Future<void> _previewCopilotAttentionSound(AppSettings settings) async {
    try {
      await _soundService.playSystemSound(settings.copilotAttentionSound);
    } on MissingPluginException catch (error) {
      _showPreviewError(error.message ?? error.toString());
    } on PlatformException catch (error) {
      _showPreviewError(error.message ?? error.toString());
    } on UnsupportedError catch (error) {
      _showPreviewError(error.message ?? error.toString());
    }
  }

  void _showPreviewError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AiAssistantSection extends StatefulWidget {
  const _AiAssistantSection();

  @override
  State<_AiAssistantSection> createState() => _AiAssistantSectionState();
}

class _AiAssistantSectionState extends State<_AiAssistantSection> {
  late final TextEditingController _openAiApiKeyController;
  late final TextEditingController _openAiTranscriptionModelController;
  late final TextEditingController _openAiResponseModelController;

  @override
  void initState() {
    super.initState();
    final settingsProvider = context.read<SettingsProvider>();
    final settings = settingsProvider.settings;
    _openAiApiKeyController = TextEditingController(
      text: settingsProvider.openAiApiKey,
    );
    _openAiTranscriptionModelController = TextEditingController(
      text: settings.openAiTranscriptionModel,
    );
    _openAiResponseModelController = TextEditingController(
      text: settings.openAiResponseModel,
    );
  }

  @override
  void dispose() {
    _openAiApiKeyController.dispose();
    _openAiTranscriptionModelController.dispose();
    _openAiResponseModelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI Assistant',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'OpenAI specific configuration',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'API KEY',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _openAiApiKeyController,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            style: appFormFieldTextStyle(context, monospace: true),
            decoration: InputDecoration(
              hintText: 'sk-...',
              hintStyle: appFormFieldHintStyle(context, monospace: true),
            ),
            onChanged: (value) => settingsProvider.updateOpenAiApiKey(value),
          ),
          const SizedBox(height: 6),
          Text(
            'Stored directly in the app config file.',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textMuted.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'TRANSCRIPTION MODEL',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _openAiTranscriptionModelController,
            style: appFormFieldTextStyle(context, monospace: true),
            decoration: InputDecoration(
              hintText: 'e.g. whisper-1',
              hintStyle: appFormFieldHintStyle(context, monospace: true),
            ),
            onChanged: (value) {
              if (value.trim().isNotEmpty) {
                settingsProvider.updateOpenAiTranscriptionModel(value.trim());
              }
            },
          ),
          const SizedBox(height: 24),
          Text(
            'RESPONSE MODEL',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _openAiResponseModelController,
            style: appFormFieldTextStyle(context, monospace: true),
            decoration: InputDecoration(
              hintText: 'e.g. gpt-4o',
              hintStyle: appFormFieldHintStyle(context, monospace: true),
            ),
            onChanged: (value) {
              if (value.trim().isNotEmpty) {
                settingsProvider.updateOpenAiResponseModel(value.trim());
              }
            },
          ),
          const SizedBox(height: 24),
          Text(
            'TTS MODEL',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          _DropdownField<String>(
            label: '',
            value: settingsProvider.settings.openAiTtsModel,
            items: const [
              DropdownMenuItem(value: 'tts-1', child: Text('tts-1')),
              DropdownMenuItem(value: 'tts-1-hd', child: Text('tts-1-hd')),
              DropdownMenuItem(
                value: 'gpt-4o-mini-tts',
                child: Text('gpt-4o-mini-tts'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                settingsProvider.updateOpenAiTtsModel(value);
              }
            },
          ),
          const SizedBox(height: 24),
          Text(
            'TTS VOICE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          _DropdownField<TtsVoice>(
            label: '',
            value: settingsProvider.settings.openAiTtsVoice,
            items: TtsVoice.values
                .map(
                  (v) => DropdownMenuItem(
                    value: v,
                    child: Text(v.displayName),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                settingsProvider.updateOpenAiTtsVoice(value);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _RemoteControlSection extends StatefulWidget {
  const _RemoteControlSection();

  @override
  State<_RemoteControlSection> createState() => _RemoteControlSectionState();
}

class _RemoteControlSectionState extends State<_RemoteControlSection> {
  late final TextEditingController _remotePortController;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>().settings;
    _remotePortController = TextEditingController(
      text: settings.remoteControlPort.toString(),
    );
  }

  @override
  void dispose() {
    _remotePortController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final settings = settingsProvider.settings;

    final isEnabled = settings.remoteControlEnabled;
    final bindAddress = settings.remoteControlBindAddress;
    final port = settings.remoteControlPort;
    final url = 'http://$bindAddress:$port';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Remote Control',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Configure remote Copilot terminal access',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'SERVER CONFIGURATION',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Serve Copilot terminals via web browser',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Transform.scale(
                scale: 0.75,
                child: Switch(
                  value: isEnabled,
                  activeTrackColor: AppColors.accent,
                  onChanged: (v) =>
                      settingsProvider.updateRemoteControlEnabled(v),
                ),
              ),
            ],
          ),
          if (isEnabled) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _DropdownField<String>(
                    label: 'Bind address',
                    value: bindAddress,
                    items: const [
                      DropdownMenuItem(
                        value: '127.0.0.1',
                        child: Text(
                          'localhost',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      DropdownMenuItem(
                        value: '0.0.0.0',
                        child: Text(
                          'All interfaces',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        settingsProvider.updateRemoteControlBindAddress(v);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Port',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _remotePortController,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          final parsed = int.tryParse(value);
                          if (parsed != null && parsed > 0 && parsed < 65536) {
                            settingsProvider.updateRemoteControlPort(parsed);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SelectableText(
              url,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.accent,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ThemeCard extends StatefulWidget {
  final String label;
  final AppColorPalette palette;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.label,
    required this.palette,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_ThemeCard> createState() => _ThemeCardState();
}

class _ThemeCardState extends State<_ThemeCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 90,
          padding: const EdgeInsets.all(8),
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
              // Mini preview swatch
              Container(
                height: 28,
                decoration: BoxDecoration(
                  color: p.base,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: p.border, width: 0.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _dot(p.accent),
                    _dot(p.terminal),
                    _dot(p.copilot),
                    _dot(p.vscode),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 10,
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
    );
  }

  Widget _dot(Color color) {
    return Container(
      width: 8,
      height: 8,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable option card (terminal app picker)
// ---------------------------------------------------------------------------

class _OptionCard extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _OptionCard({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_OptionCard> createState() => _OptionCardState();
}

class _OptionCardState extends State<_OptionCard> {
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

// ---------------------------------------------------------------------------
// Dropdown field helper
// ---------------------------------------------------------------------------

class _DropdownField<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        AppDropdownField<T>(
          initialValue: value,
          items: items,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _MarkdownEditorSection extends StatefulWidget {
  const _MarkdownEditorSection();

  @override
  State<_MarkdownEditorSection> createState() => _MarkdownEditorSectionState();
}

class _MarkdownEditorSectionState extends State<_MarkdownEditorSection> {
  late final TextEditingController _folderController;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>().settings;
    _folderController = TextEditingController(
      text: settings.markdownDocumentsFolder ?? '',
    );
  }

  @override
  void dispose() {
    _folderController.dispose();
    super.dispose();
  }

  Future<void> _pickFolder() async {
    final result = await Process.run('osascript', [
      '-e',
      'set theFolder to POSIX path of (choose folder with prompt "Select Documents Folder")',
    ]);
    if (result.exitCode == 0) {
      var folder = (result.stdout as String).trim();
      if (folder.endsWith('/')) folder = folder.substring(0, folder.length - 1);
      _folderController.text = folder;
      if (mounted) {
        context.read<SettingsProvider>().updateMarkdownDocumentsFolder(folder);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final settings = settingsProvider.settings;
    final folder = settings.markdownDocumentsFolder;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Markdown Editor',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Configure the built-in markdown editor',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'DOCUMENTS FOLDER',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Default folder for opening and browsing markdown files',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _folderController,
                  style: appFormFieldTextStyle(context, monospace: true),
                  decoration: InputDecoration(
                    hintText: 'No folder selected',
                    hintStyle: appFormFieldHintStyle(context, monospace: true),
                  ),
                  onChanged: (v) {
                    settingsProvider.updateMarkdownDocumentsFolder(
                      v.isEmpty ? null : v,
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              _SmallButton(
                label: 'Browse',
                icon: Icons.folder_open_rounded,
                onTap: _pickFolder,
              ),
              if (folder != null && folder.isNotEmpty) ...[
                const SizedBox(width: 8),
                _SmallButton(
                  label: 'Clear',
                  icon: Icons.clear_rounded,
                  onTap: () {
                    _folderController.clear();
                    settingsProvider.updateMarkdownDocumentsFolder(null);
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: 32),
          Text(
            'RECENT FILES',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          if (settings.markdownRecentFiles.isEmpty)
            Text(
              'No recently opened files',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            )
          else
            ...settings.markdownRecentFiles.map(
              (path) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        path,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => settingsProvider.removeRecentMarkdownFile(path),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SmallButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _SmallButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_SmallButton> createState() => _SmallButtonState();
}

class _SmallButtonState extends State<_SmallButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.surface2 : AppColors.surface1,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 13, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HelpSection extends StatelessWidget {
  const _HelpSection();

  @override
  Widget build(BuildContext context) {
    const shortcuts = [
      (
        keys: ['Ctrl', 'M'],
        description: 'Start / Stop voice recording',
      ),
      (
        keys: ['⌘', 'L'],
        description: 'Clear agent history (when agent panel is open)',
      ),
      (
        keys: ['⌘', '⌥', 'I'],
        description: 'Copilot summary',
      ),
      (
        keys: ['⌘', '`'],
        description: 'Toggle terminal visibility',
      ),
      (
        keys: ['Enter'],
        description: 'Submit agent message',
      ),
      (
        keys: ['⇧', 'Enter'],
        description: 'Multi-line input in terminal',
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Keyboard Shortcuts',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Available shortcuts in Tree Launcher.',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),
          ...shortcuts.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ShortcutRow(keys: s.keys, description: s.description),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  final List<String> keys;
  final String description;

  const _ShortcutRow({required this.keys, required this.description});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              description,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 16),
          Row(
            children: keys
                .map(
                  (k) => Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: AppColors.border,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        k,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
