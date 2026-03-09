import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/copilot/domain/copilot_session.dart';
import 'package:tree_launcher/providers/copilot_provider.dart';

/// Floating notification that appears when a copilot session needs attention.
/// Positioned in the bottom-center. Tapping navigates to the session.
class CopilotAttentionSnackbar extends StatefulWidget {
  const CopilotAttentionSnackbar({super.key});

  @override
  State<CopilotAttentionSnackbar> createState() =>
      _CopilotAttentionSnackbarState();
}

class _CopilotAttentionSnackbarState extends State<CopilotAttentionSnackbar>
    with SingleTickerProviderStateMixin {
  CopilotSession? _currentSession;
  Timer? _autoDismissTimer;
  late final AnimationController _animController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  /// Snapshot of sessions needing action from the previous build,
  /// so we can detect new transitions.
  Set<String> _prevNeedingAction = {};

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0.0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _show(CopilotSession session) {
    _autoDismissTimer?.cancel();
    _currentSession = session;
    _animController.forward(from: 0.0);
    _autoDismissTimer = Timer(const Duration(seconds: 8), _dismiss);
  }

  Future<void> _dismiss() async {
    _autoDismissTimer?.cancel();
    await _animController.reverse();
    if (mounted) {
      setState(() => _currentSession = null);
    }
  }

  void _onTap() {
    final session = _currentSession;
    if (session == null) return;
    _autoDismissTimer?.cancel();
    _animController.reverse().then((_) {
      if (mounted) {
        setState(() => _currentSession = null);
        context.read<CopilotProvider>().selectSession(session);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final copilot = context.watch<CopilotProvider>();
    final needsAction = copilot.sessionsNeedingAction;
    final activeSessionId = copilot.activeSession?.id;
    final currentIds = needsAction.map((s) => s.id).toSet();

    // Detect newly added sessions (not in previous snapshot)
    final newIds = currentIds.difference(_prevNeedingAction);
    _prevNeedingAction = currentIds;

    // Find a new session to notify about that isn't the one being viewed
    final candidate = newIds.isEmpty
        ? null
        : needsAction.cast<CopilotSession?>().firstWhere(
            (s) => newIds.contains(s!.id) && s.id != activeSessionId,
            orElse: () => null,
          );

    if (candidate != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _show(candidate));
        }
      });
    }

    if (_currentSession == null) return const SizedBox.shrink();

    return Positioned(
      left: 0,
      right: 0,
      bottom: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Center(
            child: GestureDetector(
              onTap: _onTap,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 300),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border(
                      left: BorderSide(color: const Color(0xFFF59E0B), width: 3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.notifications_rounded,
                        size: 18,
                        color: Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _currentSession!.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Needs your attention',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
