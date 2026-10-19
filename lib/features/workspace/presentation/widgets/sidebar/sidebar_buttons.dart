import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/terminal/presentation/controllers/terminal_controller.dart';

class SidebarCollapseToggle extends StatefulWidget {
  final bool collapsed;
  final VoidCallback onTap;

  const SidebarCollapseToggle({super.key, required this.collapsed, required this.onTap});

  @override
  State<SidebarCollapseToggle> createState() => _CollapseToggleButtonState();
}

class _CollapseToggleButtonState extends State<SidebarCollapseToggle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.collapsed ? 'Expand sidebar' : 'Collapse sidebar',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: _hovered ? AppColors.surface2 : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(
              widget.collapsed
                  ? Icons.menu_open_rounded
                  : Icons.keyboard_double_arrow_left_rounded,
              size: 16,
              color: _hovered ? AppColors.textPrimary : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

// --- Collapsed rail repo avatar tile ---
class SidebarRailIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final bool accent;
  final VoidCallback onTap;

  const SidebarRailIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.accent = false,
  });

  @override
  State<SidebarRailIconButton> createState() => _RailIconButtonState();
}

class _RailIconButtonState extends State<SidebarRailIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    if (widget.accent) {
      bg = _hovered ? AppColors.accent : AppColors.accentMuted;
      fg = _hovered ? AppColors.base : AppColors.accent;
    } else {
      bg = _hovered ? AppColors.surface2 : Colors.transparent;
      fg = _hovered ? AppColors.textPrimary : AppColors.textMuted;
    }

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: widget.accent
                    ? (_hovered
                          ? AppColors.accent
                          : AppColors.accent.withValues(alpha: 0.3))
                    : AppColors.border,
              ),
            ),
            child: Icon(widget.icon, size: 16, color: fg),
          ),
        ),
      ),
    );
  }
}

// --- Repo tile with left accent bar ---
class SidebarAddRepoButton extends StatefulWidget {
  final VoidCallback onPressed;
  const SidebarAddRepoButton({super.key, required this.onPressed});

  @override
  State<SidebarAddRepoButton> createState() => _AddRepoButtonState();
}

class _AddRepoButtonState extends State<SidebarAddRepoButton> {
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

class SidebarSettingsButton extends StatefulWidget {
  final VoidCallback onPressed;
  const SidebarSettingsButton({super.key, required this.onPressed});

  @override
  State<SidebarSettingsButton> createState() => _SettingsButtonState();
}

class _SettingsButtonState extends State<SidebarSettingsButton> {
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

class SidebarTerminalToggle extends StatefulWidget {
  const SidebarTerminalToggle({super.key});

  @override
  State<SidebarTerminalToggle> createState() => _TerminalToggleButtonState();
}

class _TerminalToggleButtonState extends State<SidebarTerminalToggle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<TerminalController>();
    final count = tp.sessions.length;
    final hasSessions = count > 0;
    final isActive = tp.isVisible && hasSessions;

    final Color fg;
    if (!hasSessions) {
      fg = AppColors.textMuted.withValues(alpha: 0.4);
    } else if (isActive) {
      fg = AppColors.terminal;
    } else {
      fg = _hovered ? AppColors.textPrimary : AppColors.textMuted;
    }

    final Color bg;
    if (isActive) {
      bg = AppColors.terminal.withValues(alpha: 0.15);
    } else {
      bg = _hovered && hasSessions ? AppColors.surface2 : Colors.transparent;
    }

    final button = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: hasSessions
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: hasSessions ? tp.toggleVisibility : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive
                  ? AppColors.terminal.withValues(alpha: 0.4)
                  : AppColors.border,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Icon(Icons.terminal_rounded, size: 16, color: fg),
              ),
              if (hasSessions)
                Positioned(
                  top: -5,
                  right: -5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    constraints: const BoxConstraints(minWidth: 15),
                    decoration: BoxDecoration(
                      color: AppColors.terminal,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.base, width: 1.5),
                    ),
                    child: Text(
                      '$count',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                        color: AppColors.base,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    return Tooltip(
      message: hasSessions
          ? (isActive ? 'Hide terminals' : 'Show terminals ($count)')
          : 'No active terminals',
      child: button,
    );
  }
}

// --- Claude session shortcut ---
