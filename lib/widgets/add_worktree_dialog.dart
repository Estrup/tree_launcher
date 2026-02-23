import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/repo_provider.dart';
import '../theme/app_theme.dart';

class AddWorktreeDialog extends StatefulWidget {
  const AddWorktreeDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<RepoProvider>(),
        child: const AddWorktreeDialog(),
      ),
    );
  }

  @override
  State<AddWorktreeDialog> createState() => _AddWorktreeDialogState();
}

class _AddWorktreeDialogState extends State<AddWorktreeDialog> {
  final _controller = TextEditingController();
  String? _error;
  bool _creating = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validate(String value) {
    if (value.isEmpty) return null; // Don't show error for empty
    if (value.contains(' ')) return 'No spaces allowed';
    if (value != value.toLowerCase()) return 'Must be lowercase';
    if (!RegExp(r'^[a-z0-9._\-]+$').hasMatch(value)) {
      return 'Only a-z, 0-9, ., -, _ allowed';
    }
    return null;
  }

  Future<void> _submit() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;

    final validationError = _validate(name);
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }

    setState(() {
      _creating = true;
      _error = null;
    });

    try {
      await context.read<RepoProvider>().addWorktree(name);
      if (mounted) Navigator.pop(context);
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
    final validationError = _validate(_controller.text);
    final hasError = _error != null || validationError != null;
    final displayError = _error ?? validationError;

    return AlertDialog(
      backgroundColor: AppColors.surface1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      title: const Text(
        'New Worktree',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.3,
        ),
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'WORKTREE NAME',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              autofocus: true,
              enabled: !_creating,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontFamily: 'monospace',
              ),
              inputFormatters: [
                FilteringTextInputFormatter.deny(RegExp(r'[A-Z\s]'),
                    replacementString: ''),
              ],
              decoration: InputDecoration(
                hintText: 'e.g. feature-auth',
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
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _submit(),
            ),
            if (displayError != null) ...[
              const SizedBox(height: 6),
              Text(
                displayError,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.error,
                ),
              ),
            ],
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
      actions: [
        TextButton(
          onPressed: _creating ? null : () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppColors.textMuted),
          ),
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
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.base,
                    ),
                  )
                : const Text(
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
}
