import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/core/utils/markdown_checkbox.dart';
import 'package:tree_launcher/features/copilot/domain/copilot_session.dart';
import 'package:tree_launcher/features/kanban/domain/comment.dart';
import 'package:tree_launcher/features/kanban/domain/issue.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/add_worktree_dialog.dart';
import 'package:tree_launcher/providers/copilot_provider.dart';
import 'package:tree_launcher/providers/kanban_provider.dart';
import 'package:tree_launcher/providers/repo_provider.dart';

class IssueViewDialog extends StatefulWidget {
  final Issue issue;

  const IssueViewDialog({super.key, required this.issue});

  @override
  State<IssueViewDialog> createState() => _IssueViewDialogState();
}

class _IssueViewDialogState extends State<IssueViewDialog> {
  bool _isEditingDescription = false;
  late TextEditingController _titleController;
  late TextEditingController _descController;
  final TextEditingController _commentController = TextEditingController();
  late String _currentDescription;
  late String _currentTitle;
  late Issue _issue;
  bool _isEditingTitle = false;

  @override
  void initState() {
    super.initState();
    _issue = widget.issue;
    _currentTitle = _issue.title;
    _currentDescription = _issue.description ?? '';
    _titleController = TextEditingController(text: _currentTitle);
    _descController = TextEditingController(text: _currentDescription);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _saveTitle() {
    final newTitle = _titleController.text.trim();
    if (newTitle.isNotEmpty && newTitle != _currentTitle) {
      setState(() {
        _currentTitle = newTitle;
        _isEditingTitle = false;
      });
      final updated = _issue.copyWith(
        title: newTitle,
        updatedAt: DateTime.now(),
      );
      _issue = updated;
      context.read<KanbanProvider>().updateIssue(updated);
    } else {
      setState(() {
        _titleController.text = _currentTitle;
        _isEditingTitle = false;
      });
    }
  }

  void _toggleEditDescription() {
    if (_isEditingDescription) {
      // Save
      final newDesc = _descController.text.trim();
      setState(() {
        _currentDescription = newDesc;
        _isEditingDescription = false;
      });
      final updated = _issue.copyWith(
        description: newDesc.isNotEmpty ? newDesc : null,
        updatedAt: DateTime.now(),
      );
      _issue = updated;
      context.read<KanbanProvider>().updateIssue(updated);
    } else {
      setState(() {
        _isEditingDescription = true;
      });
    }
  }

  void _archiveIssue() {
    context.read<KanbanProvider>().archiveIssue(_issue.id, _issue.projectId);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 1100,
        height: 750,
        child: Column(
          children: [
            // Header
            Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: AppColors.surface0,
                border: Border(
                  bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface1,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Text(
                      _issue.displayId,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTitleArea()),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: Icon(
                      Icons.archive_outlined,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    onPressed: _archiveIssue,
                    tooltip: 'Archive',
                    splashRadius: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                    splashRadius: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            // Body Area
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- LEFT COLUMN ---
                  Expanded(
                    flex: 6,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface0,
                        border: Border(
                          right: BorderSide(
                            color: AppColors.borderSubtle,
                            width: 1,
                          ),
                        ),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildPropertiesRow(),
                            const SizedBox(height: 32),
                            _buildDescriptionArea(),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // --- RIGHT COLUMN ---
                  Expanded(
                    flex: 4,
                    child: Container(
                      color: AppColors.surface0,
                      child: Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildDevelopmentSection(),
                                  const SizedBox(height: 32),
                                  _buildCommentsList(),
                                ],
                              ),
                            ),
                          ),
                          _buildCommentInput(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Left Column Content
  // ---------------------------------------------------------------------------

  Widget _buildTitleArea() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: _isEditingTitle
              ? TextField(
                  controller: _titleController,
                  autofocus: true,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onSubmitted: (_) => _saveTitle(),
                  onTapOutside: (_) => _saveTitle(),
                )
              : GestureDetector(
                  onTap: () {
                    setState(() {
                      _isEditingTitle = true;
                    });
                  },
                  child: Text(
                    _currentTitle,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildPropertiesRow() {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [_buildStatusBadge(), _buildLabelsBadge()],
    );
  }

  Widget _buildStatusBadge() {
    final statusLabel = _issue.status.name == 'todo'
        ? 'To do'
        : _issue.status.name == 'inProgress'
        ? 'In progress'
        : _issue.status.name == 'inReview'
        ? 'In review'
        : 'Done';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle_outlined, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Text(
            statusLabel,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabelsBadge() {
    if (_issue.tags.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _issue.tags
          .map(
            (tag) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surface1,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    tag,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildDescriptionArea() {
    final String markdownDescription = _currentDescription.isNotEmpty
        ? _currentDescription
        : '*No description provided.*';

    return Padding(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.notes, size: 20, color: AppColors.textPrimary),
                  const SizedBox(width: 8),
                  Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: _toggleEditDescription,
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.surface1,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: Text(
                  _isEditingDescription ? 'Save' : 'Edit',
                  style: TextStyle(
                    fontSize: 12,
                    color: _isEditingDescription
                        ? AppColors.success
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isEditingDescription)
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface0,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.accent),
              ),
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _descController,
                maxLines: null,
                minLines: 8,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Add a more detailed description...',
                  hintStyle: TextStyle(color: AppColors.textMuted),
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            )
          else
            MarkdownBody(
              data: markdownDescription,
              selectable: true,
              checkboxBuilder: (bool value) => CustomCheckbox(isChecked: value),
              builders: {'checkmark': CheckmarkBuilder()},
              extensionSet: md.ExtensionSet(
                md.ExtensionSet.gitHubFlavored.blockSyntaxes,
                <md.InlineSyntax>[
                  md.EmojiSyntax(),
                  CheckmarkSyntax(),
                  ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
                ],
              ),
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  height: 1.5,
                ),
                h1: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                h2: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                h3: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                listBullet: TextStyle(color: AppColors.textPrimary),
                blockquote: TextStyle(
                  color: AppColors.textPrimary,
                  fontStyle: FontStyle.italic,
                ),
                blockquoteDecoration: BoxDecoration(
                  color: AppColors.surface1,
                  border: Border(
                    left: BorderSide(color: AppColors.accent, width: 4),
                  ),
                ),
                blockquotePadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                code: TextStyle(
                  backgroundColor: AppColors.surface2,
                  color: AppColors.textPrimary,
                  fontFamily: 'monospace',
                ),
                codeblockDecoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Right Column Content
  // ---------------------------------------------------------------------------

  Widget _buildSectionHeader(IconData icon, String title, {Widget? trailing}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          Flexible(
            child: Align(alignment: Alignment.centerRight, child: trailing),
          ),
        ],
      ],
    );
  }

  String _generateWorktreeName() {
    final title = _issue.title
        .toLowerCase()
        .replaceAll(' ', '-')
        .replaceAll(RegExp(r'[^a-z0-9\-]'), '');
    final truncated = title.length > 15 ? title.substring(0, 15) : title;
    // Remove trailing dash
    final cleaned = truncated.endsWith('-')
        ? truncated.substring(0, truncated.length - 1)
        : truncated;
    return '$cleaned-${_issue.displayId.toLowerCase()}';
  }

  Future<void> _createWorktree() async {
    final generatedName = _generateWorktreeName();
    final result = await AddWorktreeDialog.show(
      context,
      initialName: generatedName,
    );
    if (result == null || !mounted) return;

    final kanbanProvider = context.read<KanbanProvider>();
    final copilotProvider = context.read<CopilotProvider>();

    String? sessionId = result.copilotSessionId;

    // If no copilot session was created by the dialog, create one
    if (sessionId == null) {
      final repoProvider = context.read<RepoProvider>();
      final repo = repoProvider.selectedRepo;
      if (repo != null) {
        final session = await copilotProvider.createSession(
          repo.path,
          result.worktreePath,
          generatedName,
        );
        sessionId = session.id;
      }
    }

    if (sessionId != null) {
      kanbanProvider.linkCopilotSession(
        _issue.id,
        sessionId,
        worktreePath: result.worktreePath,
        branch: result.branch,
      );
    }
  }

  Widget _buildDevelopmentSection() {
    final kanbanProvider = context.watch<KanbanProvider>();
    final copilotProvider = context.watch<CopilotProvider>();
    final links = kanbanProvider.getLinkedSessions(_issue.id);

    final repoProvider = context.read<RepoProvider>();
    final repo = repoProvider.selectedRepo;
    final allSessions = repo?.copilotSessions ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          Icons.code,
          'Development',
          trailing: TextButton.icon(
            onPressed: _createWorktree,
            icon: const Icon(Icons.add, size: 14),
            label: const Text('Create Worktree'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accent,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
        const SizedBox(height: 12),
        links.isEmpty
            ? Text(
                'No worktrees linked',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              )
            : Column(
                children: links.map((link) {
                  CopilotSession? session;
                  try {
                    session = allSessions.firstWhere(
                      (s) => s.id == link.copilotSessionId,
                    );
                  } catch (_) {
                    session = null;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap: () {
                        if (session != null) {
                          copilotProvider.selectSession(session);
                          Navigator.of(context).pop();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.surface1,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.account_tree_outlined,
                              size: 14,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    session?.name ??
                                        'Session ${link.copilotSessionId.substring(0, 8)}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textPrimary,
                                      height: 1.2,
                                    ),
                                  ),
                                  if (link.worktreePath != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      link.worktreePath!,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                        fontFamily: 'monospace',
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  if (link.branch != null) ...[
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.merge_type_rounded,
                                          size: 12,
                                          color: AppColors.textMuted,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            link.branch!,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textMuted,
                                              fontFamily: 'monospace',
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatTime(link.createdAt),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.link_off,
                                size: 14,
                                color: AppColors.textMuted,
                              ),
                              onPressed: () {
                                kanbanProvider.unlinkCopilotSession(
                                  _issue.id,
                                  link.copilotSessionId,
                                );
                              },
                              tooltip: 'Unlink',
                              iconSize: 14,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
      ],
    );
  }

  Widget _buildCommentsList() {
    final provider = context.watch<KanbanProvider>();
    final comments = provider.getComments(_issue.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(Icons.chat_bubble_outline, 'Comments and activity'),
        const SizedBox(height: 16),
        if (comments.isEmpty)
          Text(
            'No comments yet.',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          )
        else
          ...comments.map((c) => _buildCommentItem(c)),
      ],
    );
  }

  Widget _buildCommentItem(Comment comment) {
    final isAgent = comment.authorType == CommentAuthorType.agent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isAgent) ...[
                Icon(
                  Icons.smart_toy_outlined,
                  size: 14,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                comment.authorName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isAgent ? AppColors.accent : AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatTime(comment.createdAt),
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              const Spacer(),
              if (comment.authorType == CommentAuthorType.user)
                IconButton(
                  icon: Icon(Icons.close, size: 14, color: AppColors.textMuted),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppColors.surface0,
                        title: Text(
                          'Delete Comment',
                          style: TextStyle(color: AppColors.textPrimary),
                        ),
                        content: Text(
                          'Are you sure you want to delete this comment?',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () {
                              context.read<KanbanProvider>().deleteComment(
                                comment.id,
                              );
                              Navigator.of(ctx).pop();
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.error,
                            ),
                            child: const Text(
                              'Delete',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Delete',
                ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface1,
              border: Border.all(
                color: isAgent
                    ? AppColors.accent.withValues(alpha: 0.3)
                    : AppColors.borderSubtle,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: MarkdownBody(
              data: comment.content,
              selectable: true,
              checkboxBuilder: (bool value) => CustomCheckbox(isChecked: value),
              builders: {'checkmark': CheckmarkBuilder()},
              extensionSet: md.ExtensionSet(
                md.ExtensionSet.gitHubFlavored.blockSyntaxes,
                <md.InlineSyntax>[
                  md.EmojiSyntax(),
                  CheckmarkSyntax(),
                  ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
                ],
              ),
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  height: 1.4,
                ),
                blockquote: TextStyle(
                  color: AppColors.textPrimary,
                  fontStyle: FontStyle.italic,
                ),
                blockquoteDecoration: BoxDecoration(
                  color: AppColors.surface0,
                  border: Border(
                    left: BorderSide(color: AppColors.accent, width: 4),
                  ),
                ),
                blockquotePadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                code: TextStyle(
                  backgroundColor: AppColors.surface2,
                  color: AppColors.textPrimary,
                  fontFamily: 'monospace',
                ),
                codeblockDecoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surface0,
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface1,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _commentController,
                  maxLines: 4,
                  minLines: 3,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Add a comment...',
                    hintStyle: TextStyle(color: AppColors.textMuted),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(7),
                      bottomRight: Radius.circular(7),
                    ),
                    border: Border(
                      top: BorderSide(color: AppColors.borderSubtle),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Markdown is supported',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      FilledButton(
                        onPressed: _submitComment,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.surface0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text(
                          'Comment',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _submitComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    context.read<KanbanProvider>().addComment(
      issueId: _issue.id,
      content: text,
      authorType: CommentAuthorType.user,
      authorName: 'User',
    );
    _commentController.clear();
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}
