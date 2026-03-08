import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_form_fields.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/providers/kanban_provider.dart';

class CreateIssueDialog extends StatefulWidget {
  final String projectId;

  const CreateIssueDialog({super.key, required this.projectId});

  static Future<void> show(BuildContext context, String projectId) {
    return showDialog(
      context: context,
      builder: (context) => CreateIssueDialog(projectId: projectId),
    );
  }

  @override
  State<CreateIssueDialog> createState() => _CreateIssueDialogState();
}

class _CreateIssueDialogState extends State<CreateIssueDialog> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _create() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final description = _descController.text.trim();
    context.read<KanbanProvider>().createIssue(
      widget.projectId,
      title,
      description: description.isNotEmpty ? description : null,
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'New Issue',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              focusNode: _focusNode,
              style: appFormFieldTextStyle(context),
              decoration: const InputDecoration(hintText: 'Issue title'),
              onSubmitted: (_) => _create(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              maxLines: 4,
              style: appFormFieldTextStyle(context),
              decoration: const InputDecoration(
                hintText: 'Description (optional)',
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                  ),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _create,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Create'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
