import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tree_launcher/core/design_system/app_form_fields.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/agents/domain/agent_kind.dart';
import 'package:tree_launcher/features/agents/presentation/agent_launcher.dart';
import 'package:tree_launcher/features/agents/presentation/widgets/agent_kind_style.dart';
import 'package:tree_launcher/features/jira/presentation/controllers/jira_titles_controller.dart';
import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';
import 'package:tree_launcher/features/terminal/domain/claude_cli_command.dart';
import 'package:tree_launcher/features/workspace/domain/claude_prompt.dart';
import 'package:tree_launcher/features/workspace/domain/repo_config.dart';
import 'package:tree_launcher/features/workspace/domain/worktree.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_naming.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/add_worktree_dialog.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/worktree_actions.dart';

class _StartAgentResult {
  const _StartAgentResult({
    required this.prompt,
    required this.worktree,
    required this.resolvedPrompt,
    this.issueKey,
    this.prNumber,
    required this.model,
    required this.effort,
  });

  final ClaudePrompt prompt;
  final Worktree worktree;
  final String? resolvedPrompt;
  final String? issueKey;
  final int? prNumber;
  final String model;
  final String effort;
}

/// Starts an agent of one kind from its tab: pick the subtype (a saved
/// prompt of that kind), where it runs, the issue (and PR) it works on, and
/// the model and effort.
///
/// A build agent runs in the issue's worktree (picked, or created from
/// here). The other kinds run in a shared worktree, which is remembered for
/// the repo's next agent.
class StartAgentDialog extends StatefulWidget {
  const StartAgentDialog({
    super.key,
    required this.kind,
    required this.repo,
    required this.prompts,
    required this.initialPrompt,
  });

  final AgentKind kind;
  final RepoConfig repo;
  final List<ClaudePrompt> prompts;
  final ClaudePrompt initialPrompt;

  /// Shows the dialog for [kind] in the selected repo, starting with
  /// [prompt] picked, and launches the agent.
  static Future<void> show(
    BuildContext context, {
    required AgentKind kind,
    required ClaudePrompt prompt,
  }) async {
    final workspace = context.read<WorkspaceController>();
    final repo = workspace.selectedRepo;
    if (repo == null) return;
    final prompts = [
      for (final p in repo.claudePrompts)
        if (p.kind == kind) p,
    ];
    final launcher = AgentLauncher.of(context);
    final settings = context.read<SettingsController>();
    final titles = Provider.of<JiraTitlesController?>(context, listen: false);

    final result = await showDialog<_StartAgentResult>(
      context: context,
      builder: (_) => StartAgentDialog(
        kind: kind,
        repo: repo,
        prompts: prompts,
        initialPrompt: prompt,
      ),
    );
    if (result == null) return;

    await settings.updateClaudeModelAndEffort(result.model, result.effort);
    if (kind != AgentKind.build) {
      await workspace.updateAgentWorkingDirectory(repo, result.worktree.path);
    }
    await launcher.start(
      repoPath: repo.path,
      repoName: repo.name,
      prompt: result.prompt,
      worktreePath: result.worktree.path,
      resolvedPrompt: result.resolvedPrompt,
      branch: result.worktree.branch,
      issueKey: result.issueKey,
      title: result.issueKey == null
          ? null
          : titles?.titleFor(result.issueKey!),
      prNumber: result.prNumber,
      model: result.model,
      effort: result.effort,
    );
  }

  @override
  State<StartAgentDialog> createState() => _StartAgentDialogState();
}

class _StartAgentDialogState extends State<StartAgentDialog> {
  late ClaudePrompt _prompt = widget.initialPrompt;
  String? _worktreePath;
  final _issueController = TextEditingController();
  final _prController = TextEditingController();
  String _model = defaultClaudeModel;
  String _effort = defaultClaudeEffort;
  String? _error;

  /// Whether the user typed in the issue / PR fields, so picking another
  /// worktree doesn't overwrite them.
  bool _issueEdited = false;
  bool _prEdited = false;

