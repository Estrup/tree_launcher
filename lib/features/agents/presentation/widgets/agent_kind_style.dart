import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/agents/domain/agent_kind.dart';
import 'package:tree_launcher/features/agents/domain/agent_run.dart';
import 'package:tree_launcher/features/agents/domain/agent_type.dart';
import 'package:tree_launcher/features/agents/presentation/controllers/agents_controller.dart';
import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';

/// How an agent type looks, from the names its catalog entry keeps.
extension AgentTypeStyle on AgentType {
  IconData get iconData => switch (icon) {
    'edit_note' => Icons.edit_note_rounded,
    'construction' => Icons.construction_rounded,
    'fact_check' => Icons.fact_check_outlined,
    'rate_review' => Icons.rate_review_outlined,
    'menu_book' => Icons.menu_book_rounded,
    'support_agent' => Icons.support_agent_rounded,
    'bug_report' => Icons.bug_report_outlined,
    'science' => Icons.science_outlined,
    'search' => Icons.search_rounded,
    'rocket_launch' => Icons.rocket_launch_outlined,
    'security' => Icons.security_rounded,
    'speed' => Icons.speed_rounded,
    'psychology' => Icons.psychology_outlined,
    'forum' => Icons.forum_outlined,
    _ => Icons.smart_toy_outlined,
  };

  Color get colorValue => agentTypeColor(color);
}

/// The color called [name] (one of `agentTypeColors`) in the current theme.
Color agentTypeColor(String name) => switch (name) {
  'accent' => AppColors.accent,
  'magenta' => AppColors.current.ansiMagenta,
  'green' => AppColors.success,
  'blue' => AppColors.vscode,
  'branch' => AppColors.branch,
  'cyan' => AppColors.current.ansiCyan,
  'yellow' => agentWaitingColor,
  'red' => AppColors.error,
  _ => AppColors.textSecondary,
};

/// The catalog of agent types in the settings (the default one where no
/// [SettingsController] is provided), rebuilding with it when [listen].
List<AgentType> agentTypesOf(BuildContext context, {bool listen = true}) =>
    Provider.of<SettingsController?>(
      context,
      listen: listen,
    )?.settings.agentTypes ??
    defaultAgentTypes;

/// The type of [kind] in the settings' catalog (a stand-in for one it no
/// longer has), rebuilding with the catalog when [listen].
AgentType agentTypeOf(
  BuildContext context,
  AgentKind kind, {
  bool listen = true,
}) => agentTypeIn(agentTypesOf(context, listen: listen), kind);

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
    final type = agentTypeOf(context, kind);
    final color = type.colorValue;
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
          Icon(type.iconData, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            type.label,
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
