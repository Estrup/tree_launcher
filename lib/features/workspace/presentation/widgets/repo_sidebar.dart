import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/copilot/domain/copilot_session.dart';
import 'package:tree_launcher/features/copilot/presentation/widgets/copilot_status_dot.dart';
import 'package:tree_launcher/features/workspace/domain/repo_config.dart';
import 'package:tree_launcher/providers/copilot_provider.dart';
import 'package:tree_launcher/providers/repo_provider.dart';

class RepoSidebar extends StatelessWidget {
  final VoidCallback onAddRepo;
  final VoidCallback onOpenSettings;

  const RepoSidebar({
    super.key,
    required this.onAddRepo,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final repoProvider = context.watch<RepoProvider>();

    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: AppColors.surface0,
        border: Border(
          right: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Logo / brand
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.accentMuted,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(
                    Icons.account_tree_rounded,
                    size: 16,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'TreeLauncher',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Section label
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Row(
              children: [
                Text(
                  'REPOSITORIES',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted.withValues(alpha: 0.7),
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),

          // Repo list
          Expanded(
            flex: 3,
            child: repoProvider.repos.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 24),
                        Icon(
                          Icons.folder_open_rounded,
                          size: 36,
                          color: AppColors.textMuted.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No repos yet',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: repoProvider.repos.length,
                    itemBuilder: (context, index) {
                      final repo = repoProvider.repos[index];
                      final isSelected = repo == repoProvider.selectedRepo;
                      return _RepoTile(
                        repo: repo,
                        isSelected: isSelected,
                        onTap: () {
                          final copilotProvider = context
                              .read<CopilotProvider>();
                          copilotProvider.deselectSession();
                          repoProvider.selectRepo(repo);
                        },
                        onRemove: () =>
                            _confirmRemove(context, repoProvider, repo),
                        onSettings: () {
                          repoProvider.selectRepo(repo);
                          if (!repoProvider.showSettings) {
                            repoProvider.toggleSettings();
                          }
                        },
                      );
                    },
                  ),
          ),

          // Copilots section
          _CopilotsSidebarSection(),

          // Bottom bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.borderSubtle, width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(child: _AddRepoButton(onPressed: onAddRepo)),
                const SizedBox(width: 8),
                _SettingsButton(onPressed: onOpenSettings),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmRemove(
    BuildContext context,
    RepoProvider provider,
    RepoConfig repo,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Repository'),
        content: Text('Remove "${repo.name}" from TreeLauncher?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              provider.removeRepo(repo);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

// --- Repo tile with left accent bar ---

class _RepoTile extends StatefulWidget {
  final RepoConfig repo;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final VoidCallback onSettings;

  const _RepoTile({
    required this.repo,
    required this.isSelected,
    required this.onTap,
    required this.onRemove,
    required this.onSettings,
  });

  @override
  State<_RepoTile> createState() => _RepoTileState();
}

class _RepoTileState extends State<_RepoTile> {
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
          margin: const EdgeInsets.only(bottom: 2),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppColors.surface2
                : _hovered
                ? AppColors.surface1
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Left accent bar
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 3,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: widget.isSelected
                        ? AppColors.accent
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.repo.name,
                          overflow: TextOverflow.ellipsis,
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
                        const SizedBox(height: 2),
                        Text(
                          widget.repo.path.replaceFirst(
                            RegExp(r'^/Users/[^/]+'),
                            '~',
                          ),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textMuted,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Action icons (only on hover)
                if (_hovered || widget.isSelected)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _TinyIconButton(
                        icon: Icons.edit_rounded,
                        onTap: widget.onSettings,
                      ),
                      _TinyIconButton(
                        icon: Icons.close_rounded,
                        onTap: widget.onRemove,
                      ),
                    ],
                  ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TinyIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TinyIconButton({required this.icon, required this.onTap});

  @override
  State<_TinyIconButton> createState() => _TinyIconButtonState();
}

class _TinyIconButtonState extends State<_TinyIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.surfaceHover : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            widget.icon,
            size: 14,
            color: _hovered ? AppColors.textPrimary : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

// --- Bottom bar buttons ---

class _AddRepoButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _AddRepoButton({required this.onPressed});

  @override
  State<_AddRepoButton> createState() => _AddRepoButtonState();
}

class _AddRepoButtonState extends State<_AddRepoButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 36,
          decoration: BoxDecoration(
            color: _hovered ? AppColors.accent : AppColors.accentMuted,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hovered
                  ? AppColors.accent
                  : AppColors.accent.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_rounded,
                size: 16,
                color: _hovered ? AppColors.base : AppColors.accent,
              ),
              const SizedBox(width: 6),
              Text(
                'Add Repo',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _hovered ? AppColors.base : AppColors.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _SettingsButton({required this.onPressed});

  @override
  State<_SettingsButton> createState() => _SettingsButtonState();
}

class _SettingsButtonState extends State<_SettingsButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _hovered ? AppColors.surface2 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(
            Icons.tune_rounded,
            size: 16,
            color: _hovered ? AppColors.textPrimary : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

// --- Copilots sidebar section ---

class _CopilotsSidebarSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final repoProvider = context.watch<RepoProvider>();
    final copilotProvider = context.watch<CopilotProvider>();
    final sessions = repoProvider.allCopilotSessions;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 12,
                  color: AppColors.copilot.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 6),
                Text(
                  'COPILOTS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted.withValues(alpha: 0.7),
                    letterSpacing: 1.2,
                  ),
                ),
                if (copilotProvider.hasAnyActivity) ...[
                  const SizedBox(width: 6),
                  CopilotStatusDot(
                    status: copilotProvider.aggregateStatus,
                    size: 6,
                  ),
                ],
              ],
            ),
          ),
          if (sessions.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                'No copilot sessions',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted.withValues(alpha: 0.5),
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: sessions.length,
                itemBuilder: (context, index) {
                  final session = sessions[index];
                  final isActive =
                      copilotProvider.activeSession?.id == session.id;
                  final repoName = repoProvider.repos
                      .where((r) => r.path == session.repoPath)
                      .map((r) => r.name)
                      .firstOrNull;
                  return _CopilotTile(
                    session: session,
                    repoName: repoName,
                    isActive: isActive,
                    activityStatus: copilotProvider.statusForSession(
                      session.id,
                    ),
                    onTap: () => copilotProvider.selectSession(session),
                    onRemove: () => copilotProvider.removeSession(session),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _CopilotTile extends StatefulWidget {
  final CopilotSession session;
  final String? repoName;
  final bool isActive;
  final CopilotActivityStatus activityStatus;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _CopilotTile({
    required this.session,
    this.repoName,
    required this.isActive,
    required this.activityStatus,
    required this.onTap,
    required this.onRemove,
  });

  @override
  State<_CopilotTile> createState() => _CopilotTileState();
}

class _CopilotTileState extends State<_CopilotTile> {
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
          margin: const EdgeInsets.only(bottom: 2),
          decoration: BoxDecoration(
            color: widget.isActive
                ? AppColors.copilot.withValues(alpha: 0.12)
                : _hovered
                ? AppColors.surface1
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 3,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: widget.isActive
                        ? AppColors.copilot
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 12,
                  color: widget.isActive
                      ? AppColors.copilot
                      : AppColors.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      widget.repoName != null
                          ? '${_repoAbbreviation(widget.repoName!)}:${widget.session.name}'
                          : widget.session.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: widget.isActive
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: widget.isActive
                            ? AppColors.copilot
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                if (widget.activityStatus != CopilotActivityStatus.idle) ...[
                  CopilotStatusDot(status: widget.activityStatus, size: 7),
                  const SizedBox(width: 4),
                ],
                if (_hovered || widget.isActive)
                  _TinyIconButton(
                    icon: Icons.close_rounded,
                    onTap: widget.onRemove,
                  ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _repoAbbreviation(String repoName) {
  if (repoName.contains('_') || repoName.contains('.')) {
    final parts = repoName.split(RegExp(r'[_.]'));
    return parts
        .where((p) => p.isNotEmpty)
        .take(3)
        .map((p) => p[0].toUpperCase())
        .join();
  }
  return repoName.substring(0, repoName.length.clamp(0, 3)).toUpperCase();
}
