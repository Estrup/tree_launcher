import 'package:flutter/material.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/workspace/presentation/command_style.dart';

/// Combined icon + color picker displayed as a clickable icon button.
class IconColorPicker extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String? iconName;
  final String? colorHex;
  final ValueChanged<String> onIconChanged;
  final ValueChanged<String> onColorChanged;

  const IconColorPicker({
    super.key,
    required this.icon,
    required this.color,
    required this.iconName,
    required this.colorHex,
    required this.onIconChanged,
    required this.onColorChanged,
  });

  @override
  State<IconColorPicker> createState() => _IconColorPickerState();
}

class _IconColorPickerState extends State<IconColorPicker> {
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

class SettingsAddButton extends StatefulWidget {
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const SettingsAddButton({
    super.key,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  State<SettingsAddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<SettingsAddButton> {
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

class SettingsRemoveButton extends StatefulWidget {
  final VoidCallback onTap;
  const SettingsRemoveButton({super.key, required this.onTap});

  @override
  State<SettingsRemoveButton> createState() => _RemoveButtonState();
}

class _RemoveButtonState extends State<SettingsRemoveButton> {
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

class SettingsBackButton extends StatefulWidget {
  final VoidCallback onTap;
  const SettingsBackButton({super.key, required this.onTap});

  @override
  State<SettingsBackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<SettingsBackButton> {
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
