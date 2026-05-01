import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/agent/domain/agent_message.dart';
import 'package:tree_launcher/features/agent/presentation/controllers/agent_panel_controller.dart';

class AgentMessageList extends StatefulWidget {
  const AgentMessageList({required this.controller, super.key});

  final AgentPanelController controller;

  @override
  State<AgentMessageList> createState() => _AgentMessageListState();
}

class _AgentMessageListState extends State<AgentMessageList> {
  final ScrollController _scrollController = ScrollController();
  int _prevItemCount = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant AgentMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    final itemCount =
        widget.controller.messages.length +
        (widget.controller.isProcessing ? 1 : 0);
    if (itemCount != _prevItemCount) {
      _prevItemCount = itemCount;
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.controller.messages;

    if (messages.isEmpty && !widget.controller.isProcessing) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.mic_rounded,
                size: 32,
                color: AppColors.textMuted.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 12),
              Text(
                'Press Ctrl+M to speak\nor type a message below',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: messages.length + (widget.controller.isProcessing ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == messages.length) {
          return const _ThinkingIndicator();
        }
        final message = messages[index];
        return _MessageBubble(
          message: message,
          isSpeaking: widget.controller.speakingMessageId == message.id,
          onSpeak: message.role == AgentMessageRole.assistant
              ? () => widget.controller.speakMessage(message.id)
              : null,
          onStopSpeaking: widget.controller.speakingMessageId == message.id
              ? widget.controller.stopSpeaking
              : null,
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isSpeaking,
    this.onSpeak,
    this.onStopSpeaking,
  });

  final AgentMessage message;
  final bool isSpeaking;
  final VoidCallback? onSpeak;
  final VoidCallback? onStopSpeaking;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == AgentMessageRole.user;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(top: 2, right: 6),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.assistant_rounded,
                size: 13,
                color: AppColors.accent,
              ),
            ),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Listener(
                  onPointerDown: (event) {
                    if (event.buttons == kSecondaryMouseButton) {
                      _showMessageContextMenu(
                        context,
                        event.position,
                        message.content,
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isUser
                          ? AppColors.accent.withValues(alpha: 0.12)
                          : AppColors.surface1,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isUser
                            ? AppColors.accent.withValues(alpha: 0.2)
                            : AppColors.borderSubtle,
                      ),
                    ),
                    child: isUser
                        ? SelectableText(
                            message.content,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textPrimary,
                              height: 1.4,
                            ),
                          )
                        : MarkdownBody(
                            data: message.content,
                            selectable: true,
                            styleSheet: MarkdownStyleSheet(
                              p: TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textPrimary,
                                height: 1.4,
                              ),
                              code: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.accent,
                                backgroundColor: AppColors.surface0,
                                fontFamily: 'monospace',
                              ),
                              codeblockDecoration: BoxDecoration(
                                color: AppColors.surface0,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppColors.borderSubtle,
                                ),
                              ),
                            ),
                            shrinkWrap: true,
                          ),
                  ),
                ),
                if (message.toolSummaries.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  ...message.toolSummaries.map(
                    (summary) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.build_circle_outlined,
                            size: 11,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              summary,
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (!isUser && onSpeak != null) ...[
                  const SizedBox(height: 2),
                  _SpeakButton(
                    isSpeaking: isSpeaking,
                    onPressed: isSpeaking ? onStopSpeaking! : onSpeak!,
                  ),
                ],
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 28),
        ],
      ),
    );
  }

  Future<void> _showMessageContextMenu(
    BuildContext context,
    Offset position,
    String content,
  ) async {
    final action = await showMenu<_MessageContextMenuAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: const [
        PopupMenuItem(
          value: _MessageContextMenuAction.copyMessage,
          child: Text('Copy message'),
        ),
      ],
    );

    switch (action) {
      case _MessageContextMenuAction.copyMessage:
        await Clipboard.setData(ClipboardData(text: content));
        break;
      case null:
        break;
    }
  }
}

enum _MessageContextMenuAction { copyMessage }

class _SpeakButton extends StatefulWidget {
  const _SpeakButton({required this.isSpeaking, required this.onPressed});

  final bool isSpeaking;
  final VoidCallback onPressed;

  @override
  State<_SpeakButton> createState() => _SpeakButtonState();
}

class _SpeakButtonState extends State<_SpeakButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.surfaceHover : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.isSpeaking
                    ? Icons.stop_rounded
                    : Icons.volume_up_rounded,
                size: 12,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 3),
              Text(
                widget.isSpeaking ? 'Stop' : 'Speak',
                style: TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThinkingIndicator extends StatelessWidget {
  const _ThinkingIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.assistant_rounded,
              size: 13,
              color: AppColors.accent,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface1,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.textMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
