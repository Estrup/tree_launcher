import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/github_prs/presentation/controllers/github_prs_controller.dart';

/// Floating notification that appears when a newly created pull request
/// requests the current user as a reviewer. Positioned bottom-center.
/// Tapping opens the PR in the browser.
class PrReviewToast extends StatefulWidget {
  const PrReviewToast({super.key});

  @override
  State<PrReviewToast> createState() => _PrReviewToastState();
}

class _PrReviewToastState extends State<PrReviewToast>
    with SingleTickerProviderStateMixin {
  PrReviewNotification? _current;
  Timer? _autoDismissTimer;
  late final AnimationController _animController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

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

  void _show(PrReviewNotification notification) {
    _autoDismissTimer?.cancel();
    _current = notification;
    _animController.forward(from: 0.0);
    _autoDismissTimer = Timer(const Duration(seconds: 8), _dismiss);
  }

  Future<void> _dismiss() async {
    _autoDismissTimer?.cancel();
    await _animController.reverse();
    if (mounted) {
      setState(() => _current = null);
    }
  }

  void _onTap() {
    final notification = _current;
    if (notification == null) return;
    Process.run('open', [notification.pr.htmlUrl]);
    _autoDismissTimer?.cancel();
    _animController.reverse().then((_) {
      if (mounted) {
        setState(() => _current = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final prs = context.watch<GithubPrsController>();

    // Pull the next pending review request (if any) and animate it in.
    if (prs.hasPendingReviewToast) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final notification =
            context.read<GithubPrsController>().consumeReviewToast();
        if (notification != null) {
          setState(() => _show(notification));
        }
      });
    }

    if (_current == null) return const SizedBox.shrink();

    final notification = _current!;
    final pr = notification.pr;
    final headline = notification.reRequested
        ? 'Review re-requested · #${pr.number}'
        : 'Review requested · #${pr.number}';

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
                  constraints: const BoxConstraints(maxWidth: 320),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border(
                      left: BorderSide(color: AppColors.accent, width: 3),
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
                      Icon(
                        Icons.rate_review_outlined,
                        size: 18,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              headline,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              pr.title,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
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
