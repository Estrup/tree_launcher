import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/app/dependencies.dart';
import 'package:tree_launcher/core/design_system/app_form_fields.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/settings/domain/app_settings.dart';
import 'package:tree_launcher/features/settings/presentation/widgets/jira_settings_section.dart';
import 'package:tree_launcher/providers/settings_provider.dart';
import 'package:tree_launcher/services/config_service.dart';

enum _SettingsSection {
  theme,
  terminals,
  repositories,
  jira,
  agentApi,
  help,
}

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
                          icon: Icons.folder_outlined,
                          label: 'Repositories',
                          isSelected:
                              _selectedSection == _SettingsSection.repositories,
                          onTap: () => setState(
                            () =>
                                _selectedSection = _SettingsSection.repositories,
                          ),
                        ),
                        _NavItem(
                          icon: Icons.confirmation_number_outlined,
                          label: 'Jira',
                          isSelected: _selectedSection == _SettingsSection.jira,
                          onTap: () => setState(
                            () => _selectedSection = _SettingsSection.jira,
                          ),
                        ),
                        _NavItem(
                          icon: Icons.api_rounded,
                          label: 'Agent API',
                          isSelected:
                              _selectedSection == _SettingsSection.agentApi,
                          onTap: () => setState(
                            () => _selectedSection = _SettingsSection.agentApi,
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
      case _SettingsSection.repositories:
        return const _RepositoriesSection();
      case _SettingsSection.jira:
        return const JiraSettingsSection();
      case _SettingsSection.agentApi:
        return const _AgentApiSection();
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
  late final TextEditingController _claudeArgsController;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>().settings;
    _customTerminalController = TextEditingController(
      text: settings.customTerminalCommand ?? '',
    );
    _claudeArgsController = TextEditingController(
      text: settings.claudeCliArgs,
    );
  }

  @override
  void dispose() {
    _customTerminalController.dispose();
    _claudeArgsController.dispose();
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
          const SizedBox(height: 32),
          Text(
            'CLAUDE CLI',
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
              labelText: 'Extra arguments',
              hintText: defaultClaudeCliArgs,
              hintStyle: appFormFieldHintStyle(context, monospace: true),
            ),
            controller: _claudeArgsController,
            onChanged: settingsProvider.updateClaudeCliArgs,
          ),
          const SizedBox(height: 6),
          Text(
            'Added to `claude` when a session is started from the Jira tab '
            'or resumed from the sidebar.',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textMuted.withValues(alpha: 0.8),
            ),
          ),
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
                    _dot(p.branch),
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

class _RepositoriesSection extends StatelessWidget {
  const _RepositoriesSection();

  /// Replaces the home directory prefix with `~` to match the sidebar display.
  String _displayPath(String path) {
    final home = Platform.environment['HOME'];
    if (home != null && home.isNotEmpty && path.startsWith(home)) {
      return '~${path.substring(home.length)}';
    }
    return path;
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final hiddenRepos = settingsProvider.settings.hiddenRepos;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Repositories',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Repositories you've hidden from the sidebar",
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'HIDDEN REPOSITORIES',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          if (hiddenRepos.isEmpty)
            Text(
              'No hidden repositories',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            )
          else
            ...hiddenRepos.map(
              (path) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.folder_outlined,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            path.split('/').last,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _displayPath(path),
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                              fontFamily: 'monospace',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _SmallButton(
                      label: 'Unhide',
                      icon: Icons.visibility_rounded,
                      onTap: () => settingsProvider.unhideRepo(path),
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

class _AgentApiSection extends StatefulWidget {
  const _AgentApiSection();

  @override
  State<_AgentApiSection> createState() => _AgentApiSectionState();
}

class _AgentApiSectionState extends State<_AgentApiSection> {
  late final TextEditingController _portController;
  final FocusNode _portFocus = FocusNode();
  String? _error;
  bool _restarting = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>().settings;
    // A debug override (--dart-define=AGENT_API_PORT) wins over the saved
    // config and must never be written back, so the field shows it read-only.
    _portController = TextEditingController(
      text: (agentApiPortOverride != 0
              ? agentApiPortOverride
              : settings.agentApiPort)
          .toString(),
    );
    // Commit when the field loses focus, mirroring onSubmitted.
    _portFocus.addListener(() {
      if (!_portFocus.hasFocus) _commitPort();
    });
  }

  @override
  void dispose() {
    _portController.dispose();
    _portFocus.dispose();
    super.dispose();
  }

  Future<void> _commitPort() async {
    // Never persist while a debug override is active.
    if (agentApiPortOverride != 0) return;
    final settingsProvider = context.read<SettingsProvider>();
    final current = settingsProvider.settings.agentApiPort;
    final text = _portController.text.trim();
    final port = int.tryParse(text);

    if (port == null || port < 1024 || port > 65535) {
      setState(() => _error = 'Enter a port between 1024 and 65535');
      return;
    }
    setState(() => _error = null);
    if (port == current) return;

    await settingsProvider.updateAgentApiPort(port);
    await _restart(port);
  }

  Future<void> _restart(int port) async {
    final deps = context.read<AppDependencies>();
    setState(() => _restarting = true);
    await deps.agentApiServer.restart(port: port);
    if (mounted) setState(() => _restarting = false);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>().settings;
    final server = context.read<AppDependencies>().agentApiServer;
    final running = server.isRunning;
    final activePort = server.port;
    final overridden = agentApiPortOverride != 0;
    // Port this process uses: the debug override if set, else the saved config.
    final effectivePort = overridden ? agentApiPortOverride : settings.agentApiPort;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Agent API',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Local HTTP API for AI agents, bound to 127.0.0.1',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'PORT',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 160,
            child: TextField(
              style: appFormFieldTextStyle(context, monospace: true),
              decoration: InputDecoration(
                hintText: '8765',
                hintStyle: appFormFieldHintStyle(context, monospace: true),
              ),
              controller: _portController,
              focusNode: _portFocus,
              enabled: !overridden,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onSubmitted: (_) => _commitPort(),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            overridden
                ? 'Debug override from --dart-define=AGENT_API_PORT. The saved '
                      'config port (${settings.agentApiPort}) is unchanged and '
                      'will be used on a normal launch.'
                : _error ??
                      'Changing the port restarts the service immediately. '
                          'Takes effect on next launch too.',
            style: TextStyle(
              fontSize: 10,
              color: _error != null && !overridden
                  ? AppColors.error
                  : AppColors.textMuted.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _SmallButton(
                label: _restarting ? 'Restarting…' : 'Restart service',
                icon: Icons.refresh_rounded,
                onTap: () {
                  if (!_restarting) _restart(effectivePort);
                },
              ),
              const SizedBox(width: 12),
              Icon(
                running ? Icons.circle : Icons.circle_outlined,
                size: 9,
                color: running ? AppColors.success : AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                running
                    ? 'Running on http://127.0.0.1:$activePort'
                    : 'Not running',
                style: TextStyle(
                  fontSize: 12,
                  color: running
                      ? AppColors.textSecondary
                      : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
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
        keys: ['⌘', '`'],
        description: 'Toggle terminal visibility',
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
