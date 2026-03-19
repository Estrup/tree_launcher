import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/markdown_editor/presentation/controllers/markdown_editor_controller.dart';
import 'package:tree_launcher/features/markdown_editor/presentation/widgets/editor_landing_page.dart';
import 'package:tree_launcher/features/markdown_editor/presentation/widgets/editor_toolbar.dart';
import 'package:tree_launcher/features/markdown_editor/presentation/widgets/markdown_text_field.dart';

/// Composite markdown editor view used as a standalone tab or within a split panel.
class MarkdownEditorView extends StatefulWidget {
  const MarkdownEditorView({super.key});

  @override
  State<MarkdownEditorView> createState() => _MarkdownEditorViewState();
}

class _MarkdownEditorViewState extends State<MarkdownEditorView> {
  late final FocusNode _editorFocusNode;

  @override
  void initState() {
    super.initState();
    _editorFocusNode = FocusNode(debugLabel: 'markdown-editor');
  }

  @override
  void dispose() {
    _editorFocusNode.dispose();
    super.dispose();
  }

  void _showNewFileDialog(MarkdownEditorController controller) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.borderSubtle),
        ),
        child: SizedBox(
          width: 360,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'New Document',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Unsaved until you choose to save',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: textController,
                  autofocus: true,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'filename.md',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted.withValues(alpha: 0.5),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.borderSubtle),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.borderSubtle),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.accent),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty) {
                      controller.createNewDocument(value.trim());
                      Navigator.pop(ctx);
                    }
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        final value = textController.text.trim();
                        if (value.isNotEmpty) {
                          controller.createNewDocument(value);
                          Navigator.pop(ctx);
                        }
                      },
                      child: Text(
                        'Create',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MarkdownEditorController>();
    final doc = controller.activeDocument;
    final hasCopilot = controller.hasCopilotSession;
    final openDocs = controller.openDocuments;

    return Column(
      children: [
        EditorToolbar(
          fileName: doc?.fileName,
          isModified: doc?.isModified ?? false,
          hasCopilotSession: hasCopilot,
          openDocuments: openDocs,
          activeDocumentIndex: controller.activeDocumentIndex,
          onOpen: () => controller.openFile(),
          onSave: () => controller.saveDocument(),
          onClose: () => controller.closeDocument(),
          onNewFile: hasCopilot
              ? () => _showNewFileDialog(controller)
              : null,
          onOpenPlan: hasCopilot
              ? () => controller.openPlanMd()
              : null,
          onSendToCopilot: hasCopilot && doc != null && !doc.isUntitled
              ? () => controller.sendContentToCopilot()
              : null,
          onInsertPath: hasCopilot && doc != null && !doc.isUntitled
              ? () => controller.insertFilePathInCopilot()
              : null,
          onSwitchDocument: (index) => controller.switchToDocument(index),
          onCloseDocument: (index) => controller.closeDocument(index),
        ),
        Expanded(
          child: doc != null
              ? MarkdownTextField(
                  key: ValueKey('${doc.path}_${doc.isUntitled}'),
                  initialContent: doc.content,
                  onChanged: controller.updateContent,
                  focusNode: _editorFocusNode,
                )
              : EditorLandingPage(
                  recentFiles: controller.recentFiles,
                  onOpenFile: () => controller.openFile(),
                  onOpenRecentFile: (path) => controller.openFile(path),
                  onRemoveRecentFile: controller.removeRecentFile,
                ),
        ),
      ],
    );
  }
}
