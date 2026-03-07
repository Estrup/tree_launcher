import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../models/issue.dart';
import '../models/comment.dart';
import '../models/copilot_session.dart';
import '../providers/copilot_provider.dart';
import '../providers/kanban_provider.dart';
import '../providers/repo_provider.dart';
import '../theme/app_theme.dart';

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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: 1100,
        height: 750,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Top Header Bar (ID + Actions)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface1,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _issue.displayId,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.archive_outlined,
                        color: AppColors.textMuted,
                        size: 18,
                      ),
                      onPressed: _archiveIssue,
                      tooltip: 'Archive',
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(Icons.close, color: AppColors.textMuted),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Body Area
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- LEFT COLUMN ---
                  Expanded(
                    flex: 6,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(right: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTitleArea(),
                          const SizedBox(height: 16),
                          _buildQuickActionsRow(),
                          const SizedBox(height: 32),
                          _buildDescriptionArea(),
                        ],
                      ),
                    ),
                  ),

                  // --- VERTICAL DIVIDER ---
                  Container(
                    width: 1,
                    color: AppColors.borderSubtle,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                  ),

                  // --- RIGHT COLUMN ---
                  Expanded(
                    flex: 4,
                    child: Container(
                      padding: const EdgeInsets.only(left: 24),
                      child: Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildPropertiesSection(),
                                  const SizedBox(height: 32),
                                  _buildWorktreeSection(),
                                  const SizedBox(height: 32),
                                  _buildCopilotSessionsSection(),
                                  const SizedBox(height: 32),
                                  _buildCommentsList(),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
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
        Icon(
          Icons.radio_button_unchecked,
          color: AppColors.textMuted,
          size: 24,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _isEditingTitle
              ? TextField(
                  controller: _titleController,
                  autofocus: true,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
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
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildQuickActionsRow() {
    return Padding(
      padding: const EdgeInsets.only(left: 36), // Align with title text
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _buildActionButton(Icons.add, 'Add'),
          _buildActionButton(Icons.label_outline, 'Labels'),
          _buildActionButton(Icons.access_time, 'Dates'),
          _buildActionButton(Icons.check_box_outlined, 'Checklist'),
          _buildActionButton(Icons.person_outline, 'Members'),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label) {
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
          Icon(icon, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionArea() {
    final String markdownDescription = _currentDescription.isNotEmpty
        ? _currentDescription
        : '*No description provided.*';

    return Padding(
      padding: const EdgeInsets.only(left: 36),
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
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        if (trailing != null) ...[const Spacer(), trailing],
      ],
    );
  }

  Widget _buildPropertiesSection() {
    final statusLabel = _issue.status.name == 'todo'
        ? 'To do'
        : _issue.status.name == 'inProgress'
        ? 'In progress'
        : _issue.status.name == 'inReview'
        ? 'In review'
        : 'Done';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(Icons.settings_outlined, 'Properties'),
        const SizedBox(height: 12),
        _buildPropertyRow('Status', statusLabel, Icons.circle_outlined),
        Divider(height: 24, color: AppColors.borderSubtle),
        _buildLabelsRow(),
      ],
    );
  }

  Widget _buildPropertyRow(String label, String value, IconData icon) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ),
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLabelsRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Labels',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (_issue.tags.isEmpty)
                Text(
                  'None',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
              ..._issue.tags.map(
                (tag) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
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
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWorktreeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(Icons.code, 'Development'),
        const SizedBox(height: 12),
        _buildDevRow(
          'Worktree',
          _issue.worktreePath ?? 'None',
          onAdd: _setWorktree,
        ),
        Divider(height: 16, color: AppColors.borderSubtle),
        _buildDevRow('Branch', _issue.branch ?? 'None', onAdd: _setBranch),
      ],
    );
  }

  void _setBranch() {
    final controller = TextEditingController(text: _issue.branch ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface0,
        title: Text(
          'Set Branch',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: TextField(
          controller: controller,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'feature/my-branch',
            hintStyle: TextStyle(color: AppColors.textMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              final updated = _issue.copyWith(
                branch: value.isNotEmpty ? value : null,
              );
              setState(() => _issue = updated);
              context.read<KanbanProvider>().updateIssue(updated);
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _setWorktree() {
    final controller = TextEditingController(text: _issue.worktreePath ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface0,
        title: Text(
          'Set Worktree Path',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: TextField(
          controller: controller,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: '/path/to/worktree',
            hintStyle: TextStyle(color: AppColors.textMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              final updated = _issue.copyWith(
                worktreePath: value.isNotEmpty ? value : null,
              );
              setState(() => _issue = updated);
              context.read<KanbanProvider>().updateIssue(updated);
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildDevRow(
    String label,
    String value, {
    required VoidCallback onAdd,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
          ),
        ),
        TextButton(
          onPressed: onAdd,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            '+ Set',
            style: TextStyle(fontSize: 12, color: AppColors.accent),
          ),
        ),
      ],
    );
  }

  Widget _buildCopilotSessionsSection() {
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
          Icons.smart_toy_outlined,
          'Copilot Sessions',
          trailing: TextButton.icon(
            onPressed: () {
              if (repo == null) return;
              final worktreePath = _issue.worktreePath ?? repo.path;
              final worktreeName = _issue.branch ?? _issue.title;
              copilotProvider.createSession(
                repo.path,
                worktreePath,
                worktreeName,
              );
              final updatedSessions = repo.copilotSessions;
              if (updatedSessions.isNotEmpty) {
                kanbanProvider.linkCopilotSession(
                  _issue.id,
                  updatedSessions.last.id,
                );
              }
            },
            icon: const Icon(Icons.add, size: 14),
            label: const Text('New'),
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
                'No sessions linked',
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
                              Icons.chat_bubble_outline,
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar stand-in
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isAgent
                  ? AppColors.accent.withValues(alpha: 0.2)
                  : Colors.deepOrange,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: isAgent
                ? Icon(
                    Icons.smart_toy_outlined,
                    size: 16,
                    color: AppColors.accent,
                  )
                : Text(
                    comment.authorName.isNotEmpty
                        ? comment.authorName[0].toUpperCase()
                        : 'U',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.authorName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(comment.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors
                        .surface1, // lighter than surface0? Actually surface0 is the base.
                    border: Border.all(color: AppColors.borderSubtle),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: MarkdownBody(
                    data: comment.content,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        height: 1.4,
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
                const SizedBox(height: 4),
                if (comment.authorType == CommentAuthorType.user)
                  Row(
                    children: [
                      _buildCommentAction('Edit', () {}),
                      Text(
                        ' • ',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                      _buildCommentAction('Delete', () {
                        context.read<KanbanProvider>().deleteComment(
                          comment.id,
                        );
                      }),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentAction(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: AppColors.textMuted,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface0, // Matches dialog background
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _commentController,
            maxLines: 4,
            minLines: 1,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Write a comment...',
              hintStyle: TextStyle(color: AppColors.textMuted),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            onSubmitted: (_) => _submitComment(),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton(
                onPressed: _submitComment,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.surface2,
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Save', style: TextStyle(fontSize: 12)),
              ),
            ],
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
