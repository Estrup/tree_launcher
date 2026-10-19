import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';
import 'package:tree_launcher/features/settings/presentation/widgets/settings_small_button.dart';

class RepositoriesSettingsSection extends StatelessWidget {
  const RepositoriesSettingsSection({super.key});

  /// Replaces the home directory prefix with `~` to match the sidebar display.
  String _displayPath(String path) {
    final home = Platform.environment['HOME'];
    if (home != null && home.isNotEmpty && path.startsWith(home)) {
      return '~${path.substring(home.length)}';
    }
    return path;
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsController>();
    final hiddenRepos = settingsProvider.settings.hiddenRepos;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Repositories',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Repositories you've hidden from the sidebar",
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'HIDDEN REPOSITORIES',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          if (hiddenRepos.isEmpty)
            Text(
              'No hidden repositories',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            )
          else
            ...hiddenRepos.map(
              (path) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.folder_outlined,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            path.split('/').last,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _displayPath(path),
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                              fontFamily: 'monospace',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    SettingsSmallButton(
                      label: 'Unhide',
                      icon: Icons.visibility_rounded,
                      onTap: () => settingsProvider.unhideRepo(path),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
