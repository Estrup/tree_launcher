import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/providers/kanban_provider.dart';

class CreateProjectDialog extends StatefulWidget {
  final String repoPath;

  const CreateProjectDialog({super.key, required this.repoPath});

  static Future<void> show(BuildContext context, String repoPath) {
    return showDialog(
      context: context,
      builder: (context) => CreateProjectDialog(repoPath: repoPath),
    );
  }

  @override
  State<CreateProjectDialog> createState() => _CreateProjectDialogState();
}

class _CreateProjectDialogState extends State<CreateProjectDialog> {
  final _nameController = TextEditingController();
  final _keyController = TextEditingController();
  final _focusNode = FocusNode();
  bool _keyManuallyEdited = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
    _nameController.addListener(_autoGenerateKey);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _keyController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Auto-generate a 3-letter key from the project name unless the user
  /// has manually edited the key field.
  void _autoGenerateKey() {
    if (_keyManuallyEdited) return;
    final name = _nameController.text.trim().toUpperCase();
    final key = name.length <= 3
        ? name.replaceAll(RegExp(r'[^A-Z]'), '')
        : name
              .split(RegExp(r'\s+'))
              .where((w) => w.isNotEmpty)
              .map((w) => w[0])
              .take(3)
              .join();
    _keyController.text = key.padRight(0).substring(0, key.length.clamp(0, 3));
  }

  void _create() {
    final name = _nameController.text.trim();
    final key = _keyController.text.trim().toUpperCase();
    if (name.isEmpty || key.isEmpty || key.length > 3) return;

    context.read<KanbanProvider>().createProject(widget.repoPath, name, key);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'New Project',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              focusNode: _focusNode,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Project name',
                hintStyle: TextStyle(color: AppColors.textMuted),
              ),
              onSubmitted: (_) => _create(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _keyController,
              maxLength: 3,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z]')),
                LengthLimitingTextInputFormatter(3),
              ],
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
              ),
              decoration: InputDecoration(
                hintText: 'KEY',
                hintStyle: TextStyle(color: AppColors.textMuted),
                labelText: 'Project key (max 3 letters)',
                labelStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              onChanged: (_) {
                _keyManuallyEdited = true;
              },
              onSubmitted: (_) => _create(),
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
