import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/repo_settings/agent_types_section.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/repo_settings/claude_prompts_section.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/repo_settings/custom_commands_section.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/repo_settings/general_section.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/repo_settings/github_section.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/repo_settings/jira_section.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/repo_settings/predefined_issues_section.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/repo_settings/settings_controls.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/repo_settings/vscode_configs_section.dart';
import 'package:tree_launcher/core/widgets/settings_nav_item.dart';

enum _SettingsSection {
  general,
  vscodeConfigs,
  customCommands,
  claudePrompts,
  agentTypes,
  predefinedIssues,
  github,
  jira,
}

class RepoSettingsView extends StatefulWidget {
  const RepoSettingsView({super.key});

  @override
  State<RepoSettingsView> createState() => _RepoSettingsViewState();
}

class _RepoSettingsViewState extends State<RepoSettingsView> {
  _SettingsSection _selectedSection = _SettingsSection.general;

  @override
  Widget build(BuildContext context) {
    final repoProvider = context.watch<WorkspaceController>();
    final repo = repoProvider.selectedRepo;

    return Column(
      children: [
        // Full-width header
        Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: AppColors.surface0,
            border: Border(
              bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
            ),
          ),
          child: Row(
            children: [
              SettingsBackButton(onTap: () => repoProvider.closeSettings()),
              const SizedBox(width: 12),
              Text(
                repo != null ? repo.name : 'Repository Settings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Body: nav + content
        Expanded(
          child: Row(
            children: [
              // Left nav menu
              Container(
                width: 200,
                decoration: BoxDecoration(
                  color: AppColors.surface0,
                  border: Border(
                    right: BorderSide(color: AppColors.borderSubtle, width: 1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                      child: Text(
                        'SETTINGS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted.withValues(alpha: 0.7),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    SettingsNavItem(
                      icon: Icons.info_outline_rounded,
                      label: 'General',
                      isSelected: _selectedSection == _SettingsSection.general,
                      onTap: () => setState(
                        () => _selectedSection = _SettingsSection.general,
                      ),
                    ),
                    SettingsNavItem(
                      icon: Icons.code_rounded,
                      label: 'VS Code Configs',
                      isSelected:
                          _selectedSection == _SettingsSection.vscodeConfigs,
                      onTap: () => setState(
                        () => _selectedSection = _SettingsSection.vscodeConfigs,
                      ),
                    ),
                    SettingsNavItem(
                      icon: Icons.terminal_rounded,
                      label: 'Custom Commands',
                      isSelected:
                          _selectedSection == _SettingsSection.customCommands,
                      onTap: () => setState(
                        () =>
                            _selectedSection = _SettingsSection.customCommands,
                      ),
                    ),
                    SettingsNavItem(
                      icon: Icons.auto_awesome_rounded,
                      label: 'Claude Prompts',
                      isSelected:
                          _selectedSection == _SettingsSection.claudePrompts,
                      onTap: () => setState(
                        () =>
                            _selectedSection = _SettingsSection.claudePrompts,
                      ),
                    ),
                    SettingsNavItem(
                      icon: Icons.smart_toy_outlined,
                      label: 'Agents',
                      isSelected:
                          _selectedSection == _SettingsSection.agentTypes,
                      onTap: () => setState(
                        () => _selectedSection = _SettingsSection.agentTypes,
                      ),
                    ),
                    SettingsNavItem(
                      icon: Icons.confirmation_number_outlined,
                      label: 'Issue Keys',
                      isSelected:
                          _selectedSection == _SettingsSection.predefinedIssues,
                      onTap: () => setState(
                        () => _selectedSection =
                            _SettingsSection.predefinedIssues,
                      ),
                    ),
                    SettingsNavItem(
                      icon: Icons.merge_type_rounded,
                      label: 'GitHub',
                      isSelected:
                          _selectedSection == _SettingsSection.github,
                      onTap: () => setState(
                        () =>
                            _selectedSection = _SettingsSection.github,
                      ),
                    ),
                    SettingsNavItem(
                      icon: Icons.confirmation_number_rounded,
                      label: 'Jira',
                      isSelected: _selectedSection == _SettingsSection.jira,
                      onTap: () => setState(
                        () => _selectedSection = _SettingsSection.jira,
                      ),
                    ),
                  ],
                ),
              ),
              // Right content area
              Expanded(child: _buildContent(context)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (_selectedSection) {
      case _SettingsSection.general:
        return const RepoGeneralSection();
      case _SettingsSection.vscodeConfigs:
        return const RepoVscodeConfigsSection();
      case _SettingsSection.customCommands:
        return const RepoCustomCommandsSection();
      case _SettingsSection.claudePrompts:
        return const RepoClaudePromptsSection();
      case _SettingsSection.agentTypes:
        return const RepoAgentTypesSection();
      case _SettingsSection.predefinedIssues:
        return const RepoPredefinedIssuesSection();
      case _SettingsSection.github:
        return const RepoGithubSection();
      case _SettingsSection.jira:
        return const RepoJiraSection();
    }
  }
}
