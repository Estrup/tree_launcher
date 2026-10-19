import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_form_fields.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';

class RepoJiraSection extends StatefulWidget {
  const RepoJiraSection({super.key});

  @override
  State<RepoJiraSection> createState() => _JiraSectionState();
}

class _JiraSectionState extends State<RepoJiraSection> {
  static final _projectKeyPattern = RegExp(r'^[A-Z][A-Z0-9_]+$');

  late TextEditingController _keyController;
  String? _lastRepoPath;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final repo = context.read<WorkspaceController>().selectedRepo;
    _lastRepoPath = repo?.path;
    _keyController = TextEditingController(text: repo?.jiraProjectKey ?? '');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repo = context.read<WorkspaceController>().selectedRepo;
    if (repo != null && repo.path != _lastRepoPath) {
      _lastRepoPath = repo.path;
      _keyController.text = repo.jiraProjectKey ?? '';
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _keyController.dispose();
    super.dispose();
  }

  String? get _keyError {
    final key = _keyController.text.trim();
    if (key.isEmpty || _projectKeyPattern.hasMatch(key)) return null;
    return 'Use the project key, e.g. AU2';
  }

  void _save() {
    setState(() {});
    _debounce?.cancel();
    if (_keyError != null) return;
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final provider = context.read<WorkspaceController>();
      final repo = provider.selectedRepo;
      if (repo == null) return;
      provider.updateJiraProjectKey(repo, _keyController.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    final error = _keyError;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Jira',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Show a Jira tab listing the project\'s issues by fixVersion',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),
          Text(
            'PROJECT KEY',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 200,
            child: TextField(
              controller: _keyController,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                TextInputFormatter.withFunction(
                  (oldValue, newValue) =>
                      newValue.copyWith(text: newValue.text.toUpperCase()),
                ),
              ],
              style: appFormFieldTextStyle(context, monospace: true),
              decoration: InputDecoration(
                hintText: 'e.g. AU2',
                hintStyle: appFormFieldHintStyle(context, monospace: true),
                errorText: error,
              ),
              onChanged: (_) => _save(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Leave empty to hide the Jira tab. Uses the token in '
            '~/.config/jira-pat.txt.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
