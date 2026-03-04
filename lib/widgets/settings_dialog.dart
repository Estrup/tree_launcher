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
        side: BorderSide(color: AppColors.border),
      ),
      title: Text(
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Theme ──
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
              _buildThemePicker(settings, settingsProvider),
              const SizedBox(height: 24),

              // ── Terminal application ──
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
              _buildTerminalOptions(settings, settingsProvider),
              if (settings.terminalApp == TerminalApp.custom) ...[
                const SizedBox(height: 16),
                TextField(
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontFamily: 'monospace',
                  ),
                  decoration: InputDecoration(
                    labelText: 'Command path',
                    labelStyle: TextStyle(color: AppColors.textMuted),
                    hintText: 'shortcuts run "My Shortcut" --input-path "{path}"',
                    hintStyle: TextStyle(
                      color: AppColors.textMuted.withValues(alpha: 0.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.accent),
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

              // ── Built-in terminal ──
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
              _buildTerminalFontSettings(settings, settingsProvider),
              const SizedBox(height: 24),

              // ── Branch prefix ──
              Text(
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
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
                decoration: InputDecoration(
                  labelText: 'Branch prefix',
                  labelStyle: TextStyle(color: AppColors.textMuted),
                  hintText: 'e.g. feature, fix, username',
                  hintStyle: TextStyle(
                    color: AppColors.textMuted.withValues(alpha: 0.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.accent),
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
            ],
          ),
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
            child: Text(
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

  Widget _buildThemePicker(AppSettings settings, SettingsProvider provider) {
    return Wrap(
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
          onTap: () => provider.updateTheme(name),
        );
      }).toList(),
    );
  }

  Widget _buildTerminalOptions(
    AppSettings settings,
    SettingsProvider provider,
  ) {
    return Row(
      children: [
        _OptionCard(
          label: 'Terminal',
          icon: Icons.terminal_rounded,
          isSelected: settings.terminalApp == TerminalApp.terminal,
          onTap: () => provider.updateTerminalApp(TerminalApp.terminal),
        ),
        const SizedBox(width: 8),
        _OptionCard(
          label: 'Ghostty',
          icon: Icons.terminal_rounded,
          isSelected: settings.terminalApp == TerminalApp.ghostty,
          onTap: () => provider.updateTerminalApp(TerminalApp.ghostty),
        ),
        const SizedBox(width: 8),
        _OptionCard(
          label: 'Custom',
          icon: Icons.tune_rounded,
          isSelected: settings.terminalApp == TerminalApp.custom,
          onTap: () => provider.updateTerminalApp(TerminalApp.custom),
        ),
      ],
    );
  }

  Widget _buildTerminalFontSettings(
    AppSettings settings,
    SettingsProvider provider,
  ) {
    const fonts = ['SF Mono', 'Menlo', 'Monaco', 'JetBrains Mono', 'Fira Code', 'monospace'];
    const sizes = [11.0, 12.0, 13.0, 14.0, 15.0, 16.0];

    final currentFont = settings.terminalFontFamily ?? 'SF Mono';
    final currentSize = settings.terminalFontSize ?? 13.0;

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: _DropdownField<String>(
            label: 'Font',
            value: currentFont,
            items: fonts.map((f) => DropdownMenuItem(
              value: f,
              child: Text(f, style: TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
                fontFamily: f,
              )),
            )).toList(),
            onChanged: (v) => provider.updateTerminalFontFamily(v),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: _DropdownField<double>(
            label: 'Size',
            value: currentSize,
            items: sizes.map((s) => DropdownMenuItem(
              value: s,
              child: Text('${s.toInt()} px', style: TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
              )),
            )).toList(),
            onChanged: (v) => provider.updateTerminalFontSize(v),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Theme preview card
// ---------------------------------------------------------------------------

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
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
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
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.surface0,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              dropdownColor: AppColors.surface1,
              style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
              icon: Icon(Icons.expand_more, size: 16, color: AppColors.textMuted),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
