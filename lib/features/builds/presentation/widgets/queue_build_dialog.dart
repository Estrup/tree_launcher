import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tree_launcher/features/builds/data/azure_devops_service.dart';
import 'package:tree_launcher/features/builds/domain/azure_devops_config.dart';
import 'package:tree_launcher/features/builds/presentation/controllers/builds_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/branch_search_dropdown.dart';
import 'package:tree_launcher/theme/app_theme.dart';

class QueueBuildDialog extends StatefulWidget {
  final AzureDevopsConfig config;
  final int definitionId;
  final String? lastBranch;
  final Future<void> Function(String branch)? onBuildQueued;

  const QueueBuildDialog({
    super.key,
    required this.config,
    required this.definitionId,
    this.lastBranch,
    this.onBuildQueued,
  });

  @override
  State<QueueBuildDialog> createState() => _QueueBuildDialogState();
}

class _QueueBuildDialogState extends State<QueueBuildDialog> {
  String? _selectedBranch;
  bool _isQueuing = false;
  String? _errorMessage;
  List<String> _branches = [];
  bool _loadingBranches = true;

  @override
  void initState() {
    super.initState();
    _selectedBranch = widget.lastBranch;
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    try {
      final workspace = context.read<WorkspaceController>();
      final branches = await workspace.listBranches();
      if (mounted) {
        final lastBranch =
            widget.lastBranch != null && branches.contains(widget.lastBranch)
            ? widget.lastBranch
            : null;
        setState(() {
          _branches = branches;
          _loadingBranches = false;
          if (lastBranch != null) {
            _selectedBranch = lastBranch;
          } else if (_selectedBranch == null && branches.isNotEmpty) {
            _selectedBranch = branches.first;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingBranches = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _queueBuild() async {
    final branch = _selectedBranch;
    if (branch == null || branch.isEmpty) {
      setState(() => _errorMessage = 'Please select or enter a branch');
      return;
    }

    setState(() {
      _isQueuing = true;
      _errorMessage = null;
    });

    try {
      final result =
          await AzureDevopsService().queueBuild(widget.config, widget.definitionId, branch);
      if (!mounted) return;

      // Update the builds controller so the list refreshes.
      context.read<BuildsController>().onBuildQueued(
            widget.definitionId,
            result,
          );

      await widget.onBuildQueued?.call(branch);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isQueuing = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border),
      ),
      title: Text(
        'Start Build',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.3,
        ),
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'BRANCH',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            if (_loadingBranches)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              )
            else
              BranchSearchDropdown(
                branches: _branches,
                selectedBranch: _selectedBranch,
                enabled: !_isQueuing,
                onSelected: (branch) {
                  setState(() => _selectedBranch = branch);
                },
              ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isQueuing ? null : () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
        GestureDetector(
          onTap: _isQueuing ? null : _queueBuild,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _isQueuing
                  ? AppColors.accent.withValues(alpha: 0.5)
                  : AppColors.accent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: _isQueuing
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.base,
                    ),
                  )
                : Text(
                    'Start Build',
                    style: TextStyle(
                      color: AppColors.base,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
