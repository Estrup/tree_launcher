import 'package:flutter/material.dart';

import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/agents/domain/agent_kind.dart';
import 'package:tree_launcher/features/agents/domain/agent_run.dart';
import 'package:tree_launcher/features/agents/presentation/controllers/agents_controller.dart';

extension AgentKindStyle on AgentKind {
  IconData get icon => switch (this) {
    AgentKind.refine => Icons.edit_note_rounded,
    AgentKind.build => Icons.construction_rounded,
    AgentKind.verify => Icons.fact_check_outlined,
    AgentKind.review => Icons.rate_review_outlined,
    AgentKind.docs => Icons.menu_book_rounded,
  };

  Color get color => switch (this) {
    AgentKind.refine => AppColors.current.ansiMagenta,
    AgentKind.build => AppColors.accent,
    AgentKind.verify => AppColors.success,
    AgentKind.review => AppColors.vscode,
    AgentKind.docs => AppColors.branch,
  };
}

/// Amber, for anything waiting on a human. The light palette's terminal
/// yellow is a dark brown (for text on white), so it gets its own amber.
Color get agentWaitingColor => AppColors.brightness == Brightness.light
    ? const Color(0xFFB45309)
    : AppColors.current.ansiYellow;

/// Label, icon and color of a run's state pill, taking what the terminal
/// shows of its Claude session into account.
({String label, IconData icon, Color color}) agentStatusStyle(
  AgentRun run,
  AgentLiveness liveness,
) {
  if (run.state == AgentState.waiting) {
    return (
      label: 'Waiting for you',
      icon: Icons.pause_circle_filled_rounded,
      color: agentWaitingColor,
    );
  }
  if (!run.state.isFinished) {
    switch (liveness) {
      case AgentLiveness.waiting:
        return (
          label: 'Needs an answer',
          icon: Icons.help_rounded,
          color: agentWaitingColor,
        );
      case AgentLiveness.exited:
        return (
          label: 'Claude exited',
          icon: Icons.warning_amber_rounded,
          color: AppColors.textMuted,
        );
      case AgentLiveness.idle:
        return (
          label: 'Idle',
          icon: Icons.radio_button_unchecked_rounded,
          color: AppColors.textSecondary,
        );
      case AgentLiveness.none:
      case AgentLiveness.unknown:
      case AgentLiveness.busy:
        break;
    }
  }
  return switch (run.state) {
    AgentState.starting => (
      label: 'Starting',
      icon: Icons.hourglass_top_rounded,
      color: AppColors.textSecondary,
    ),
    AgentState.running || AgentState.waiting => (
      label: 'Running',
      icon: Icons.autorenew_rounded,
      color: AppColors.vscode,
    ),
    AgentState.done => (
      label: 'Done',
      icon: Icons.check_circle_rounded,
      color: AppColors.success,
    ),
    AgentState.failed => (
      label: 'Failed',
      icon: Icons.cancel_rounded,
      color: AppColors.error,
    ),
    AgentState.stopped => (
      label: 'Stopped',
      icon: Icons.stop_circle_outlined,
      color: AppColors.textMuted,
    ),
  };
}

({IconData icon, Color color}) agentStageStyle(AgentStageState state) =>
    switch (state) {
      AgentStageState.pending => (
        icon: Icons.radio_button_unchecked_rounded,
        color: AppColors.textMuted,
      ),
      AgentStageState.running => (
        icon: Icons.timelapse_rounded,
        color: AppColors.vscode,
      ),
      AgentStageState.waiting => (
        icon: Icons.pause_circle_filled_rounded,
        color: agentWaitingColor,
      ),
      AgentStageState.done => (
        icon: Icons.check_circle_rounded,
        color: AppColors.success,
      ),
      AgentStageState.failed => (
        icon: Icons.cancel_rounded,
        color: AppColors.error,
      ),
      AgentStageState.skipped => (
        icon: Icons.remove_circle_outline_rounded,
        color: AppColors.textMuted,
      ),
    };

/// A small pill naming an agent kind.
class AgentKindChip extends StatelessWidget {
  const AgentKindChip({super.key, required this.kind});

  final AgentKind kind;

  @override
  Widget build(BuildContext context) {
    final color = kind.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(kind.icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            kind.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
