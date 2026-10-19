import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_form_fields.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/activity/domain/predefined_issue.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/repo_settings/settings_controls.dart';

class RepoPredefinedIssuesSection extends StatefulWidget {
  const RepoPredefinedIssuesSection({super.key});

  @override
  State<RepoPredefinedIssuesSection> createState() =>
      _PredefinedIssuesSectionState();
}

class _PredefinedIssuesSectionState extends State<RepoPredefinedIssuesSection> {
  late List<PredefinedIssue> _issues;
  String? _lastRepoPath;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final repo = context.read<WorkspaceController>().selectedRepo;
    _lastRepoPath = repo?.path;
    _issues = List.from(repo?.predefinedIssues ?? []);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repo = context.read<WorkspaceController>().selectedRepo;
    if (repo != null && repo.path != _lastRepoPath) {
      _lastRepoPath = repo.path;
      _issues = List.from(repo.predefinedIssues);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _save() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final provider = context.read<WorkspaceController>();
      final repo = provider.selectedRepo;
      if (repo == null) return;
      final cleaned = _issues
          .where(
            (i) => i.key.trim().isNotEmpty || i.description.trim().isNotEmpty,
          )
          .map(
            (i) => PredefinedIssue(
              key: i.key.trim(),
              description: i.description.trim(),
            ),
          )
          .toList();
      provider.updateRepoPredefinedIssues(repo, cleaned);
    });
  }

  void _addIssue() {
    setState(() {
      _issues.add(PredefinedIssue(key: '', description: ''));
    });
  }

  void _removeIssue(int index) {
    setState(() {
      _issues.removeAt(index);
    });
    _save();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Issue Keys',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Reusable issue keys and descriptions. Pick from these '
                      'when logging a manual activity post.',
                      style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              SettingsAddButton(
                label: 'Add Issue',
                color: AppColors.accent,
                bgColor: AppColors.accent.withValues(alpha: 0.12),
                onTap: _addIssue,
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_issues.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface0,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.confirmation_number_outlined,
                    size: 32,
                    color: AppColors.textMuted.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No issue keys',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add issue keys to pick from when logging manual posts.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            )
          else
            ...List.generate(_issues.length, (index) {
              return _PredefinedIssueCard(
                key: ValueKey('issue_$index'),
                issue: _issues[index],
                onChanged: (i) {
                  setState(() => _issues[index] = i);
                  _save();
                },
                onRemove: () => _removeIssue(index),
              );
            }),
        ],
      ),
    );
  }
}

class _PredefinedIssueCard extends StatefulWidget {
  final PredefinedIssue issue;
  final ValueChanged<PredefinedIssue> onChanged;
  final VoidCallback onRemove;

  const _PredefinedIssueCard({
    super.key,
    required this.issue,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_PredefinedIssueCard> createState() => _PredefinedIssueCardState();
}

class _PredefinedIssueCardState extends State<_PredefinedIssueCard> {
  late final TextEditingController _keyController;
  late final TextEditingController _descController;

  @override
  void initState() {
    super.initState();
    _keyController = TextEditingController(text: widget.issue.key);
    _descController = TextEditingController(text: widget.issue.description);
  }

  @override
  void didUpdateWidget(_PredefinedIssueCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Cards are keyed by index, so removing one reuses State for a different
    // issue. Re-sync controllers when the underlying issue differs.
    if (widget.issue.key != _keyController.text) {
      _keyController.text = widget.issue.key;
    }
    if (widget.issue.description != _descController.text) {
      _descController.text = widget.issue.description;
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface0,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'KEY',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 160,
                child: TextField(
                  style: appFormFieldTextStyle(context),
                  decoration: const InputDecoration(hintText: 'e.g. AU2-1234'),
                  controller: _keyController,
                  onChanged: (v) =>
                      widget.onChanged(widget.issue.copyWith(key: v)),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DESCRIPTION',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  style: appFormFieldTextStyle(context),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Fix login redirect loop',
                  ),
                  controller: _descController,
                  onChanged: (v) =>
                      widget.onChanged(widget.issue.copyWith(description: v)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(top: 22),
            child: SettingsRemoveButton(onTap: widget.onRemove),
          ),
        ],
      ),
    );
  }
}
