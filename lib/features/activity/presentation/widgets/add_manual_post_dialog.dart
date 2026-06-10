import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tree_launcher/core/design_system/app_form_fields.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/workspace/domain/repo_config.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_naming.dart';
import 'package:tree_launcher/models/predefined_issue.dart';

/// The fields captured when logging a manual activity post. The date is implied
/// (always "now"); the description comes from the picked predefined issue, or
/// is typed freely for a custom issue key.
class AddManualPostResult {
  final String issueKey;
  final String description;
  final double? hours;

  const AddManualPostResult({
    required this.issueKey,
    this.description = '',
    this.hours,
  });
}

/// Dialog for logging work done outside any worktree against an issue key.
///
/// When the repo has predefined issues, the key is picked from them (auto-
/// filling the description) or "Custom issue…" reveals free-text key and
/// description fields. Without presets the key is typed directly.
class AddManualPostDialog extends StatefulWidget {
  final RepoConfig repo;

  const AddManualPostDialog({super.key, required this.repo});

  static Future<AddManualPostResult?> show(
    BuildContext context, {
    required RepoConfig repo,
  }) {
    return showDialog<AddManualPostResult>(
      context: context,
      builder: (_) => AddManualPostDialog(repo: repo),
    );
  }

  @override
  State<AddManualPostDialog> createState() => _AddManualPostDialogState();
}

class _AddManualPostDialogState extends State<AddManualPostDialog> {
  /// Sentinel dropdown entry for typing an arbitrary issue key; compared by
  /// identity since real presets may legitimately have any field values.
  static final PredefinedIssue _customIssue =
      PredefinedIssue(key: '', description: '');

  final _keyController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _hoursController = TextEditingController();

  PredefinedIssue? _selectedIssue;
  String _description = '';
  String? _error;

  List<PredefinedIssue> get _presets => widget.repo.predefinedIssues;

  bool get _isCustom =>
      _presets.isEmpty || identical(_selectedIssue, _customIssue);

  @override
  void initState() {
    super.initState();
    if (_presets.isNotEmpty) {
      _selectIssue(_presets.first);
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    _descriptionController.dispose();
    _hoursController.dispose();
    super.dispose();
  }

  void _selectIssue(PredefinedIssue issue) {
    setState(() {
      _selectedIssue = issue;
      _description = issue.description;
      _keyController.text = identical(issue, _customIssue) ? '' : issue.key;
      _error = null;
    });
  }

  void _submit() {
    final issueKey = _keyController.text.trim();
    if (issueKey.isEmpty) {
      setState(() => _error = 'Issue key is required');
      return;
    }
    final jiraError = validateJiraKey(issueKey);
    if (jiraError != null) {
      setState(() => _error = jiraError);
      return;
    }

    double? hours;
    final hoursText = _hoursController.text.trim();
    if (hoursText.isNotEmpty) {
      hours = double.tryParse(hoursText.replaceAll(',', '.'));
      if (hours == null || hours < 0) {
        setState(() => _error = 'Hours must be a positive number');
        return;
      }
    }

    Navigator.pop(
      context,
      AddManualPostResult(
        issueKey: issueKey,
        description:
            _isCustom ? _descriptionController.text.trim() : _description,
        hours: hours,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPresets = _presets.isNotEmpty;

    return AlertDialog(
      backgroundColor: AppColors.surface1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border),
      ),
      title: Text(
        'Log Activity',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.3,
        ),
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel('REPO'),
              const SizedBox(height: 8),
              Text(
                widget.repo.name,
                style: appFormFieldTextStyle(context),
              ),
              const SizedBox(height: 16),

              _sectionLabel('ISSUE'),
              const SizedBox(height: 8),
              if (hasPresets) ...[
                AppDropdownField<PredefinedIssue>(
                  initialValue: _selectedIssue,
                  items: [
                    for (final issue in _presets)
                      DropdownMenuItem(
                        value: issue,
                        child: Text(
                          issue.description.isEmpty
                              ? issue.key
                              : '${issue.key} — ${issue.description}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    DropdownMenuItem(
                      value: _customIssue,
                      child: const Text('Custom issue…'),
                    ),
                  ],
                  onChanged: (issue) {
                    if (issue != null) _selectIssue(issue);
                  },
                ),
              ],
              if (_isCustom) ...[
                if (hasPresets) const SizedBox(height: 8),
                TextField(
                  controller: _keyController,
                  autofocus: true,
                  style: appFormFieldTextStyle(context, monospace: true),
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'e.g. AU2-1234',
                    hintStyle: appFormFieldHintStyle(context, monospace: true),
                  ),
                  onChanged: (_) => setState(() => _error = null),
                  onSubmitted: (_) => _submit(),
                ),
                if (!hasPresets) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Tip: add reusable issue keys in repo settings to pick '
                    'them here.',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
                const SizedBox(height: 16),

                _sectionLabel('DESCRIPTION (OPTIONAL)'),
                const SizedBox(height: 8),
                TextField(
                  controller: _descriptionController,
                  style: appFormFieldTextStyle(context),
                  decoration: InputDecoration(
                    hintText: 'Shown in the activity timeline',
                    hintStyle: appFormFieldHintStyle(context),
                  ),
                  onChanged: (_) => setState(() => _error = null),
                  onSubmitted: (_) => _submit(),
                ),
              ],

              const SizedBox(height: 16),

              _sectionLabel('HOURS (OPTIONAL)'),
              const SizedBox(height: 8),
              TextField(
                controller: _hoursController,
                style: appFormFieldTextStyle(context),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: InputDecoration(
                  hintText: 'e.g. 2',
                  hintStyle: appFormFieldHintStyle(context),
                ),
                onChanged: (_) => setState(() => _error = null),
                onSubmitted: (_) => _submit(),
              ),

              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: TextStyle(fontSize: 11, color: AppColors.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
        ),
        GestureDetector(
          onTap: _submit,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Log',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.base,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
        letterSpacing: 1.2,
      ),
    );
  }
}
