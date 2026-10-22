import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_form_fields.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/core/errors/user_message.dart';
import 'package:tree_launcher/features/jira/data/jira_api_service.dart';
import 'package:tree_launcher/features/jira/domain/jira_version.dart';
import 'package:tree_launcher/features/jira/presentation/widgets/jira_trigger_check_bar.dart';
import 'package:tree_launcher/features/workspace/domain/repo_config.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/branch_search_dropdown.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/repo_settings/repo_settings_section_state.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/repo_settings/jira_triggers_list.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/repo_settings/settings_controls.dart';

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
    final savedKey = context
        .watch<WorkspaceController>()
        .selectedRepo
        ?.jiraProjectKey;
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
          if (savedKey != null) ...[
            const SizedBox(height: 32),
            _VersionRules(key: ValueKey(savedKey), projectKey: savedKey),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: AppColors.textMuted,
      letterSpacing: 1.2,
    ),
  );
}

/// What the repo does per fixVersion: the versions mapped to a default base
/// branch, each with its branch and a row to map another version, and the
/// Jira triggers.
class _VersionRules extends StatefulWidget {
  const _VersionRules({super.key, required this.projectKey});

  final String projectKey;

  @override
  State<_VersionRules> createState() => _VersionRulesState();
}

class _VersionRulesState extends State<_VersionRules> {
  List<JiraVersion>? _versions;
  List<String> _branches = const [];
  String? _error;

  /// Whether the row for a new mapping is shown.
  bool _adding = false;

  /// The version picked in the new mapping's row.
  String? _newVersionId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final jira = context.read<JiraApiService>();
    final workspace = context.read<WorkspaceController>();
    try {
      final (versions, branches) = await (
        jira.fetchVersions(widget.projectKey),
        workspace.listBranches().catchError((_) => <String>[]),
      ).wait;
      if (!mounted) return;
      setState(() {
        _versions = versions;
        _branches = branches;
      });
    } catch (e) {
      final error = e is ParallelWaitError ? e.errors.$1 : e;
      if (mounted) setState(() => _error = userMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final versions = _versions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('DEFAULT BRANCH PER FIXVERSION'),
        const SizedBox(height: 4),
        Text(
          'A new worktree for an issue in the version starts from this '
          'branch.',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(height: 12),
        _mappings(context),
        if (versions != null) ...[
          const SizedBox(height: 32),
          _SectionLabel('TRIGGERS'),
          const SizedBox(height: 4),
          Text(
            'When an issue in the version moves to the status or is created, '
            'a Claude session starts with the prompt. Only changes after a '
            'trigger is turned on or edited count. How often Jira is checked '
            'is set in Settings → Jira.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          const JiraTriggerCheckBar(),
          const SizedBox(height: 8),
          JiraTriggersList(versions: versions),
        ],
      ],
    );
  }

  Widget _mappings(BuildContext context) {
    final workspace = context.watch<WorkspaceController>();
    final mapped = workspace.selectedRepo?.jiraVersionBranches ?? const {};
    if (_error != null) {
      return Text(
        "Couldn't load the fixVersions: $_error",
        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
      );
    }
    final versions = _versions;
    if (versions == null) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    // A mapped version Jira no longer lists shows its id.
    String nameOf(String id) =>
        versions.where((v) => v.id == id).firstOrNull?.name ?? id;
    final unmapped = [
      for (final v in orderVersionsForPicker(versions))
        if (!v.released && !mapped.containsKey(v.id)) v,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final MapEntry(key: id, value: branch) in mapped.entries)
          _row(
            version: Text(
              nameOf(id),
              overflow: TextOverflow.ellipsis,
              style: appFormFieldTextStyle(context),
            ),
            branch: BranchSearchDropdown(
              key: ValueKey(id),
              branches: _branches,
              selectedBranch: branch,
              reportTyped: false,
              onSelected: (branch) => _save(id, branch),
            ),
            onRemove: () => _save(id, null),
          ),
        if (_adding)
          _row(
            version: AppDropdownField<String>(
              initialValue: _newVersionId,
              decoration: const InputDecoration(hintText: 'fixVersion'),
              items: [
                for (final v in unmapped)
                  DropdownMenuItem(
                    value: v.id,
                    child: Text(v.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (id) => setState(() => _newVersionId = id),
            ),
            branch: BranchSearchDropdown(
              branches: _branches,
              enabled: _newVersionId != null,
              reportTyped: false,
              onSelected: (branch) {
                final id = _newVersionId;
                if (id == null) return;
                setState(() {
                  _adding = false;
                  _newVersionId = null;
                });
                _save(id, branch);
              },
            ),
            onRemove: () => setState(() {
              _adding = false;
              _newVersionId = null;
            }),
          ),
        if (mapped.isEmpty && !_adding)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'No fixVersion has a default branch.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
        if (!_adding && unmapped.isNotEmpty)
          SettingsAddButton(
            label: 'Add Mapping',
            color: AppColors.accent,
            bgColor: AppColors.accent.withValues(alpha: 0.12),
            onTap: () => setState(() => _adding = true),
          ),
      ],
    );
  }

  Widget _row({
    required Widget version,
    required Widget branch,
    required VoidCallback onRemove,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        SizedBox(width: 200, child: version),
        const SizedBox(width: 12),
        SizedBox(width: 320, child: branch),
        const SizedBox(width: 4),
        SettingsRemoveButton(onTap: onRemove),
      ],
    ),
  );

  void _save(String versionId, String? branch) {
    final workspace = context.read<WorkspaceController>();
    final repo = workspace.selectedRepo;
    if (repo == null) return;
    workspace.updateJiraVersionBranch(repo, versionId, branch);
  }
}
