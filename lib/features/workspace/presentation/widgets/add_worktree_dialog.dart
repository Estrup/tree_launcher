import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_form_fields.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/terminal/domain/claude_cli_command.dart';
import 'package:tree_launcher/features/terminal/presentation/claude_session_actions.dart';
import 'package:tree_launcher/features/workspace/domain/worktree.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_naming.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/worktree_actions.dart';
import 'package:tree_launcher/providers/repo_provider.dart';
import 'package:tree_launcher/providers/settings_provider.dart';
import 'branch_search_dropdown.dart';

class AddWorktreeResult {
  final String worktreePath;
  final String? branch;

  /// In start-Claude mode, the picked prompt with its placeholders filled in,
  /// or null for no first message.
  final String? claudePrompt;

  /// In start-Claude mode, the picked `--model` alias and `--effort` level;
  /// null otherwise.
  final String? claudeModel;
  final String? claudeEffort;

  const AddWorktreeResult({
    required this.worktreePath,
    this.branch,
    this.claudePrompt,
    this.claudeModel,
    this.claudeEffort,
  });
}

class AddWorktreeDialog extends StatefulWidget {
  final String? initialName;
  final String? initialJiraKey;

  /// Base branch to preselect instead of the repo's last used one (e.g. a
  /// PR's head branch). Not remembered as the last used base branch.
  final String? initialBaseBranch;

  /// Whether "Create new branch" starts checked. Off checks out
  /// [initialBaseBranch] itself.
  final bool initialCreateNewBranch;

  /// PR author recorded on the created worktree.
  final String? prAuthor;

  /// Number of the PR the dialog was opened from, filled into `{pr}` in saved
  /// prompts. Without it, `{pr}` is the open PR from the worktree's branch.
  final int? prNumber;

  /// In start-Claude mode, replaces the issue-context first message (e.g.
  /// with a PR's context), shown as [contextPromptLabel] in the picker.
  final String? contextPrompt;
  final String? contextPromptLabel;

  /// Title of the issue or PR the dialog was opened from, shown in the header.
  final String? contextTitle;

  /// Start-Claude mode: adds a Claude prompt picker and returns the resolved
  /// prompt in [AddWorktreeResult.claudePrompt]. The caller starts the session.
  final bool startClaude;

  /// In start-Claude mode, start in this worktree instead of creating one; the
  /// worktree fields are replaced by a summary of it.
  final Worktree? existingWorktree;

  const AddWorktreeDialog({
    super.key,
    this.initialName,
    this.initialJiraKey,
    this.initialBaseBranch,
    this.initialCreateNewBranch = true,
    this.prAuthor,
    this.prNumber,
    this.startClaude = false,
    this.existingWorktree,
    this.contextPrompt,
    this.contextPromptLabel,
    this.contextTitle,
  });

