import 'package:flutter/material.dart';
import '../models/copilot_session.dart';
import '../theme/app_theme.dart';

/// Animated pulsing dot that indicates copilot activity status.
/// Green for working, orange for needs-action, hidden for idle.
class CopilotStatusDot extends StatefulWidget {
  final CopilotActivityStatus status;
  final double size;

  const CopilotStatusDot({super.key, required this.status, this.size = 8});

  @override
  State<CopilotStatusDot> createState() => _CopilotStatusDotState();
}

class _CopilotStatusDotState extends State<CopilotStatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _opacity = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _syncAnimation();
  }

  @override
  void didUpdateWidget(CopilotStatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (widget.status == CopilotActivityStatus.idle) {
      _controller.stop();
      _controller.value = 0;
    } else {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.status == CopilotActivityStatus.idle) {
      return SizedBox(width: widget.size, height: widget.size);
    }

    final color = widget.status == CopilotActivityStatus.working
        ? AppColors.success
        : const Color(0xFFF59E0B); // amber/orange for needs-action

    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, child) => Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: _opacity.value),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: _opacity.value * 0.4),
              blurRadius: widget.size * 0.5,
              spreadRadius: widget.size * 0.1,
            ),
          ],
        ),
      ),
    );
  }
}
