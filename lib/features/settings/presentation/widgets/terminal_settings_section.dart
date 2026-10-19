import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_form_fields.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/settings/domain/app_settings.dart';
import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';

class TerminalSettingsSection extends StatefulWidget {
  const TerminalSettingsSection({super.key});

  @override
  State<TerminalSettingsSection> createState() => _TerminalsSectionState();
}

class _TerminalsSectionState extends State<TerminalSettingsSection> {
  late final TextEditingController _customTerminalController;
  late final TextEditingController _claudeArgsController;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsController>().settings;
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
    final settingsProvider = context.watch<SettingsController>();
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
