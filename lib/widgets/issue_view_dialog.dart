import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../theme/app_theme.dart';
import 'kanban_board.dart';

class IssueViewDialog extends StatefulWidget {
  final KanbanCardData data;

  const IssueViewDialog({super.key, required this.data});

  @override
  State<IssueViewDialog> createState() => _IssueViewDialogState();
}

class _IssueViewDialogState extends State<IssueViewDialog> {
  bool _isEditing = false;
  late TextEditingController _descController;
  late String _currentDescription;

  @override
  void initState() {
    super.initState();
    _currentDescription = widget.data.description ?? '';
    _descController = TextEditingController(text: _currentDescription);
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  void _toggleEdit() {
    if (_isEditing) {
      setState(() {
        _currentDescription = _descController.text;
        _isEditing = false;
      });
    } else {
      setState(() {
        _isEditing = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Add some markdown formatting for nice prototype view if it's just raw text
    final String markdownDescription = _currentDescription.isNotEmpty
        ? '# ${widget.data.title}\n\n$_currentDescription'
        : '# ${widget.data.title}\n\n*No description provided.*';

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
                    widget.data.id,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    widget.data.title,
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
                const SizedBox(width: 8),
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
            _buildPropertyRow('Status', 'Todo', Icons.circle_outlined),
            Divider(height: 16, color: AppColors.borderSubtle),
            _buildPropertyRow('Assignee', 'Unassigned', Icons.person_outline),
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
              if (widget.data.tags.isEmpty)
                Text(
                  'None',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
              ...widget.data.tags.map(
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
                          color: Colors.amber, // Prototype color
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
              InkWell(
                onTap: () {},
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.borderSubtle,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Icon(Icons.add, size: 14, color: AppColors.textMuted),
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
            _buildDevRow('Worktree', 'None', onAdd: () {}),
            Divider(height: 1, color: AppColors.borderSubtle),
            _buildDevRow('Branch', 'None', onAdd: () {}),
          ],
        ),
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
              '+ Create',
              style: TextStyle(fontSize: 12, color: AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCopilotSessionsSection() {
    return _buildSidebarSection(
      title: 'Copilot Sessions',
      trailing: TextButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.add, size: 14),
        label: const Text('New'),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      child: Column(
        children: [
          _buildSessionItem(
            title: 'Debug stall at 99%',
            time: '2 hours ago',
            active: true,
          ),
          const SizedBox(height: 8),
          _buildSessionItem(
            title: 'Refactor image loader',
            time: 'Yesterday',
            active: false,
          ),
          const SizedBox(height: 8),
          _buildSessionItem(
            title: 'Fix dark mode borders',
            time: '2 days ago',
            active: false,
          ),
        ],
      ),
    );
  }

  Widget _buildSessionItem({
    required String title,
    required String time,
    required bool active,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: active ? AppColors.surface2 : AppColors.surface0,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: active ? AppColors.accent : AppColors.borderSubtle,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 14,
            color: active ? AppColors.accent : AppColors.textMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: active ? AppColors.textPrimary : AppColors.textMuted,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
