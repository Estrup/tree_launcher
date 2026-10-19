import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tree_launcher/core/design_system/app_form_fields.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/workspace/domain/repo_config.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/repo_settings/repo_settings_section_state.dart';

class RepoJiraSection extends StatefulWidget {
  const RepoJiraSection({super.key});

  @override
  State<RepoJiraSection> createState() => _JiraSectionState();
}

class _JiraSectionState extends State<RepoJiraSection>
    with RepoSettingsSectionState {
  static final _projectKeyPattern = RegExp(r'^[A-Z][A-Z0-9_]+$');

  final _keyController = TextEditingController();

  @override
  void loadFrom(RepoConfig? repo) {
    _keyController.text = repo?.jiraProjectKey ?? '';
  }

  @override
  void dispose() {
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
    cancelSave();
    if (_keyError != null) return;
    saveLater(
      (provider, repo) =>
          provider.updateJiraProjectKey(repo, _keyController.text),
      delay: const Duration(milliseconds: 400),
    );
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
