import 'package:flutter/material.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/agent/presentation/controllers/agent_panel_controller.dart';

class AgentPanelHeader extends StatelessWidget {
  const AgentPanelHeader({required this.controller, super.key});

  final AgentPanelController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.assistant_rounded,
            size: 18,
            color: AppColors.accent,
          ),
          const SizedBox(width: 8),
          Text(
            'Agent',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(width: 8),
          if (controller.isRecording)
            _StatusBadge(label: 'Recording', color: AppColors.error)
          else if (controller.isProcessing)
            _StatusBadge(label: 'Thinking…', color: AppColors.accent),
          const Spacer(),
          if (controller.messages.isNotEmpty)
            _HeaderButton(
              icon: Icons.delete_outline_rounded,
              tooltip: 'Clear history',
              onPressed: controller.clearHistory,
            ),
          _HeaderButton(
            icon: Icons.close_rounded,
            tooltip: 'Close',
            onPressed: controller.closePanel,
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _HeaderButton extends StatefulWidget {
  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  State<_HeaderButton> createState() => _HeaderButtonState();
}

class _HeaderButtonState extends State<_HeaderButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(left: 4),
            decoration: BoxDecoration(
              color: _hovered
                  ? AppColors.surfaceHover
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              widget.icon,
              size: 16,
              color: AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
