import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tree_launcher/features/builds/domain/azure_devops_config.dart';
import 'package:tree_launcher/features/builds/domain/build_result.dart';
import 'package:tree_launcher/features/builds/presentation/controllers/builds_controller.dart';
import 'package:tree_launcher/features/builds/presentation/widgets/queue_build_dialog.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:tree_launcher/theme/app_theme.dart';

class BuildsTab extends StatefulWidget {
  const BuildsTab({super.key});

  @override
  State<BuildsTab> createState() => _BuildsTabState();
}

class _BuildsTabState extends State<BuildsTab> {
  String? _lastLoadedRepoPath;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadIfNeeded();
  }

  void _loadIfNeeded() {
    final workspace = context.read<WorkspaceController>();
    final repo = workspace.selectedRepo;
    if (repo == null) return;

    final config = repo.azureDevopsConfig;
    if (config == null || !config.isConfigured) return;

    if (_lastLoadedRepoPath != repo.path) {
      _lastLoadedRepoPath = repo.path;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<BuildsController>().loadBuilds(config);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<WorkspaceController>();
    final builds = context.watch<BuildsController>();
    final repo = workspace.selectedRepo;
    final config = repo?.azureDevopsConfig;

    if (config == null || !config.isConfigured) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.build_circle_outlined,
                size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              'Configure Azure DevOps in repo settings',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (config.selectedPipelines.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.playlist_add, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              'Select build pipelines in repo settings',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Text(
                'Build Pipelines',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              if (builds.isLoading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                )
              else
                _HeaderAction(
                  icon: Icons.refresh,
                  tooltip: 'Refresh builds',
                  onTap: () => builds.refresh(config),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (builds.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline,
                      size: 16, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      builds.error!,
                      style: TextStyle(
                          color: AppColors.error, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        // Pipeline list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            itemCount: config.selectedPipelines.length,
            itemBuilder: (context, index) {
              final pipeline = config.selectedPipelines[index];
              final build = builds.latestBuilds[pipeline.id];
              return _BuildPipelineRow(
                pipelineName: pipeline.name,
                buildResult: build,
                onRun: () => _showQueueDialog(config, pipeline.id),
                onOpenInBrowser: build?.webUrl != null
                    ? () => Process.run('open', [build!.webUrl!])
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }

  void _showQueueDialog(AzureDevopsConfig config, int definitionId) {
    final workspace = context.read<WorkspaceController>();
    final repo = workspace.selectedRepo;
    showDialog(
      context: context,
      builder: (_) => QueueBuildDialog(
        config: config,
        definitionId: definitionId,
        lastBranch: repo?.lastAzureDevopsBranch,
        onBuildQueued: (branch) async {
          if (repo != null) {
            await workspace.updateLastAzureDevopsBranch(repo, branch);
          }
        },
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 18, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _BuildPipelineRow extends StatelessWidget {
  final String pipelineName;
  final BuildResult? buildResult;
  final VoidCallback onRun;
  final VoidCallback? onOpenInBrowser;

  const _BuildPipelineRow({
    required this.pipelineName,
    required this.buildResult,
    required this.onRun,
    this.onOpenInBrowser,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          // Status indicator
          _StatusDot(buildResult: buildResult),
          const SizedBox(width: 12),
          // Pipeline name
          Expanded(
            flex: 3,
            child: Text(
              pipelineName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          // Branch
          Expanded(
            flex: 2,
            child: buildResult?.branchName != null
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.account_tree,
                          size: 13, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          buildResult!.branchName!,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontFamily: 'monospace',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 12),
          // Commit
          SizedBox(
            width: 70,
            child: buildResult?.shortCommit != null
                ? Text(
                    buildResult!.shortCommit!,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      fontFamily: 'monospace',
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
          // Open in browser
          if (onOpenInBrowser != null)
            Tooltip(
              message: 'Open in Azure DevOps',
              child: InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: onOpenInBrowser,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.open_in_new,
                      size: 15, color: AppColors.textMuted),
                ),
              ),
            )
          else
            const SizedBox(width: 23),
          const SizedBox(width: 4),
          // Run build
          Tooltip(
            message: 'Start new build',
            child: InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: onRun,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.play_arrow_rounded,
                    size: 18, color: AppColors.accent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final BuildResult? buildResult;

  const _StatusDot({this.buildResult});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor;
    final isRunning =
        buildResult != null && buildResult!.status == BuildStatus.inProgress;

    return Tooltip(
      message: buildResult?.statusLabel ?? 'No builds',
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isRunning ? null : color,
          border: isRunning ? Border.all(color: color, width: 2) : null,
        ),
      ),
    );
  }

  Color get _statusColor {
    if (buildResult == null) return AppColors.textMuted;

    if (buildResult!.status == BuildStatus.completed) {
      switch (buildResult!.result) {
        case BuildResultType.succeeded:
          return AppColors.success;
        case BuildResultType.partiallySucceeded:
          return Colors.orange;
        case BuildResultType.failed:
          return AppColors.error;
        case BuildResultType.canceled:
          return AppColors.textMuted;
        case BuildResultType.none:
          return AppColors.textMuted;
      }
    }

    if (buildResult!.status == BuildStatus.inProgress) {
      return AppColors.accent;
    }

    return AppColors.textMuted;
  }
}
