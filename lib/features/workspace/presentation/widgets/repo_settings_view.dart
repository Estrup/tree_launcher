import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/repo_settings/claude_prompts_section.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/repo_settings/custom_commands_section.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/repo_settings/general_section.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/repo_settings/github_section.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/repo_settings/jira_section.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/repo_settings/predefined_issues_section.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/repo_settings/settings_controls.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/repo_settings/vscode_configs_section.dart';

enum _SettingsSection {
  general,
  vscodeConfigs,
  customCommands,
  claudePrompts,
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
                    _NavItem(
                      icon: Icons.info_outline_rounded,
                      label: 'General',
                      isSelected: _selectedSection == _SettingsSection.general,
                      onTap: () => setState(
                        () => _selectedSection = _SettingsSection.general,
                      ),
                    ),
                    _NavItem(
                      icon: Icons.code_rounded,
                      label: 'VS Code Configs',
                      isSelected:
                          _selectedSection == _SettingsSection.vscodeConfigs,
                      onTap: () => setState(
                        () => _selectedSection = _SettingsSection.vscodeConfigs,
                      ),
                    ),
                    _NavItem(
                      icon: Icons.terminal_rounded,
                      label: 'Custom Commands',
                      isSelected:
                          _selectedSection == _SettingsSection.customCommands,
                      onTap: () => setState(
                        () =>
                            _selectedSection = _SettingsSection.customCommands,
                      ),
                    ),
                    _NavItem(
                      icon: Icons.auto_awesome_rounded,
                      label: 'Claude Prompts',
                      isSelected:
                          _selectedSection == _SettingsSection.claudePrompts,
                      onTap: () => setState(
                        () =>
                            _selectedSection = _SettingsSection.claudePrompts,
                      ),
                    ),
                    _NavItem(
                      icon: Icons.confirmation_number_outlined,
                      label: 'Issue Keys',
                      isSelected:
                          _selectedSection == _SettingsSection.predefinedIssues,
                      onTap: () => setState(
                        () => _selectedSection =
                            _SettingsSection.predefinedIssues,
                      ),
                    ),
                    _NavItem(
                      icon: Icons.merge_type_rounded,
                      label: 'GitHub',
                      isSelected:
                          _selectedSection == _SettingsSection.github,
                      onTap: () => setState(
                        () =>
                            _selectedSection = _SettingsSection.github,
                      ),
                    ),
                    _NavItem(
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
      case _SettingsSection.predefinedIssues:
        return const RepoPredefinedIssuesSection();
      case _SettingsSection.github:
        return const RepoGithubSection();
      case _SettingsSection.jira:
        return const RepoJiraSection();
    }
  }
}

// --- Nav Item ---

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppColors.surface2
                : _hovered
                ? AppColors.surface1
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 16,
                color: widget.isSelected
                    ? AppColors.accent
                    : AppColors.textMuted,
              ),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: widget.isSelected
                      ? FontWeight.w600
                      : FontWeight.w500,
                  color: widget.isSelected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- General Section ---
