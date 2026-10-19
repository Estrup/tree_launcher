import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/github_prs/domain/github_config.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:tree_launcher/features/workspace/domain/repo_config.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/repo_settings/repo_settings_section_state.dart';

class RepoGithubSection extends StatefulWidget {
  const RepoGithubSection({super.key});

  @override
  State<RepoGithubSection> createState() => _GithubSectionState();
}

class _GithubSectionState extends State<RepoGithubSection>
    with RepoSettingsSectionState {
  final _ownerController = TextEditingController();
  final _repoController = TextEditingController();
  final _tokenController = TextEditingController();
  final _intervalController = TextEditingController();

  @override
  void loadFrom(RepoConfig? repo) {
    final config = repo?.githubConfig;
    _ownerController.text = config?.owner ?? '';
    _repoController.text = config?.repo ?? '';
    _tokenController.text = config?.token ?? '';
    _intervalController.text = (config?.prRefreshIntervalMinutes ?? 5)
        .toString();
  }

  @override
  void dispose() {
    _ownerController.dispose();
    _repoController.dispose();
    _tokenController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  void _saveConfig() {
    saveLater((provider, repo) {

      var owner = _ownerController.text.trim();
      final repoName = _repoController.text.trim();
      final token = _tokenController.text.trim();
      final interval =
          (int.tryParse(_intervalController.text.trim()) ?? 5).clamp(1, 1440);

      // Auto-parse if user pastes a full GitHub URL into the owner field
      if (owner.contains('github.com') && repoName.isEmpty) {
        final parsed = _parseGithubUrl(owner);
        if (parsed != null) {
          owner = parsed.$1;
          _ownerController.text = parsed.$1;
          _repoController.text = parsed.$2;
          final config = GithubConfig(
            owner: parsed.$1,
            repo: parsed.$2,
            token: token,
            prRefreshIntervalMinutes: interval,
            issuesEnabled: repo.githubConfig?.issuesEnabled ?? false,
          );
          provider.updateGithubConfig(repo, config);
          return;
        }
      }

      final config = (owner.isEmpty && repoName.isEmpty && token.isEmpty)
          ? null
          : GithubConfig(
              owner: owner,
              repo: repoName,
              token: token,
              prRefreshIntervalMinutes: interval,
              issuesEnabled: repo.githubConfig?.issuesEnabled ?? false,
            );
      provider.updateGithubConfig(repo, config);
    });
  }

  (String, String)? _parseGithubUrl(String input) {
    final uri = Uri.tryParse(input);
    if (uri != null && uri.host.contains('github.com')) {
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.length >= 2) {
        return (segments[0], segments[1]);
      }
    }
    // Try pattern: github.com/owner/repo
    final match = RegExp(r'github\.com/([^/]+)/([^/]+)').firstMatch(input);
    if (match != null) {
      return (match.group(1)!, match.group(2)!.replaceAll('.git', ''));
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GitHub',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Configure GitHub connection to view pull requests and issues',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 24),

          // Owner
          Text(
            'OWNER',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _ownerController,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
              hintText: 'owner (or paste full GitHub URL)',
              hintStyle: TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                fontFamily: 'monospace',
              ),
            ),
            onChanged: (_) => _saveConfig(),
          ),
          const SizedBox(height: 16),

          // Repo
          Text(
            'REPOSITORY',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _repoController,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
              hintText: 'repository-name',
              hintStyle: TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                fontFamily: 'monospace',
              ),
            ),
            onChanged: (_) => _saveConfig(),
          ),
          const SizedBox(height: 16),

          // Token
          Text(
            'PERSONAL ACCESS TOKEN',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _tokenController,
            obscureText: true,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
              hintText: 'ghp_...',
              hintStyle: TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                fontFamily: 'monospace',
              ),
            ),
            onChanged: (_) => _saveConfig(),
          ),
          const SizedBox(height: 16),
          Text(
            'Create a token at GitHub → Settings → Developer settings → Personal access tokens.\n'
            'Requires the "repo" scope for private repositories. A fine-grained token '
            'needs Issues: read and write for the Issues tab.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          // Auto-refresh interval
          Text(
            'AUTO-REFRESH INTERVAL (MINUTES)',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 120,
            child: TextField(
              controller: _intervalController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                fontFamily: 'monospace',
              ),
              decoration: InputDecoration(
                hintText: '5',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                  fontFamily: 'monospace',
                ),
              ),
              onChanged: (_) => _saveConfig(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'How often the pull request list refreshes (minimum 1 minute). '
            'Refreshing runs in the background even when this tab is not open.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          _issuesSwitch(),
        ],
      ),
    );
  }

  /// Turns the repo's Issues tab on or off. Needs a connection first.
  Widget _issuesSwitch() {
    final repo = context.watch<WorkspaceController>().selectedRepo;
    final config = repo?.githubConfig;
    return SizedBox(
      width: 400,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Show issues tab',
                  style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  'Lists the repository\'s GitHub issues in an Issues tab, '
                  'like the Jira tab. Leave off for repos whose issues live '
                  'elsewhere.',
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
            value: config?.issuesEnabled ?? false,
            onChanged: repo == null || config == null
                ? null
                : (value) => context.read<WorkspaceController>().updateGithubConfig(
                    repo,
                    config.copyWith(issuesEnabled: value),
                  ),
          ),
        ],
      ),
    );
  }
}

// --- Jira Section ---
