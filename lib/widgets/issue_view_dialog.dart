import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../models/issue.dart';
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
  bool _isEditing = false;
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late String _currentDescription;
  late String _currentTitle;
  late Issue _issue;

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
    super.dispose();
  }

  void _toggleEdit() {
    if (_isEditing) {
      // Save
      final newTitle = _titleController.text.trim();
      final newDesc = _descController.text.trim();
      if (newTitle.isNotEmpty) {
        setState(() {
          _currentTitle = newTitle;
          _currentDescription = newDesc;
          _isEditing = false;
        });
        final updated = _issue.copyWith(
          title: newTitle,
          description: newDesc.isNotEmpty ? newDesc : null,
          updatedAt: DateTime.now(),
        );
        _issue = updated;
        context.read<KanbanProvider>().updateIssue(updated);
      }
    } else {
      setState(() {
        _isEditing = true;
      });
    }
  }

  void _archiveIssue() {
    context.read<KanbanProvider>().archiveIssue(_issue.id, _issue.projectId);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final String markdownDescription = _currentDescription.isNotEmpty
        ? '# $_currentTitle\n\n$_currentDescription'
        : '# $_currentTitle\n\n*No description provided.*';

    return Dialog(
      backgroundColor: AppColors.surface0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: 1000,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _issue.id.substring(0, 8),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _isEditing
                      ? TextField(
                          controller: _titleController,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        )
                      : Text(
                          _currentTitle,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                ),
                const SizedBox(width: 16),
                TextButton.icon(
                  onPressed: _toggleEdit,
                  icon: Icon(_isEditing ? Icons.check : Icons.edit, size: 16),
                  label: Text(_isEditing ? 'Save' : 'Edit'),
                  style: TextButton.styleFrom(
                    foregroundColor: _isEditing
                        ? AppColors.success
                        : AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 4),
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
            const SizedBox(height: 24),
            // Body
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left side (Markdown content / Editor)
                  Expanded(
                    flex: 5,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _isEditing
                            ? AppColors.surface0
                            : AppColors.surface1,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _isEditing
                              ? AppColors.accent
                              : AppColors.borderSubtle,
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: _isEditing
                          ? TextField(
                              controller: _descController,
                              maxLines: null,
                              expands: true,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                height: 1.5,
                              ),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Add a description...',
                                hintStyle: TextStyle(
                                  color: AppColors.textMuted,
                                ),
                              ),
                            )
                          : Markdown(
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
                                listBullet: TextStyle(
                                  color: AppColors.textPrimary,
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
                  ),
                  const SizedBox(width: 24),
                  // Right side (Sidebar: Properties, Actions, Sessions)
                  SizedBox(
                    width: 300,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildPropertiesSection(),
                          const SizedBox(height: 24),
                          _buildWorktreeSection(),
                          const SizedBox(height: 24),
                          _buildCopilotSessionsSection(),
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

  Widget _buildSidebarSection({
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            trailing ?? const SizedBox.shrink(),
          ],
        ),
        const SizedBox(height: 12),
        child,
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

    return _buildSidebarSection(
      title: 'Properties',
      trailing: Icon(
        Icons.settings_outlined,
        size: 16,
        color: AppColors.textMuted,
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          children: [
            _buildPropertyRow('Status', statusLabel, Icons.circle_outlined),
            Divider(height: 16, color: AppColors.borderSubtle),
            _buildLabelsRow(),
          ],
        ),
      ),
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
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(12),
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
    return _buildSidebarSection(
      title: 'Development',
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          children: [
            _buildDevRow(
              'Worktree',
              _issue.worktreePath ?? 'None',
              onAdd: _setWorktree,
            ),
            Divider(height: 1, color: AppColors.borderSubtle),
            _buildDevRow('Branch', _issue.branch ?? 'None', onAdd: _setBranch),
          ],
        ),
      ),
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
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
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
      ),
    );
  }

  Widget _buildCopilotSessionsSection() {
    final kanbanProvider = context.watch<KanbanProvider>();
    final copilotProvider = context.watch<CopilotProvider>();
    final links = kanbanProvider.getLinkedSessions(_issue.id);

    // Resolve copilot session objects from links
    final repoProvider = context.read<RepoProvider>();
    final repo = repoProvider.selectedRepo;
    final allSessions = repo?.copilotSessions ?? [];

    return _buildSidebarSection(
      title: 'Copilot Sessions',
      trailing: TextButton.icon(
        onPressed: () {
          if (repo == null) return;
          final worktreePath = _issue.worktreePath ?? repo.path;
          final worktreeName = _issue.branch ?? _issue.title;
          copilotProvider.createSession(repo.path, worktreePath, worktreeName);
          // Link the latest session
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
      child: links.isEmpty
          ? Text(
              'No sessions linked',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            )
          : Column(
              children: links.map((link) {
                // Try to find the matching copilot session
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
                        color: AppColors.surface0,
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
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}