  static Future<AddWorktreeResult?> show(
    BuildContext context, {
    String? initialName,
    String? initialJiraKey,
    String? initialBaseBranch,
    bool initialCreateNewBranch = true,
    String? prAuthor,
    int? prNumber,
    bool startClaude = false,
    Worktree? existingWorktree,
    String? contextPrompt,
    String? contextPromptLabel,
    String? contextTitle,
  }) {
    return showDialog<AddWorktreeResult>(
      context: context,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<RepoProvider>(),
        child: AddWorktreeDialog(
          initialName: initialName,
          initialJiraKey: initialJiraKey,
          initialBaseBranch: initialBaseBranch,
          initialCreateNewBranch: initialCreateNewBranch,
          prAuthor: prAuthor,
          prNumber: prNumber,
          startClaude: startClaude,
          existingWorktree: existingWorktree,
          contextPrompt: contextPrompt,
          contextPromptLabel: contextPromptLabel,
          contextTitle: contextTitle,
        ),
      ),
    );
  }

  /// The Claude-session flow behind the Jira and PR buttons: shows the session
  /// already running in [existingWorktree], or asks for the worktree (reusing
  /// [existingWorktree] when given) and a prompt, then starts Claude there.
  static Future<void> startClaudeSession(
    BuildContext context, {
    Worktree? existingWorktree,
    String? initialName,
    String? initialJiraKey,
    String? initialBaseBranch,
    bool initialCreateNewBranch = true,
    String? prAuthor,
    int? prNumber,
    String? contextPrompt,
    String? contextPromptLabel,
    String? contextTitle,
  }) async {
    final repo = context.read<RepoProvider>().selectedRepo;
    if (repo == null) return;
    final launcher = ClaudeSessionLauncher.of(context);
    final settings = context.read<SettingsProvider>();
    if (existingWorktree != null && launcher.focus(existingWorktree.path)) {
      return;
    }
    final result = await show(
      context,
      initialName: initialName,
      initialJiraKey: initialJiraKey,
      initialBaseBranch: initialBaseBranch,
      initialCreateNewBranch: initialCreateNewBranch,
      prAuthor: prAuthor,
      prNumber: prNumber,
      startClaude: true,
      existingWorktree: existingWorktree,
      contextPrompt: contextPrompt,
      contextPromptLabel: contextPromptLabel,
      contextTitle: contextTitle,
    );
    if (result == null) return;
    await settings.updateClaudeModelAndEffort(
      result.claudeModel,
      result.claudeEffort,
    );
    await launcher.start(
      repoPath: repo.path,
      worktreePath: result.worktreePath,
      prompt: result.claudePrompt,
      model: result.claudeModel,
      effort: result.claudeEffort,
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
  late bool _createNewBranch = widget.initialCreateNewBranch;

  /// Selected entry of the Claude prompt picker (see [_promptOptions]).
  late String _promptKey = widget.existingWorktree?.kickoffPromptPath != null
      ? _kickoffPromptKey
      : _contextPromptKey;

  /// Picked `--model` alias and `--effort` level. Start from the last pick
  /// (see [SettingsController.updateClaudeModelAndEffort]).
  String _model = defaultClaudeModel;
  String _effort = defaultClaudeEffort;

  static const _contextPromptKey = 'context';
  static const _kickoffPromptKey = 'kickoff';
  static const _noPromptKey = 'none';
  static const _savedPromptPrefix = 'saved:';

  Worktree? get _existing =>
      widget.startClaude ? widget.existingWorktree : null;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>().settings;
    final model = settings.claudeModel;
    if (model != null && claudeModelAliases.contains(model)) _model = model;
    final effort = settings.claudeEffort;
    if (effort != null && claudeEffortLevels.contains(effort)) {
      _effort = effort;
    }
    if (widget.initialJiraKey != null) {
      _jiraController.text = widget.initialJiraKey!;
    }
    if (_existing != null) {
      _loadingBranches = false;
      return;
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
        final initial = widget.initialBaseBranch;
        setState(() {
          // Offer the requested branch even if it isn't fetched yet; git
          // reports it if it doesn't exist.
          _branches = initial == null || branches.contains(initial)
              ? branches
              : [initial, ...branches];
          _loadingBranches = false;
          if (initial != null) {
            _selectedBranch = initial;
          } else if (branches.isNotEmpty) {
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

  /// The Claude prompt toggles. None selected means no first message.
  List<_PromptOption> _promptOptions() {
    final prompts =
        context.read<RepoProvider>().selectedRepo?.claudePrompts ?? const [];
    final existing = _existing;
    final jira = _jiraController.text.trim();
    final contextPrompt =
        widget.contextPrompt ??
        claudeContextPromptFor(
          issue: existing?.jiraIssue ?? (jira.isNotEmpty ? jira : null),
          base: existing?.baseBranch ?? _selectedBranch,
        );
    return [
      _PromptOption(
        key: _contextPromptKey,
        label: widget.contextPromptLabel ?? 'Issue context',
        icon: Icons.description_outlined,
        preview: _firstLine(contextPrompt),
      ),
      if (existing?.kickoffPromptPath != null)
        const _PromptOption(
          key: _kickoffPromptKey,
          label: 'Kickoff prompt',
          icon: Icons.rocket_launch_outlined,
          preview: 'Staged when the worktree was created',
        ),
      for (var i = 0; i < prompts.length; i++)
        _PromptOption(
          key: '$_savedPromptPrefix$i',
          label: prompts[i].name,
          icon: Icons.bookmark_border_rounded,
          preview: _firstLine(prompts[i].prompt),
        ),
    ];
  }

  static String? _firstLine(String? text) => text
      ?.split('\n')
      .map((l) => l.trim())
      .firstWhere((l) => l.isNotEmpty, orElse: () => '');

  /// Fills the picked prompt in for the worktree at [worktreePath].
  String? _resolvePrompt({
    required String worktreePath,
    String? issue,
    String? baseBranch,
  }) {
    final repo = context.read<RepoProvider>().selectedRepo;
    switch (_promptKey) {
      case _contextPromptKey:
        return widget.contextPrompt ??
            claudeContextPromptFor(issue: issue, base: baseBranch);
      case _kickoffPromptKey:
        final existing = _existing;
        return existing == null ? null : kickoffPromptLaunchPrompt(existing);
      case _noPromptKey:
        return null;
    }
    final index = int.tryParse(_promptKey.substring(_savedPromptPrefix.length));
    final prompts = repo?.claudePrompts ?? const [];
    if (index == null || index >= prompts.length) return null;
    // A new branch has no PR yet; an existing one may.
    final branch =
        _existing?.branch ?? (_createNewBranch ? null : _selectedBranch);
    return resolveClaudePrompt(
      prompts[index],
      issue: issue,
      baseBranch: baseBranch,
      worktreeName: p.basename(worktreePath),
      worktreePath: worktreePath,
      repoName: repo?.name,
      prNumber: widget.prNumber ?? openPrNumberForBranch(context, branch),
    );
  }

  Future<void> _submit() async {
    final existing = _existing;
    if (existing != null) {
      Navigator.pop(
        context,
        AddWorktreeResult(
          worktreePath: existing.path,
          branch: existing.branch,
          claudePrompt: _resolvePrompt(
            worktreePath: existing.path,
            issue: existing.jiraIssue ?? widget.initialJiraKey,
            baseBranch: existing.baseBranch,
          ),
          claudeModel: _model,
          claudeEffort: _effort,
        ),
      );
      return;
    }

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
        prAuthor: widget.prAuthor,
      );

      // Save last used base branch for this repo, unless it was preset (a
      // PR's branch shouldn't become the default for new worktrees).
      if (_selectedBranch != null &&
          widget.initialBaseBranch == null &&
          repoProvider.selectedRepo != null) {
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
                  claudePrompt: widget.startClaude
                      ? _resolvePrompt(
                          worktreePath: worktreePath,
                          issue: jira.isNotEmpty ? jira : null,
                          baseBranch: _selectedBranch,
                        )
                      : null,
                  claudeModel: widget.startClaude ? _model : null,
                  claudeEffort: widget.startClaude ? _effort : null,
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
    final existing = _existing;
    return Dialog(
      backgroundColor: AppColors.surface1,
      insetPadding: const EdgeInsets.all(32),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.startClaude ? 820 : 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: widget.startClaude
                    // Split: worktree fields left, prompt toggles right.
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: existing != null
                                ? _existingWorktreeFields(existing)
                                : _worktreeFields(context),
                          ),
                          const SizedBox(width: 24),
                          SizedBox(width: 300, child: _promptPanel()),
                        ],
                      )
                    : _worktreeFields(context),
              ),
            ),
            _footer(),
          ],
        ),
      ),
    );
  }

  /// Tinted header: icon badge, title, and what the dialog was opened from.
  Widget _header() {
    final color = widget.startClaude ? AppColors.claude : AppColors.accent;
    final jiraKey = widget.initialJiraKey;
    final contextTitle = widget.contextTitle;
    final repoName = context.read<RepoProvider>().selectedRepo?.name;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.12), color.withValues(alpha: 0)],
        ),
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 16),
              ],
            ),
            child: Icon(
              widget.startClaude
                  ? Icons.auto_awesome_rounded
                  : Icons.account_tree_rounded,
              size: 20,
              color: color,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.startClaude ? 'Start Claude Session' : 'New Worktree',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (jiraKey != null && jiraKey.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          jiraKey,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: color,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        contextTitle ??
                            (repoName != null ? 'in $repoName' : ''),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Footer: where the worktree goes, plus Cancel and the primary action.
  Widget _footer() {
    final nested =
        context.watch<RepoProvider>().selectedRepo?.useNestedWorktrees == true;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 20, 12),
      decoration: BoxDecoration(
        color: AppColors.surface0.withValues(alpha: 0.5),
        border: Border(top: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _existing != null
                ? const SizedBox.shrink()
                : Text(
                    nested
                        ? 'Created in the repository\'s .worktrees/ subfolder.'
                        : 'Created in the same folder as the repository.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted.withValues(alpha: 0.6),
                    ),
                  ),
          ),
          TextButton(
            onPressed: _creating ? null : () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          const SizedBox(width: 8),
          _primaryButton(widget.startClaude ? 'Start' : 'Create'),
        ],
      ),
    );
  }

  /// The worktree name / Jira / branch fields for a new worktree.
  Widget _worktreeFields(BuildContext context) {
    final nameError = validateWorktreeName(_nameController.text);
    final jiraError = validateJiraKey(_jiraController.text);
    final hasError = _error != null || nameError != null;
    final displayError = _error ?? nameError;

    return Column(
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
                : () => _setCreateNewBranch(!_createNewBranch),
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: Checkbox(
                    value: _createNewBranch,
                    onChanged: _creating
                        ? null
                        : (v) => _setCreateNewBranch(v ?? true),
                    activeColor: AppColors.accent,
                    side: BorderSide(color: AppColors.textMuted),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
      ],
    );
  }

  void _setCreateNewBranch(bool value) {
    setState(() {
      _createNewBranch = value;
      if (!_createNewBranch) {
        _newBranchController.clear();
        _branchManuallyEdited = false;
      } else {
        _updateAutoFillBranch();
      }
    });
  }

  /// Start-Claude mode for an issue that already has a worktree: the left
  /// side only summarises it.
  Widget _existingWorktreeFields(Worktree existing) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('WORKTREE'),
        const SizedBox(height: 8),
        _existingWorktreeSummary(existing),
      ],
    );
  }

  Widget _primaryButton(String label) {
    final color = widget.startClaude ? AppColors.claude : AppColors.accent;
    return MouseRegion(
      cursor: _creating ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _creating ? null : _submit,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
          decoration: BoxDecoration(
            color: _creating ? color.withValues(alpha: 0.5) : color,
            borderRadius: BorderRadius.circular(8),
            boxShadow: _creating
                ? null
                : [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
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
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.startClaude
                          ? Icons.play_arrow_rounded
                          : Icons.add_rounded,
                      size: 15,
                      color: AppColors.base,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.base,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  /// Right-hand panel of prompt toggles (at most one active) plus a note on
  /// the command that will run.
  Widget _promptPanel() {
    final args = context.watch<SettingsProvider>().settings.claudeCliArgs;
    final options = _promptOptions();
    final active = options.any((o) => o.key == _promptKey) ? _promptKey : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface0,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('CLAUDE PROMPT'),
          const SizedBox(height: 10),
          for (final option in options) ...[
            _PromptToggle(
              option: option,
              selected: option.key == active,
              enabled: !_creating,
              onTap: () => setState(
                () => _promptKey = option.key == active
                    ? _noPromptKey
                    : option.key,
              ),
            ),
            const SizedBox(height: 6),
          ],
          if (active == null)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 4),
              child: Text(
                'No prompt — Claude starts without a first message.',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ),
          const SizedBox(height: 14),
          _sectionLabel('MODEL'),
          const SizedBox(height: 8),
          _choiceChips(
            values: claudeModelAliases,
            selected: _model,
            onSelected: (v) => setState(() => _model = v),
          ),
          const SizedBox(height: 14),
          _sectionLabel('EFFORT'),
          const SizedBox(height: 8),
          _choiceChips(
            values: claudeEffortLevels,
            selected: _effort,
            onSelected: (v) => setState(() => _effort = v),
          ),
          const SizedBox(height: 14),
          Text(
            'Runs ${buildClaudeCliCommand(extraArgs: args, model: _model, effort: _effort)} '
            'in the built-in terminal.',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textMuted.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  /// A row of single-select chips for [values].
  Widget _choiceChips({
    required List<String> values,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    String label(String v) =>
        v == 'xhigh' ? 'XHigh' : '${v[0].toUpperCase()}${v.substring(1)}';
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final value in values)
          _ChoiceChip(
            label: label(value),
            selected: value == selected,
            enabled: !_creating,
            onTap: () => onSelected(value),
          ),
      ],
    );
  }

  Widget _existingWorktreeSummary(Worktree wt) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface0,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Icon(Icons.account_tree_rounded, size: 15, color: AppColors.success),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wt.name,
                  overflow: TextOverflow.ellipsis,
                  style: appFormFieldTextStyle(context, monospace: true),
                ),
                const SizedBox(height: 2),
                Text(
                  wt.branch,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
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

/// One entry of the Claude prompt toggles.
class _PromptOption {
  final String key;
  final String label;
  final IconData icon;

  /// First line of the prompt text, shown under the label.
  final String? preview;

  const _PromptOption({
    required this.key,
    required this.label,
    required this.icon,
    this.preview,
  });
}

/// A toggle button for one Claude prompt. Selected tiles are tinted in the
/// Claude color with a check mark.
class _PromptToggle extends StatefulWidget {
  final _PromptOption option;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _PromptToggle({
    required this.option,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  State<_PromptToggle> createState() => _PromptToggleState();
}

class _PromptToggleState extends State<_PromptToggle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final color = AppColors.claude;
    final preview = widget.option.preview;

    return MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.12)
                : _hovered
                ? AppColors.surface2
                : AppColors.surface1,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.55)
                  : AppColors.borderSubtle,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.15),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                widget.option.icon,
                size: 16,
                color: selected ? color : AppColors.textMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.option.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                    if (preview != null && preview.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 140),
                child: Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  key: ValueKey(selected),
                  size: 16,
                  color: selected
                      ? color
                      : AppColors.textMuted.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small single-select chip in the Claude panel's model / effort rows.
class _ChoiceChip extends StatefulWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  State<_ChoiceChip> createState() => _ChoiceChipState();
}

class _ChoiceChipState extends State<_ChoiceChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final color = AppColors.claude;
    return MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.14)
                : _hovered
                ? AppColors.surface2
                : AppColors.surface1,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.55)
                  : AppColors.borderSubtle,
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? color : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
