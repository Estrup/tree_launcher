import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/agent/presentation/controllers/agent_panel_controller.dart';

class AgentInputBar extends StatefulWidget {
  const AgentInputBar({required this.controller, super.key});

  final AgentPanelController controller;

  @override
  State<AgentInputBar> createState() => _AgentInputBarState();
}

class _AgentInputBarState extends State<AgentInputBar> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submitText() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    unawaited(widget.controller.submitText(text));
  }

  @override
  Widget build(BuildContext context) {
    final isIdle = widget.controller.phase == AgentPanelPhase.idle;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Start / stop-and-submit button
          _InputIconButton(
            icon: widget.controller.isRecording
                ? Icons.stop_rounded
                : Icons.mic_rounded,
            tooltip: widget.controller.isRecording
                ? 'Stop recording'
                : 'Start recording',
            isActive: widget.controller.isRecording,
            activeColor: AppColors.error,
            onPressed: isIdle || widget.controller.isRecording
                ? () {
                    if (widget.controller.isRecording) {
                      unawaited(widget.controller.stopRecordingAndSubmit());
                    } else {
                      unawaited(widget.controller.startRecording());
                    }
                  }
                : null,
          ),
          if (widget.controller.isRecording) ...[
            const SizedBox(width: 8),
            _InputIconButton(
              icon: Icons.close_rounded,
              tooltip: 'Cancel recording',
              onPressed: () {
                unawaited(widget.controller.cancelRecording());
              },
            ),
          ],
          const SizedBox(width: 8),
          // Text field
          Expanded(
            child: KeyboardListener(
              focusNode: FocusNode(),
              onKeyEvent: (event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.enter &&
                    !HardwareKeyboard.instance.isShiftPressed) {
                  _submitText();
                }
              },
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                enabled: isIdle,
                maxLines: 3,
                minLines: 1,
                style: TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Type a message…',
                  hintStyle: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textMuted,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.borderSubtle),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.borderSubtle),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  filled: true,
                  fillColor: AppColors.surface0,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Send button
          _InputIconButton(
            icon: Icons.send_rounded,
            tooltip: 'Send',
            onPressed: isIdle ? _submitText : null,
          ),
        ],
      ),
    );
  }
}

class _InputIconButton extends StatefulWidget {
  const _InputIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isActive = false,
    this.activeColor,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool isActive;
  final Color? activeColor;

  @override
  State<_InputIconButton> createState() => _InputIconButtonState();
}

class _InputIconButtonState extends State<_InputIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null;
    final color = widget.isActive
        ? (widget.activeColor ?? AppColors.accent)
        : AppColors.textMuted;

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: isEnabled ? (_) => setState(() => _hovered = true) : null,
        onExit: isEnabled ? (_) => setState(() => _hovered = false) : null,
        cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: widget.isActive
                  ? color.withValues(alpha: 0.15)
                  : (_hovered ? AppColors.surfaceHover : Colors.transparent),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              widget.icon,
              size: 18,
              color: color.withValues(alpha: isEnabled ? 1 : 0.4),
            ),
          ),
        ),
      ),
    );
  }
}