  bool get _isBuild => widget.kind == AgentKind.build;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsController>().settings;
    if (claudeModelAliases.contains(settings.claudeModel)) {
      _model = settings.claudeModel!;
    }
    if (claudeEffortLevels.contains(settings.claudeEffort)) {
      _effort = settings.claudeEffort!;
    }
    final initial = _isBuild ? null : _defaultSharedWorktree();
    if (initial != null) _selectWorktree(initial);
  }

  @override
  void dispose() {
    _issueController.dispose();
    _prController.dispose();
    super.dispose();
  }

  List<Worktree> get _worktrees =>
      context.read<WorkspaceController>().worktrees;

  Worktree? get _worktree =>
      _worktrees.where((w) => w.path == _worktreePath).firstOrNull;

  /// Where a verify, review or docs agent runs by default: the last one's
  /// directory, else the worktree on the main line.
  Worktree? _defaultSharedWorktree() {
    final worktrees = _worktrees;
    final remembered = widget.repo.agentWorkingDirectory;
    return worktrees.where((w) => w.path == remembered).firstOrNull ??
        worktrees
            .where(
              (w) => const ['develop', 'main', 'master'].contains(w.branch),
            )
            .firstOrNull ??
        worktrees.where((w) => w.isMain).firstOrNull ??
        worktrees.firstOrNull;
  }

  void _selectWorktree(Worktree worktree) {
    _worktreePath = worktree.path;
    if (_isBuild && !_issueEdited) {
      _issueController.text = worktree.jiraIssue ?? '';
    }
    if (!_prEdited) {
      final pr = openPrNumberForBranch(context, worktree.branch);
      _prController.text = pr == null ? '' : '$pr';
    }
  }

  Future<void> _createWorktree() async {
    final result = await AddWorktreeDialog.show(context);
    if (result == null || !mounted) return;
    setState(() {
      _worktreePath = result.worktreePath;
      final created = _worktree;
      if (created != null) _selectWorktree(created);
    });
  }

  bool get _usesPr => _prompt.prompt.contains('{pr}');

  String? get _issueKey {
    final text = _issueController.text.trim().toUpperCase();
    return text.isEmpty ? null : text;
  }

  int? get _prNumber => int.tryParse(_prController.text.trim());

  String? _resolved(Worktree? worktree) => resolveClaudePrompt(
    _prompt,
    issue: _issueKey,
    baseBranch: worktree?.baseBranch ?? worktree?.branch,
    worktreeName: worktree?.name ?? '',
    worktreePath: worktree?.path ?? '',
    repoName: widget.repo.name,
    prNumber: _prNumber,
  );

  void _submit() {
    final worktree = _worktree;
    if (worktree == null) {
      setState(() => _error = 'Pick where the agent runs');
      return;
    }
    final issue = _issueKey;
    if (issue == null && _prompt.prompt.contains('{issue}')) {
      setState(() => _error = '${_prompt.name} needs a Jira issue');
      return;
    }
    if (issue != null) {
      final error = validateJiraKey(issue);
      if (error != null) {
        setState(() => _error = 'Issue: $error');
        return;
      }
    }
    if (_usesPr && _prController.text.trim().isNotEmpty && _prNumber == null) {
      setState(() => _error = 'PR must be a number');
      return;
    }
    Navigator.pop(
      context,
      _StartAgentResult(
        prompt: _prompt,
        worktree: worktree,
        resolvedPrompt: _resolved(worktree),
        issueKey: issue,
        prNumber: _usesPr ? _prNumber : null,
        model: _model,
        effort: _effort,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final worktrees = context.watch<WorkspaceController>().worktrees;
    final kind = widget.kind;
    final color = kind.color;
    final worktree = _worktree;
    final preview = _resolved(worktree);

    return Dialog(
      backgroundColor: AppColors.surface1,
      insetPadding: const EdgeInsets.all(32),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                border: Border(
                  bottom: BorderSide(color: AppColors.borderSubtle),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(kind.icon, size: 18, color: color),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'New ${kind.label.toLowerCase()} agent',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        widget.repo.name,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('TYPE'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final prompt in widget.prompts)
                          _Chip(
                            label: prompt.name,
                            color: color,
                            selected: prompt.name == _prompt.name,
                            onTap: () => setState(() => _prompt = prompt),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _label(_isBuild ? 'WORKTREE' : 'RUNS IN'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            // Rebuilt when a new worktree is picked from
                            // outside the dropdown.
                            key: ValueKey(_worktreePath),
                            initialValue:
                                worktrees.any((w) => w.path == _worktreePath)
                                ? _worktreePath
                                : null,
                            isExpanded: true,
                            dropdownColor: AppColors.surface1,
                            style: appFormFieldTextStyle(context),
                            hint: Text(
                              _isBuild
                                  ? "Pick the issue's worktree"
                                  : 'Pick a worktree',
                              style: appFormFieldHintStyle(context),
                            ),
                            items: [
                              for (final w in worktrees)
                                DropdownMenuItem(
                                  value: w.path,
                                  child: Text(
                                    [
                                      w.name,
                                      if (w.jiraIssue != null &&
                                          !w.name.toUpperCase().contains(
                                            w.jiraIssue!,
                                          ))
                                        w.jiraIssue!,
                                      '(${w.branch})',
                                    ].join('  '),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (path) {
                              final picked = worktrees
                                  .where((w) => w.path == path)
                                  .firstOrNull;
                              if (picked != null) {
                                setState(() => _selectWorktree(picked));
                              }
                            },
                          ),
                        ),
                        if (_isBuild) ...[
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: _createWorktree,
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('New worktree'),
                          ),
                        ],
                      ],
                    ),
                    if (!_isBuild)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'A shared checkout; remembered for the next agent.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('JIRA ISSUE'),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _issueController,
                                style: appFormFieldTextStyle(context),
                                decoration: const InputDecoration(
                                  hintText: 'AU2-1234',
                                ),
                                onChanged: (_) => setState(() {
                                  _issueEdited = true;
                                  _error = null;
                                }),
                              ),
                            ],
                          ),
                        ),
                        if (_usesPr) ...[
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 140,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('PR'),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _prController,
                                  style: appFormFieldTextStyle(context),
                                  decoration: const InputDecoration(
                                    hintText: '7123',
                                  ),
                                  onChanged: (_) => setState(() {
                                    _prEdited = true;
                                    _error = null;
                                  }),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 18),
                    _label('MODEL'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final model in claudeModelAliases)
                          _Chip(
                            label: _capitalized(model),
                            color: AppColors.claude,
                            selected: model == _model,
                            onTap: () => setState(() => _model = model),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _label('EFFORT'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final effort in claudeEffortLevels)
                          _Chip(
                            label: effort == 'xhigh'
                                ? 'XHigh'
                                : _capitalized(effort),
                            color: AppColors.claude,
                            selected: effort == _effort,
                            onTap: () => setState(() => _effort = effort),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _label('FIRST MESSAGE'),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surface0,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Text(
                        preview ?? '(empty)',
                        maxLines: 6,
                        overflow: TextOverflow.ellipsis,
                        style: appFormFieldTextStyle(
                          context,
                          monospace: true,
                          height: 1.4,
                        ).copyWith(fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Runs in the built-in terminal with '
                      '$agentIdEnvironmentVariable set, so the agent can '
                      'report to this tab.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted.withValues(alpha: 0.7),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        style: TextStyle(fontSize: 12, color: AppColors.error),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: color),
                    onPressed: worktree == null ? null : _submit,
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Start agent'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _capitalized(String v) =>
      '${v[0].toUpperCase()}${v.substring(1)}';

  Widget _label(String text) => Text(
    text,
    style: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: AppColors.textMuted,
      letterSpacing: 1.0,
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.16)
                : AppColors.surface0,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.5)
                  : AppColors.borderSubtle,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? color : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
