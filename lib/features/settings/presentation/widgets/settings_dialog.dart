import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/core/storage/config_file.dart';
import 'package:tree_launcher/core/widgets/settings_nav_item.dart';
import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';
import 'package:tree_launcher/features/settings/presentation/widgets/agent_api_settings_section.dart';
import 'package:tree_launcher/features/settings/presentation/widgets/agent_types_settings_section.dart';
import 'package:tree_launcher/features/settings/presentation/widgets/help_settings_section.dart';
import 'package:tree_launcher/features/settings/presentation/widgets/jira_settings_section.dart';
import 'package:tree_launcher/features/settings/presentation/widgets/repositories_settings_section.dart';
import 'package:tree_launcher/features/settings/presentation/widgets/terminal_settings_section.dart';
import 'package:tree_launcher/features/settings/presentation/widgets/theme_settings_section.dart';
import 'package:tree_launcher/core/platform/open_external.dart';

enum _SettingsSection {
  theme,
  terminals,
  repositories,
  jira,
  agents,
  agentApi,
  help,
}

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<SettingsController>(),
        child: const SettingsDialog(),
      ),
    );
  }

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  _SettingsSection _selectedSection = _SettingsSection.theme;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 800,
        height: 600,
        child: Column(
          children: [
            // Header
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
                  Icon(
                    Icons.settings_outlined,
                    size: 20,
                    color: AppColors.textPrimary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => Navigator.pop(context),
                    splashRadius: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            // Body
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Nav
                  Container(
                    width: 200,
                    decoration: BoxDecoration(
                      color: AppColors.surface0,
                      border: Border(
                        right: BorderSide(
                          color: AppColors.borderSubtle,
                          width: 1,
                        ),
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
                          icon: Icons.palette_outlined,
                          label: 'Theme',
                          isSelected:
                              _selectedSection == _SettingsSection.theme,
                          onTap: () => setState(
                            () => _selectedSection = _SettingsSection.theme,
                          ),
                        ),
                        SettingsNavItem(
                          icon: Icons.terminal_rounded,
                          label: 'Terminals',
                          isSelected:
                              _selectedSection == _SettingsSection.terminals,
                          onTap: () => setState(
                            () => _selectedSection = _SettingsSection.terminals,
                          ),
                        ),
                        SettingsNavItem(
                          icon: Icons.folder_outlined,
                          label: 'Repositories',
                          isSelected:
                              _selectedSection == _SettingsSection.repositories,
                          onTap: () => setState(
                            () =>
                                _selectedSection = _SettingsSection.repositories,
                          ),
                        ),
                        SettingsNavItem(
                          icon: Icons.confirmation_number_outlined,
                          label: 'Jira',
                          isSelected: _selectedSection == _SettingsSection.jira,
                          onTap: () => setState(
                            () => _selectedSection = _SettingsSection.jira,
                          ),
                        ),
                        SettingsNavItem(
                          icon: Icons.smart_toy_outlined,
                          label: 'Agents',
                          isSelected:
                              _selectedSection == _SettingsSection.agents,
                          onTap: () => setState(
                            () => _selectedSection = _SettingsSection.agents,
                          ),
                        ),
                        SettingsNavItem(
                          icon: Icons.api_rounded,
                          label: 'Agent API',
                          isSelected:
                              _selectedSection == _SettingsSection.agentApi,
                          onTap: () => setState(
                            () => _selectedSection = _SettingsSection.agentApi,
                          ),
                        ),
                        const Spacer(),
                        SettingsNavItem(
                          icon: Icons.help_outline_rounded,
                          label: 'Help',
                          isSelected:
                              _selectedSection == _SettingsSection.help,
                          onTap: () => setState(
                            () => _selectedSection = _SettingsSection.help,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: _buildConfigFileLink(),
                        ),
                      ],
                    ),
                  ),
                  // Right Options
                  Expanded(
                    child: Container(
                      color: AppColors.surface0,
                      child: _buildContent(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (_selectedSection) {
      case _SettingsSection.theme:
        return const ThemeSettingsSection();
      case _SettingsSection.terminals:
        return const TerminalSettingsSection();
      case _SettingsSection.repositories:
        return const RepositoriesSettingsSection();
      case _SettingsSection.jira:
        return const JiraSettingsSection();
      case _SettingsSection.agents:
        return const AgentTypesSettingsSection();
      case _SettingsSection.agentApi:
        return const AgentApiSettingsSection();
      case _SettingsSection.help:
        return const HelpSettingsSection();
    }
  }

  Widget _buildConfigFileLink() {
    return FutureBuilder<String>(
      future: context.read<ConfigFile>().path,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final path = snapshot.data!;
        return GestureDetector(
          onTap: () => openExternal(path),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Text(
              path,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.accent,
                fontFamily: 'monospace',
                decoration: TextDecoration.underline,
                decorationColor: AppColors.accent.withValues(alpha: 0.4),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }
}
