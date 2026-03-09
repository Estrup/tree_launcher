import 'package:flutter/material.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/agent/presentation/controllers/agent_panel_controller.dart';
import 'package:tree_launcher/features/agent/presentation/widgets/agent_input_bar.dart';
import 'package:tree_launcher/features/agent/presentation/widgets/agent_message_list.dart';
import 'package:tree_launcher/features/agent/presentation/widgets/agent_panel_header.dart';

const _panelWidth = 380.0;
const _panelHeight = 480.0;

class AgentPanel extends StatelessWidget {
  const AgentPanel({required this.controller, super.key});

  final AgentPanelController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final isVisible = controller.panelOpen;

        return IgnorePointer(
          ignoring: !isVisible,
          child: AnimatedOpacity(
            opacity: isVisible ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: AnimatedSlide(
              offset: isVisible ? Offset.zero : const Offset(0.08, 0.08),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.only(
                    right: 20,
                    bottom: 20,
                  ),
                  child: SizedBox(
                    width: _panelWidth,
                    height: _panelHeight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.base,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.45),
                            blurRadius: 28,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Column(
                          children: [
                            AgentPanelHeader(controller: controller),
                            if (controller.errorMessage != null)
                              _ErrorBanner(
                                message: controller.errorMessage!,
                                onDismiss: () {
                                  // Clear error by starting fresh
                                  controller.clearHistory();
                                },
                              ),
                            Expanded(
                              child: AgentMessageList(
                                controller: controller,
                              ),
                            ),
                            AgentInputBar(controller: controller),
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

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(
            color: AppColors.error.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 14, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 11, color: AppColors.error),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: Icon(
              Icons.close_rounded,
              size: 14,
              color: AppColors.error.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
