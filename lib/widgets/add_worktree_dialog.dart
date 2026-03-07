import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/command_style.dart';
import '../models/copilot_prompt.dart';
import '../models/custom_command.dart';
import '../providers/copilot_provider.dart';
import '../providers/repo_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/terminal_provider.dart';
import '../theme/app_theme.dart';
import 'branch_search_dropdown.dart';

class AddWorktreeResult {
  final String worktreePath;
  final String? branch;
  final String? copilotSessionId;

  const AddWorktreeResult({
    required this.worktreePath,
    this.branch,
    this.copilotSessionId,
  });
}

class AddWorktreeDialog extends StatefulWidget {
  final String? initialName;

  const AddWorktreeDialog({super.key, this.initialName});

  static Future<AddWorktreeResult?> show(
    BuildContext context, {
    String? initialName,
  }) {
    return showDialog<AddWorktreeResult>(
      context: context,
      builder: (_) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: context.read<RepoProvider>()),
          ChangeNotifierProvider.value(value: context.read<TerminalProvider>()),
          ChangeNotifierProvider.value(value: context.read<CopilotProvider>()),
        ],
        child: AddWorktreeDialog(initialName: initialName),
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
  bool _launchCopilot = false;
  CopilotPrompt? _selectedPrompt;
  bool _runCommands = false;
  Set<String> _selectedCommands = {};
  String? _error;
  bool _creating = false;
  List<String> _branches = [];
  bool _loadingBranches = true;
  bool _branchManuallyEdited = false;
  bool _createNewBranch = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialName != null) {
      _nameController.text = widget.initialName!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateAutoFillBranch();
      });
    }
    _loadBranches();
    _initRunCommandDefaults();
  }

  void _initRunCommandDefaults() {
    final repo = context.read<RepoProvider>().selectedRepo;
    if (repo == null) return;
    final commandNames = repo.customCommands.map((c) => c.name).toSet();
    final validDefaults = repo.defaultRunCommands
        .where((name) => commandNames.contains(name))
        .toSet();
    if (validDefaults.isNotEmpty) {
      _runCommands = true;
      _selectedCommands = validDefaults;
    }
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
    } else if (prefix != null && prefix.isNotEmpty) {
      _newBranchController.text = '$prefix/$name';
    } else {
      _newBranchController.text = name;
    }
  }

  String? _validateName(String value) {
    if (value.isEmpty) return null;
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
      final terminalProvider = context.read<TerminalProvider>();
      final copilotProvider = context.read<CopilotProvider>();
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

      String? copilotSessionId;
      if (_launchCopilot && worktreePath != null) {
        final repo = repoProvider.selectedRepo;
        String? prompt;
        if (_selectedPrompt != null) {
          prompt = _selectedPrompt!.prompt;
          if (jira.isNotEmpty) {
            prompt = prompt.replaceAll('{issue}', jira);
          } else {
            prompt = prompt.replaceAll('{issue}', '');
          }
          prompt = prompt.replaceAll(RegExp(r'\s+'), ' ').trim();
          if (prompt.isEmpty) prompt = null;
        }
        final session = await copilotProvider.createSession(
          repo?.path ?? worktreePath,
          worktreePath,
          worktreeName,
          prompt: prompt,
        );
        copilotSessionId = session.id;
      }

      // Launch selected run commands in the new worktree
      if (_runCommands &&
          _selectedCommands.isNotEmpty &&
          worktreePath != null) {
        final repo = repoProvider.selectedRepo!;

        // Persist selected commands as defaults
        await repoProvider.updateDefaultRunCommands(
          repo,
          _selectedCommands.toList(),
        );

        // Shut down existing command sessions for this repo
        await terminalProvider.gracefulCloseCommandSessionsForRepo(repo.path);

        // Launch each selected command
        for (final cmd in repo.customCommands) {
          if (_selectedCommands.contains(cmd.name)) {
            terminalProvider.openTerminalWithCommand(
              cmd.name,
              worktreePath,
              repo.path,
              cmd.command,
            );
          }
        }
      }

      if (mounted) {
        Navigator.pop(
          context,
          worktreePath != null
              ? AddWorktreeResult(
                  worktreePath: worktreePath,
                  branch: newBranch.isNotEmpty ? newBranch : null,
                  copilotSessionId: copilotSessionId,
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
    final nameError = _validateName(_nameController.text);
    final jiraError = _validateJira(_jiraController.text);
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
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontFamily: 'monospace',
                ),
                inputFormatters: [
                  _SpaceToDashFormatter(),
                  FilteringTextInputFormatter.deny(
                    RegExp(r'[A-Z]'),
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
                style: TextStyle(
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
                  style: TextStyle(fontSize: 11, color: AppColors.error),
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
                  style: TextStyle(
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
              ],

              const SizedBox(height: 16),

              // Launch Terminal
              _buildTerminalSection(),

              // Run Commands
              _buildRunSection(),

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

  Widget _buildTerminalSection() {
    final repo = context.read<RepoProvider>().selectedRepo;
    final prompts = repo?.copilotPrompts ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: _creating
                ? null
                : () => setState(() => _launchCopilot = !_launchCopilot),
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: Checkbox(
                    value: _launchCopilot,
                    onChanged: _creating
                        ? null
                        : (v) => setState(() => _launchCopilot = v ?? false),
                    activeColor: AppColors.accent,
                    side: BorderSide(color: AppColors.textMuted),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 16,
                  color: AppColors.copilot,
                ),
                const SizedBox(width: 6),
                Text(
                  'Launch Copilot',
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
        if (_launchCopilot && prompts.isNotEmpty) ...[
          const SizedBox(height: 12),
          _sectionLabel('COPILOT PROMPT (OPTIONAL)'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface0,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<CopilotPrompt?>(
                value: _selectedPrompt,
                isExpanded: true,
                dropdownColor: AppColors.surface1,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
                icon: Icon(
                  Icons.expand_more_rounded,
                  color: AppColors.textMuted,
                  size: 18,
                ),
                items: [
                  DropdownMenuItem<CopilotPrompt?>(
                    value: null,
                    child: Text(
                      'None',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  ...prompts.map(
                    (p) => DropdownMenuItem<CopilotPrompt?>(
                      value: p,
                      child: Text(
                        p.name,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
                onChanged: _creating
                    ? null
                    : (value) => setState(() => _selectedPrompt = value),
              ),
            ),
          ),
          if (_selectedPrompt != null) ...[
            const SizedBox(height: 6),
            Text(
              _selectedPrompt!.prompt,
              style: TextStyle(
                fontSize: 10,
                color: AppColors.textMuted.withValues(alpha: 0.6),
                fontFamily: 'monospace',
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildRunSection() {
    final repo = context.read<RepoProvider>().selectedRepo;
    if (repo == null || repo.customCommands.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: _creating
                ? null
                : () => setState(() => _runCommands = !_runCommands),
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: Checkbox(
                    value: _runCommands,
                    onChanged: _creating
                        ? null
                        : (v) => setState(() => _runCommands = v ?? false),
                    activeColor: AppColors.accent,
                    side: BorderSide(color: AppColors.textMuted),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.play_arrow_rounded,
                  size: 16,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 6),
                Text(
                  'Run',
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
        if (_runCommands) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Column(
              children: [
                for (int i = 0; i < repo.customCommands.length; i++)
                  _buildCommandCheckbox(repo.customCommands[i], i),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCommandCheckbox(CustomCommand cmd, int index) {
    final isSelected = _selectedCommands.contains(cmd.name);
    final color = getCommandColor(cmd.colorHex, index);
    final icon = getCommandIcon(cmd.iconName);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: _creating
              ? null
              : () {
                  setState(() {
                    if (isSelected) {
                      _selectedCommands.remove(cmd.name);
                    } else {
                      _selectedCommands.add(cmd.name);
                    }
                  });
                },
          child: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: Checkbox(
                  value: isSelected,
                  onChanged: _creating
                      ? null
                      : (v) {
                          setState(() {
                            if (v == true) {
                              _selectedCommands.add(cmd.name);
                            } else {
                              _selectedCommands.remove(cmd.name);
                            }
                          });
                        },
                  activeColor: color,
                  side: BorderSide(color: AppColors.textMuted),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                cmd.name,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
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
