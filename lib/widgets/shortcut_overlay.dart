import 'package:flutter/material.dart';

import '../services/shortcut_overlay_controller.dart';
import '../theme/app_theme.dart';

class ShortcutOverlay extends StatelessWidget {
  const ShortcutOverlay({required this.controller, super.key});

  final ShortcutOverlayController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final isVisible = controller.isVisible;

        return IgnorePointer(
          ignoring: !isVisible,
          child: AnimatedOpacity(
            opacity: isVisible ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: AnimatedSlide(
              offset: isVisible ? Offset.zero : const Offset(0, 0.18),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  minimum: const EdgeInsets.only(
                    bottom: 48,
                    left: 24,
                    right: 24,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 600,
                      minHeight: 100,
                      maxHeight: 100,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F3F7).withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 32,
                            offset: const Offset(0, 18),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            _OverlayIconButton(
                              icon: Icons.close_rounded,
                              tooltip: 'Dismiss',
                              onPressed: controller.canDismiss
                                  ? controller.dismiss
                                  : null,
                              backgroundColor: const Color(
                                0xFFE7E7EE,
                              ).withValues(alpha: 0.95),
                              iconColor: const Color(0xFF111111),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                child: controller.isSending
                                    ? _OverlayStatus(
                                        key: const ValueKey('sending-status'),
                                        label: controller.statusLabel,
                                        indicator: const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Color(0xFF111111),
                                                ),
                                          ),
                                        ),
                                      )
                                    : _OverlayStatus(
                                        key: const ValueKey('listening-status'),
                                        label: controller.statusLabel,
                                        indicator: const _ListeningIndicator(),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            _OverlayIconButton(
                              icon: Icons.arrow_upward_rounded,
                              tooltip: 'Send',
                              onPressed: controller.canSubmit
                                  ? () => controller.submit()
                                  : null,
                              backgroundColor: const Color(0xFF0C0C0F),
                              iconColor: const Color(0xFFF5F5F8),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OverlayStatus extends StatelessWidget {
  const _OverlayStatus({
    required this.label,
    required this.indicator,
    super.key,
  });

  final String label;
  final Widget indicator;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          indicator,
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111111),
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _ListeningIndicator extends StatelessWidget {
  const _ListeningIndicator();

  @override
  Widget build(BuildContext context) {
    const barHeights = <double>[10, 14, 18, 14, 10];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(barHeights.length, (index) {
        final height = barHeights[index];
        final color = index.isEven
            ? AppColors.textMuted.withValues(alpha: 0.55)
            : AppColors.textSecondary.withValues(alpha: 0.75);

        return Padding(
          padding: EdgeInsets.only(
            right: index == barHeights.length - 1 ? 0 : 4,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
            child: SizedBox(width: 4, height: height),
          ),
        );
      }),
    );
  }
}

class _OverlayIconButton extends StatefulWidget {
  const _OverlayIconButton({
    required this.icon,
    required this.tooltip,
    required this.backgroundColor,
    required this.iconColor,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback? onPressed;

  @override
  State<_OverlayIconButton> createState() => _OverlayIconButtonState();
}

class _OverlayIconButtonState extends State<_OverlayIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null;

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: isEnabled ? (_) => setState(() => _hovered = true) : null,
        onExit: isEnabled ? (_) => setState(() => _hovered = false) : null,
        cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: widget.backgroundColor.withValues(
                alpha: isEnabled ? (_hovered ? 0.88 : 1) : 0.55,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.icon,
              size: 24,
              color: widget.iconColor.withValues(alpha: isEnabled ? 1 : 0.45),
            ),
          ),
        ),
      ),
    );
  }
}
