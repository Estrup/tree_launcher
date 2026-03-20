import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
              ? () => controller.createNewDocument()
              : null,
          onOpenPlan: hasCopilot
              ? () => controller.openPlanMd()
              : null,
          onSendToCopilot: hasCopilot && doc != null
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
