import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/agents/presentation/widgets/agent_kind_style.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';

/// Which of the agent types (the catalog in Settings → Agents) the selected
/// repo uses. A type switched off has no tab, its prompts don't start
/// agents, and the agent API refuses to register it for the repo.
class RepoAgentTypesSection extends StatelessWidget {
  const RepoAgentTypesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<WorkspaceController>();
    final repo = workspace.selectedRepo;
    if (repo == null) return const SizedBox.shrink();
    final types = agentTypesOf(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Agents',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'The agent types this repo uses. A type that is off has no tab, '
            'its prompts don\'t start agents, and agents of it can\'t '
            'register here. Add or rename types in Settings → Agents.',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 480,
            child: Column(
              children: [
                for (final type in types)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface0,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          type.iconData,
                          size: 16,
                          color: repo.usesAgentType(type.kind)
                              ? type.colorValue
                              : AppColors.textMuted,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            type.label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: repo.usesAgentType(type.kind)
                                  ? AppColors.textPrimary
                                  : AppColors.textMuted,
                            ),
                          ),
                        ),
                        Text(
                          type.kind.id,
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Switch.adaptive(
                          value: repo.usesAgentType(type.kind),
                          onChanged: (on) =>
                              workspace.updateDisabledAgentTypes(repo, [
                                for (final kind in repo.disabledAgentTypes)
                                  if (kind != type.kind) kind,
                                if (!on) type.kind,
                              ]),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
