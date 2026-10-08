import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_form_fields.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_naming.dart';
import 'package:tree_launcher/providers/repo_provider.dart';
import 'package:tree_launcher/providers/settings_provider.dart';
import 'branch_search_dropdown.dart';

class AddWorktreeResult {
  final String worktreePath;
  final String? branch;

  const AddWorktreeResult({required this.worktreePath, this.branch});
}

class AddWorktreeDialog extends StatefulWidget {
  final String? initialName;
  final String? initialJiraKey;

  const AddWorktreeDialog({super.key, this.initialName, this.initialJiraKey});

  static Future<AddWorktreeResult?> show(
    BuildContext context, {
    String? initialName,
    String? initialJiraKey,
  }) {
    return showDialog<AddWorktreeResult>(
      context: context,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<RepoProvider>(),
        child: AddWorktreeDialog(
          initialName: initialName,
          initialJiraKey: initialJiraKey,
        ),
      ),
    );
  }

  @override
  State<AddWorktreeDialog> createState() => _AddWorktreeDialogState();
}

class _AddWorktreeDialogState extends State<AddWorktreeDialog> {
  final _nameController = TextEditingController();
  final _jiraController = TextEditingController();
  final _newBranchController = TextEditingController();
  String? _selectedBranch;
  String? _error;
  bool _creating = false;
  List<String> _branches = [];
  bool _loadingBranches = true;
  bool _branchManuallyEdited = false;
  bool _createNewBranch = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialJiraKey != null) {
      _jiraController.text = widget.initialJiraKey!;
    }
    if (widget.initialName != null) {
      _nameController.text = widget.initialName!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateAutoFillBranch();
      });
    }
    _loadBranches();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _jiraController.dispose();
    _newBranchController.dispose();
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
    if (_branchManuallyEdited || !_createNewBranch) return;
    final prefix = context
        .read<SettingsProvider>()
        .settings
        .defaultBranchPrefix;
    final name = _effectiveWorktreeName;
    if (name.isEmpty) {
      _newBranchController.text = '';
    } else {
      _newBranchController.text = buildBranchName(name, prefix);
    }
  }

  String get _effectiveWorktreeName {
    return _nameController.text.trim();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final nameError = validateWorktreeName(name);
    if (nameError != null) {
      setState(() => _error = nameError);
      return;
    }

    final jira = _jiraController.text.trim();
    if (jira.isNotEmpty) {
      final jiraError = validateJiraKey(jira);
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
        jiraIssue: jira.isNotEmpty ? jira : null,
      );

      // Save last used base branch for this repo
      if (_selectedBranch != null && repoProvider.selectedRepo != null) {
        await repoProvider.updateLastBaseBranch(
          repoProvider.selectedRepo!,
          _selectedBranch!,
        );
      }

      if (mounted) {
        Navigator.pop(
          context,
          worktreePath != null
              ? AddWorktreeResult(
                  worktreePath: worktreePath,
                  branch: newBranch.isNotEmpty ? newBranch : null,
                )
              : null,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _creating = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final nameError = validateWorktreeName(_nameController.text);
    final jiraError = validateJiraKey(_jiraController.text);
    final hasError = _error != null || nameError != null;
    final displayError = _error ?? nameError;

    return AlertDialog(
      backgroundColor: AppColors.surface1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border),
      ),
      title: Text(
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
                style: appFormFieldTextStyle(context, monospace: true),
                inputFormatters: [
                  _SpaceToDashFormatter(),
                  FilteringTextInputFormatter.deny(
                    RegExp(r'[A-Z]'),
                    replacementString: '',
                  ),
                ],
                decoration: _inputDecoration(
                  context: context,
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
                  style: TextStyle(fontSize: 11, color: AppColors.error),
                ),
              ],

              const SizedBox(height: 16),

              // JIRA Issue No.
              _sectionLabel('JIRA ISSUE NO. (OPTIONAL)'),
              const SizedBox(height: 8),
              TextField(
                controller: _jiraController,
                enabled: !_creating,
                style: appFormFieldTextStyle(context, monospace: true),
                textCapitalization: TextCapitalization.characters,
                decoration: _inputDecoration(
                  context: context,
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
                  style: TextStyle(fontSize: 11, color: AppColors.error),
                ),
              ],

              const SizedBox(height: 16),

              // Base Branch
              _sectionLabel('BASE BRANCH'),
              const SizedBox(height: 8),
              if (_loadingBranches)
                Padding(
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

              // Create New Branch toggle
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: _creating
                      ? null
                      : () {
                          setState(() {
                            _createNewBranch = !_createNewBranch;
                            if (!_createNewBranch) {
                              _newBranchController.clear();
                              _branchManuallyEdited = false;
                            } else {
                              _updateAutoFillBranch();
                            }
                          });
                        },
                  child: Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: Checkbox(
                          value: _createNewBranch,
                          onChanged: _creating
                              ? null
                              : (v) {
                                  setState(() {
                                    _createNewBranch = v ?? true;
                                    if (!_createNewBranch) {
                                      _newBranchController.clear();
                                      _branchManuallyEdited = false;
                                    } else {
                                      _updateAutoFillBranch();
                                    }
                                  });
                                },
                          activeColor: AppColors.accent,
                          side: BorderSide(color: AppColors.textMuted),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.merge_type_rounded,
                        size: 16,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Create new branch',
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

              // New Branch
              if (_createNewBranch) ...[
                const SizedBox(height: 12),
                _sectionLabel('NEW BRANCH'),
                const SizedBox(height: 8),
                TextField(
                  controller: _newBranchController,
                  enabled: !_creating,
                  style: appFormFieldTextStyle(context, monospace: true),
                  decoration: _inputDecoration(
                    context: context,
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
              ],

              const SizedBox(height: 16),
              Text(
                context.watch<RepoProvider>().selectedRepo?.useNestedWorktrees ==
                        true
                    ? 'Created in the repository\'s .worktrees/ subfolder.'
                    : 'Created in the same folder as the repository.',
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
          child: Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
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
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.base,
                    ),
                  )
                : Text(
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

  InputDecoration _inputDecoration({
    required BuildContext context,
    required String hint,
    required bool hasError,
  }) {
    final decoration = InputDecoration(
      hintText: hint,
      hintStyle: appFormFieldHintStyle(context, monospace: true),
    );
    if (!hasError) return decoration;

    OutlineInputBorder? withErrorBorder(InputBorder? border) {
      if (border is! OutlineInputBorder) return null;
      return border.copyWith(borderSide: BorderSide(color: AppColors.error));
    }

    final theme = Theme.of(context).inputDecorationTheme;
    return decoration.copyWith(
      border: withErrorBorder(theme.border),
      enabledBorder: withErrorBorder(theme.enabledBorder ?? theme.border),
      focusedBorder: withErrorBorder(theme.focusedBorder ?? theme.border),
      errorBorder: withErrorBorder(theme.errorBorder ?? theme.border),
      focusedErrorBorder: withErrorBorder(
        theme.focusedErrorBorder ?? theme.focusedBorder ?? theme.border,
      ),
    );
  }
}

class _SpaceToDashFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final newText = newValue.text.replaceAll(' ', '-');
    if (newText == newValue.text) return newValue;
    return newValue.copyWith(text: newText, selection: newValue.selection);
  }
}
