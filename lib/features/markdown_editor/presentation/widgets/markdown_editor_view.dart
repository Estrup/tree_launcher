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

    return Column(
      children: [
        EditorToolbar(
          fileName: doc?.fileName,
          isModified: doc?.isModified ?? false,
          onOpen: () => controller.openFile(),
          onSave: () => controller.saveDocument(),
          onClose: () => controller.closeDocument(),
        ),
        Expanded(
          child: doc != null
              ? MarkdownTextField(
                  key: ValueKey(doc.path),
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
