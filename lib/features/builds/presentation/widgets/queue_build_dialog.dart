import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tree_launcher/features/builds/domain/azure_devops_config.dart';
import 'package:tree_launcher/features/builds/presentation/controllers/builds_controller.dart';
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
  final _searchController = TextEditingController();
  String? _selectedBranch;
  bool _isQueuing = false;
  String? _errorMessage;
  List<String> _filteredBranches = [];

  @override
  void initState() {
    super.initState();
    _selectedBranch = widget.lastBranch;
    if (_selectedBranch != null) {
      _searchController.text = _selectedBranch!;
    }
    _searchController.addListener(_filterBranches);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BuildsController>().loadBranches(widget.config);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterBranches() {
    final builds = context.read<BuildsController>();
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredBranches = builds.branches;
      } else {
        _filteredBranches = builds.branches
            .where((b) => b.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  Future<void> _queueBuild() async {
    final branch = _selectedBranch ?? _searchController.text.trim();
    if (branch.isEmpty) {
      setState(() => _errorMessage = 'Please select or enter a branch');
      return;
    }

    setState(() {
      _isQueuing = true;
      _errorMessage = null;
    });

    final builds = context.read<BuildsController>();
    final result = await builds.queueBuild(
      widget.config,
      widget.definitionId,
      branch,
    );

    if (!mounted) return;

    if (result != null) {
      await widget.onBuildQueued?.call(branch);
      if (mounted) Navigator.of(context).pop();
    } else {
      setState(() {
        _isQueuing = false;
        _errorMessage = builds.error ?? 'Failed to queue build';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final builds = context.watch<BuildsController>();

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
            const SizedBox(height: 6),
            TextField(
              controller: _searchController,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                fontFamily: 'monospace',
              ),
              decoration: InputDecoration(
                hintText: 'Search or enter branch name...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                  fontFamily: 'monospace',
                ),
                prefixIcon: Icon(Icons.search,
                    size: 18, color: AppColors.textMuted),
                suffixIcon: builds.isFetchingBranches
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accent,
                          ),
                        ),
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() => _selectedBranch = value);
              },
              onSubmitted: (_) => _queueBuild(),
            ),
            const SizedBox(height: 8),
            if (_filteredBranches.isNotEmpty ||
                (!builds.isFetchingBranches && builds.branches.isNotEmpty))
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: (_filteredBranches.isNotEmpty
                          ? _filteredBranches
                          : builds.branches)
                      .length,
                  itemBuilder: (context, index) {
                    final branches = _filteredBranches.isNotEmpty
                        ? _filteredBranches
                        : builds.branches;
                    final branch = branches[index];
                    final isSelected = branch == _selectedBranch;
                    return InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () {
                        setState(() {
                          _selectedBranch = branch;
                          _searchController.text = branch;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.accent.withValues(alpha: 0.1)
                              : null,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          branch,
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: isSelected
                                ? AppColors.accent
                                : AppColors.textSecondary,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  },
                ),
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
