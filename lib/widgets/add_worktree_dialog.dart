import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/repo_provider.dart';
import '../providers/settings_provider.dart';
import '../services/launcher_service.dart';
import '../theme/app_theme.dart';
import 'branch_search_dropdown.dart';

class AddWorktreeDialog extends StatefulWidget {
  const AddWorktreeDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<RepoProvider>(),
        child: const AddWorktreeDialog(),
      ),
    );
  }

  @override
  State<AddWorktreeDialog> createState() => _AddWorktreeDialogState();
}

class _AddWorktreeDialogState extends State<AddWorktreeDialog> {
  final _launcherService = LauncherService();
  final _nameController = TextEditingController();
  final _jiraController = TextEditingController();
  final _newBranchController = TextEditingController();
  final _promptController = TextEditingController();
  String? _selectedBranch;
  bool _launchTerminal = false;
  String? _error;
  bool _creating = false;
  List<String> _branches = [];
  bool _loadingBranches = true;
  bool _branchManuallyEdited = false;

  static const _defaultPrompt =
      'Retrieve the jira issue {issue} with comments and files. '
      'Analyse the issue and problem relating to the codebase. '
      'Try to find a solution';

  @override
  void initState() {
    super.initState();
    _promptController.text = _defaultPrompt;
    _loadBranches();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _jiraController.dispose();
    _newBranchController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _loadBranches() async {
    try {
      final repoProvider = context.read<RepoProvider>();
      final branches = await repoProvider.listBranches();
      if (mounted) {
        final lastBaseBranch = repoProvider.selectedRepo?.lastBaseBranch;
        setState(() {
          _branches = branches;
          _loadingBranches = false;
          if (branches.isNotEmpty) {
            if (lastBaseBranch != null && branches.contains(lastBaseBranch)) {
              _selectedBranch = lastBaseBranch;
            } else {
              _selectedBranch = branches.first;
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingBranches = false);
      }
    }
  }

  void _updateAutoFillBranch() {
    if (_branchManuallyEdited) return;
    final prefix = context
        .read<SettingsProvider>()
        .settings
        .defaultBranchPrefix;
    final name = _effectiveWorktreeName;
    if (name.isEmpty) {
      _newBranchController.text = '';
    } else if (prefix != null && prefix.isNotEmpty) {
      _newBranchController.text = '$prefix/$name';
    } else {
      _newBranchController.text = name;
    }
  }

  String? _validateName(String value) {
    if (value.isEmpty) return null;
    if (value.contains(' ')) return 'No spaces allowed';
    if (value != value.toLowerCase()) return 'Must be lowercase';
    if (!RegExp(r'^[a-z0-9._\-]+$').hasMatch(value)) {
      return 'Only a-z, 0-9, ., -, _ allowed';
    }
    return null;
  }

  String? _validateJira(String value) {
    if (value.isEmpty) return null;
    if (!RegExp(r'^[A-Z][A-Z0-9]+-\d+$').hasMatch(value)) {
      return 'Format: AU2-0001';
    }
    return null;
  }

  String get _effectiveWorktreeName {
    final name = _nameController.text.trim();
    final jira = _jiraController.text.trim();
    if (jira.isNotEmpty && _validateJira(jira) == null) {
      return '$name-${jira.toLowerCase()}';
    }
    return name;
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final nameError = _validateName(name);
    if (nameError != null) {
      setState(() => _error = nameError);
      return;
    }

    final jira = _jiraController.text.trim();
    if (jira.isNotEmpty) {
      final jiraError = _validateJira(jira);
      if (jiraError != null) {
        setState(() => _error = jiraError);
        return;
      }
    }

    setState(() {
      _creating = true;
      _error = null;
    });

    try {
      final repoProvider = context.read<RepoProvider>();
      final worktreeName = _effectiveWorktreeName;
      final newBranch = _newBranchController.text.trim();

      final worktreePath = await repoProvider.addWorktree(
        worktreeName,
        baseBranch: _selectedBranch,
        newBranch: newBranch.isNotEmpty ? newBranch : null,
      );

      // Save last used base branch for this repo
      if (_selectedBranch != null && repoProvider.selectedRepo != null) {
        await repoProvider.updateLastBaseBranch(
          repoProvider.selectedRepo!,
          _selectedBranch!,
        );
      }

      if (_launchTerminal && worktreePath != null) {
        await _launchGhosttyTerminal(worktreePath, jira);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _creating = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _launchGhosttyTerminal(String path, String jiraIssue) async {
    var prompt = _promptController.text.trim();
    if (jiraIssue.isNotEmpty) {
      prompt = prompt.replaceAll('{issue}', jiraIssue);
    } else {
      prompt = prompt.replaceAll('{issue}', '');
    }
    prompt = prompt.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (prompt.isNotEmpty) {
      final escapedPrompt = prompt.replaceAll("'", "'\\''");
      await _launcherService.openGhosttyWithCommand(
        path,
        "copilot -i '$escapedPrompt'",
      );
      return;
    }

    await _launcherService.openGhostty(path);
  }

  @override
  Widget build(BuildContext context) {
    final nameError = _validateName(_nameController.text);
    final jiraError = _validateJira(_jiraController.text);
    final hasError = _error != null || nameError != null;
    final displayError = _error ?? nameError;

    return AlertDialog(
      backgroundColor: AppColors.surface1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      title: const Text(
        'New Worktree',
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
              // Worktree Name
              _sectionLabel('WORKTREE NAME'),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                autofocus: true,
                enabled: !_creating,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontFamily: 'monospace',
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.deny(
                    RegExp(r'[A-Z\s]'),
                    replacementString: '',
                  ),
                ],
                decoration: _inputDecoration(
                  hint: 'e.g. feature-auth',
                  hasError: hasError,
                ),
                onChanged: (_) {
                  setState(() => _error = null);
                  _updateAutoFillBranch();
                },
                onSubmitted: (_) => _submit(),
              ),
              if (displayError != null) ...[
                const SizedBox(height: 6),
                Text(
                  displayError,
                  style: const TextStyle(fontSize: 11, color: AppColors.error),
                ),
              ],

              const SizedBox(height: 16),

              // JIRA Issue No.
              _sectionLabel('JIRA ISSUE NO. (OPTIONAL)'),
              const SizedBox(height: 8),
              TextField(
                controller: _jiraController,
                enabled: !_creating,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontFamily: 'monospace',
                ),
                textCapitalization: TextCapitalization.characters,
                decoration: _inputDecoration(
                  hint: 'e.g. AU2-0001',
                  hasError: jiraError != null,
                ),
                onChanged: (_) {
                  setState(() => _error = null);
                  _updateAutoFillBranch();
                },
              ),
              if (jiraError != null) ...[
                const SizedBox(height: 6),
                Text(
                  jiraError,
                  style: const TextStyle(fontSize: 11, color: AppColors.error),
                ),
              ],
              if (_jiraController.text.isNotEmpty &&
                  jiraError == null &&
                  _nameController.text.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Worktree: $_effectiveWorktreeName',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted.withValues(alpha: 0.6),
                    fontFamily: 'monospace',
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Base Branch
              _sectionLabel('BASE BRANCH'),
              const SizedBox(height: 8),
              if (_loadingBranches)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
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
                  enabled: !_creating,
                  onSelected: (branch) {
                    setState(() => _selectedBranch = branch);
                  },
                ),

              const SizedBox(height: 16),

              // New Branch
              _sectionLabel('NEW BRANCH'),
              const SizedBox(height: 8),
              TextField(
                controller: _newBranchController,
                enabled: !_creating,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontFamily: 'monospace',
                ),
                decoration: _inputDecoration(
                  hint: 'Auto-filled from worktree name',
                  hasError: false,
                ),
                onChanged: (value) {
                  if (value.isEmpty) {
                    _branchManuallyEdited = false;
                  } else {
                    _branchManuallyEdited = true;
                  }
                },
              ),

              const SizedBox(height: 16),

              // Launch Terminal
              _buildTerminalSection(),

              const SizedBox(height: 12),
              Text(
                'Created in the same folder as the repository.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _creating ? null : () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
        GestureDetector(
          onTap: _creating ? null : _submit,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: _creating
                  ? AppColors.accent.withValues(alpha: 0.5)
                  : AppColors.accent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: _creating
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.base,
                    ),
                  )
                : const Text(
                    'Create',
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

  Widget _buildTerminalSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: _creating
                ? null
                : () => setState(() => _launchTerminal = !_launchTerminal),
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: Checkbox(
                    value: _launchTerminal,
                    onChanged: _creating
                        ? null
                        : (v) => setState(() => _launchTerminal = v ?? false),
                    activeColor: AppColors.accent,
                    side: const BorderSide(color: AppColors.textMuted),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.terminal_rounded,
                  size: 16,
                  color: AppColors.terminal,
                ),
                const SizedBox(width: 6),
                const Text(
                  'Launch Ghostty terminal',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_launchTerminal) ...[
          const SizedBox(height: 12),
          _sectionLabel('COPILOT PROMPT (OPTIONAL)'),
          const SizedBox(height: 8),
          TextField(
            controller: _promptController,
            enabled: !_creating,
            maxLines: 3,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontFamily: 'monospace',
            ),
            decoration: _inputDecoration(
              hint: 'Enter prompt for copilot...',
              hasError: false,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '{issue} will be replaced with the JIRA issue number',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textMuted.withValues(alpha: 0.6),
            ),
          ),
        ],
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
        letterSpacing: 1.2,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required bool hasError,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: AppColors.textMuted.withValues(alpha: 0.4),
        fontFamily: 'monospace',
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: hasError ? AppColors.error : AppColors.border,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: hasError ? AppColors.error : AppColors.accent,
        ),
      ),
      filled: true,
      fillColor: AppColors.surface0,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}
