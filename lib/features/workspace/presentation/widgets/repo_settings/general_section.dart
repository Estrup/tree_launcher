import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_form_fields.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:tree_launcher/features/workspace/domain/repo_config.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/repo_settings/repo_settings_section_state.dart';

class RepoGeneralSection extends StatefulWidget {
  const RepoGeneralSection({super.key});

  @override
  State<RepoGeneralSection> createState() => _GeneralSectionState();
}

class _GeneralSectionState extends State<RepoGeneralSection>
    with RepoSettingsSectionState {
  final _nameController = TextEditingController();

  @override
  void loadFrom(RepoConfig? repo) {
    _nameController.text = repo?.name ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _onNameChanged(String value) {
    saveLater((provider, repo) {
      final name = value.trim();
      if (name.isNotEmpty && name != repo.name) {
        provider.renameRepo(repo, name);
      }
    }, delay: const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<WorkspaceController>().selectedRepo;
    if (repo == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'General',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Basic repository configuration',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'DISPLAY NAME',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 400,
            child: TextField(
              controller: _nameController,
              style: appFormFieldTextStyle(context),
              decoration: const InputDecoration(hintText: 'Repository name'),
              onChanged: _onNameChanged,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'PATH',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 400,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface0,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Text(
              repo.path,
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'WORKTREE LOCATION',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 400,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nest worktrees in .worktrees/ subfolder',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'When on, new worktrees are created inside the repo '
                        'and kept out of git status. When off, they are created '
                        'alongside the repo. Does not apply to bare repos.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Switch.adaptive(
                  value: repo.useNestedWorktrees,
                  onChanged: (value) {
                    context.read<WorkspaceController>().updateUseNestedWorktrees(
                      repo,
                      value,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- VS Code Configs Section ---
