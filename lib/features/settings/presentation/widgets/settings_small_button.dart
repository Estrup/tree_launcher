import 'package:flutter/material.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';

class SettingsSmallButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const SettingsSmallButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  State<SettingsSmallButton> createState() => _SmallButtonState();
}

class _SmallButtonState extends State<SettingsSmallButton> {
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
