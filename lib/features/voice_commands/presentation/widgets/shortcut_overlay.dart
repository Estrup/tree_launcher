import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/services/shortcut_overlay_controller.dart';

const _overlayCardKey = ValueKey('shortcut-overlay-card');
const _overlayDetailScrollKey = ValueKey('shortcut-overlay-detail-scroll');
const _overlayMinHeight = 100.0;
const _overlayMaxWidth = 600.0;
const _overlayMaxHeightFraction = 0.4;
const _overlayAbsoluteMaxHeight = 320.0;

class ShortcutOverlay extends StatelessWidget {
  const ShortcutOverlay({required this.controller, super.key});

  final ShortcutOverlayController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxOverlayHeight = _resolveMaxOverlayHeight(
          constraints.maxHeight,
        );

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
                        constraints: BoxConstraints(
                          maxWidth: _overlayMaxWidth,
                          minHeight: _overlayMinHeight,
                          maxHeight: maxOverlayHeight,
                        ),
                        child: DecoratedBox(
                          key: _overlayCardKey,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFF3F3F7,
                            ).withValues(alpha: 0.96),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
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
                                    child: _OverlayStatus(
                                      key: ValueKey(controller.phase),
                                      label: controller.statusLabel,
                                      detail: controller.detailLabel,
                                      indicator: _buildIndicator(controller),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 20),
                                _OverlayIconButton(
                                  icon: controller.primaryIcon,
                                  tooltip: controller.primaryTooltip,
                                  onPressed: controller.canPrimaryAction
                                      ? () {
                                          unawaited(
                                            controller.handlePrimaryAction(),
                                          );
                                        }
                                      : null,
                                  backgroundColor: controller.isBusy
                                      ? const Color(0xFF404048)
                                      : const Color(0xFF0C0C0F),
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
      },
    );
  }
}

class _OverlayStatus extends StatelessWidget {
  const _OverlayStatus({
    required this.label,
    required this.detail,
    required this.indicator,
    super.key,
  });

  final String label;
  final String detail;
  final Widget indicator;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              indicator,
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111111),
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
        if (detail.isNotEmpty) ...[
          const SizedBox(height: 6),
          Flexible(
            fit: FlexFit.loose,
            child: SingleChildScrollView(
              key: _overlayDetailScrollKey,
              child: Text(
                detail,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted.withValues(alpha: 0.95),
                  letterSpacing: -0.1,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ],
      ],
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

class _BusyIndicator extends StatelessWidget {
  const _BusyIndicator();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(
        strokeWidth: 2.2,
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF111111)),
      ),
    );
  }
}

class _StatusIconIndicator extends StatelessWidget {
  const _StatusIconIndicator({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Icon(icon, size: 18, color: color);
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

Widget _buildIndicator(ShortcutOverlayController controller) {
  switch (controller.phase) {
    case VoiceCommandPhase.recording:
      return const _ListeningIndicator();
    case VoiceCommandPhase.trimming:
    case VoiceCommandPhase.transcribing:
    case VoiceCommandPhase.routing:
      return const _BusyIndicator();
    case VoiceCommandPhase.success:
      return const _StatusIconIndicator(
        icon: Icons.check_circle_rounded,
        color: Color(0xFF0F8A4B),
      );
    case VoiceCommandPhase.error:
      return const _StatusIconIndicator(
        icon: Icons.error_rounded,
        color: Color(0xFFB42318),
      );
    case VoiceCommandPhase.closed:
      return const SizedBox.shrink();
  }
}

double _resolveMaxOverlayHeight(double availableHeight) {
  final screenRelativeMax = availableHeight.isFinite
      ? availableHeight * _overlayMaxHeightFraction
      : _overlayAbsoluteMaxHeight;

  return math.max(
    _overlayMinHeight,
    math.min(_overlayAbsoluteMaxHeight, screenRelativeMax),
  );
}
