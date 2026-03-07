import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tree_launcher/features/kanban/presentation/controllers/kanban_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';

class WorkspaceFlowCoordinator extends StatefulWidget {
  const WorkspaceFlowCoordinator({required this.child, super.key});

  final Widget child;

  @override
  State<WorkspaceFlowCoordinator> createState() =>
      _WorkspaceFlowCoordinatorState();
}

class _WorkspaceFlowCoordinatorState extends State<WorkspaceFlowCoordinator> {
  String? _lastRepoPath;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repoPath = context.watch<WorkspaceController>().selectedRepo?.path;
    if (repoPath == null || repoPath == _lastRepoPath) return;
    _lastRepoPath = repoPath;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<KanbanController>().loadProjectsForRepo(repoPath);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
