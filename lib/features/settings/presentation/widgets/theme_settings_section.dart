import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';

class ThemeSettingsSection extends StatelessWidget {
  const ThemeSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsController>();
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
