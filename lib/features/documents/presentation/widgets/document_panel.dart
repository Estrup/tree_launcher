import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import 'package:tree_launcher/core/design_system/app_snackbar.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/core/errors/user_message.dart';
import 'package:tree_launcher/core/platform/open_external.dart';
import 'package:tree_launcher/core/widgets/issue_list.dart';
import 'package:tree_launcher/features/agents/presentation/widgets/agent_kind_style.dart';
import 'package:tree_launcher/features/documents/domain/session_document.dart';
import 'package:tree_launcher/features/documents/presentation/controllers/documents_controller.dart';
import 'package:tree_launcher/features/documents/presentation/widgets/document_view.dart';
import 'package:tree_launcher/features/jira/presentation/widgets/jira_issue_dialog.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/repo_pages.dart';

/// A saved document with its header (title, issues, where it came from,
/// actions) above the viewer. Follows the document as it is replaced, and
/// shows that it is gone once deleted.
class DocumentPanel extends StatefulWidget {
  const DocumentPanel({
    super.key,
    required this.documentId,
    this.inDialog = false,
  });

  final String documentId;

  /// In the viewer dialog: offers to open the Documents page, and closes
  /// the dialog when the document is deleted.
  final bool inDialog;

  @override
  State<DocumentPanel> createState() => _DocumentPanelState();
}

class _DocumentPanelState extends State<DocumentPanel> {
  int _reloads = 0;
  String? _renderedPath;

  @override
  void initState() {
    super.initState();
    _resolveRenderedPath();
  }

  @override
  void didUpdateWidget(DocumentPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.documentId != widget.documentId) _resolveRenderedPath();
  }

  Future<void> _resolveRenderedPath() async {
    final path = await context.read<DocumentsController>().renderedPathFor(
      widget.documentId,
    );
    if (mounted) setState(() => _renderedPath = path);
  }

  @override
  Widget build(BuildContext context) {
    final document = context.watch<DocumentsController>().documentById(
      widget.documentId,
    );
    if (document == null) {
      return Center(
        child: Text(
          'This document was deleted.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      );
    }
    final renderedPath = _renderedPath;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyR, meta: true): _reload,
      },
      child: Focus(
        // In the dialog, so ⌘R works at once; on the page it would take the
        // focus from the search field whenever the selection follows it.
        autofocus: widget.inDialog,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              document: document,
              inDialog: widget.inDialog,
              onReload: _reload,
            ),
            Divider(height: 1, color: AppColors.borderSubtle),
            Expanded(
              child: renderedPath == null
                  ? const SizedBox.shrink()
                  : DocumentView(
                      filePath: document.filePath,
                      format: document.format,
                      title: document.title,
                      renderedPath: renderedPath,
                      version: (document.updatedAt, _reloads),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _reload() => setState(() => _reloads++);
}

class _Header extends StatelessWidget {
  const _Header({
    required this.document,
    required this.inDialog,
    required this.onReload,
  });

  final SessionDocument document;
  final bool inDialog;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final kind = document.agentKind;
    final type = kind == null ? null : agentTypeOf(context, kind);
    final from = document.worktreePath == null
        ? null
        : p.basename(document.worktreePath!);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    DocumentFormatTag(format: document.format),
                    const SizedBox(width: 8),
                    Flexible(
                      child: SelectableText(
                        document.title,
                        maxLines: 2,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final key in document.issueKeys)
                      _LinkText(
                        text: key,
                        color: AppColors.accent,
                        onTap: () =>
                            JiraIssueDialog.show(context, issueKey: key),
                      ),
                    if (type != null)
                      _LinkText(
                        icon: type.iconData,
                        text: 'From ${type.label}',
                        color: type.colorValue,
                        onTap: () => _showAgentPage(context),
                      ),
                    if (from != null) _MutedText(from),
                    if (document.prNumber != null)
                      _MutedText('PR #${document.prNumber}'),
                    _MutedText(formatRelativeTime(document.updatedAt)),
                  ],
                ),
              ],
            ),
          ),
          _icon(Icons.refresh_rounded, 'Reload (⌘R)', onReload),
          _icon(
            Icons.open_in_new_rounded,
            document.format == DocumentFormat.pdf
                ? 'Open in Preview'
                : 'Open in default app',
            () => openExternal(document.filePath),
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            icon: Icon(
              Icons.more_horiz_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
            onSelected: (action) => _act(context, action),
            itemBuilder: (_) => [
              if (inDialog)
                const PopupMenuItem(
                  value: 'page',
                  child: Text('Open in Documents page'),
                ),
              const PopupMenuItem(
                value: 'reveal',
                child: Text('Reveal in Finder'),
              ),
              const PopupMenuItem(value: 'copy', child: Text('Copy path')),
              const PopupMenuItem(value: 'delete', child: Text('Delete…')),
            ],
          ),
          if (inDialog)
            _icon(
              Icons.close_rounded,
              'Close (Esc)',
              () => Navigator.of(context).maybePop(),
            ),
        ],
      ),
    );
  }

  Widget _icon(IconData icon, String tooltip, VoidCallback onPressed) =>
      IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 18, color: AppColors.textSecondary),
      );

  Future<void> _act(BuildContext context, String action) async {
    switch (action) {
      case 'page':
        await showDocumentsPage(context, document);
        if (context.mounted) Navigator.of(context).maybePop();
      case 'reveal':
        revealInFinder(document.filePath);
      case 'copy':
        await Clipboard.setData(ClipboardData(text: document.filePath));
        showAppSnackBar('Copied ${document.filePath}');
      case 'delete':
        await confirmDeleteDocument(context, document);
    }
  }

  Future<void> _showAgentPage(BuildContext context) async {
    final kind = document.agentKind;
    if (kind == null) return;
    await _showRepoPage(context, document.repoName, agentPageKey(kind));
    if (inDialog && context.mounted) Navigator.of(context).maybePop();
  }
}

/// Selects the document's repo and shows its Documents page with
/// [document] selected.
Future<void> showDocumentsPage(
  BuildContext context,
  SessionDocument document,
) async {
  context.read<DocumentsController>().select(document.repoName, document.id);
  await _showRepoPage(context, document.repoName, documentsPageKey);
}

Future<void> _showRepoPage(
  BuildContext context,
  String repoName,
  String pageKey,
) async {
  final workspace = context.read<WorkspaceController>();
  final repo = workspace.repos.where((r) => r.name == repoName).firstOrNull;
  if (repo == null) return;
  await workspace.selectRepo(repo);
  workspace.showRepoPage(pageKey);
}

/// Asks, then deletes [document] and its file.
Future<void> confirmDeleteDocument(
  BuildContext context,
  SessionDocument document,
) async {
  final documents = context.read<DocumentsController>();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete document?'),
      content: Text('This removes "${document.title}" and its file.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    await documents.delete(document.id);
  } catch (e) {
    showAppSnackBar('Failed to delete: ${userMessage(e)}');
  }
}

/// The small MD / HTML / PDF tag.
class DocumentFormatTag extends StatelessWidget {
  const DocumentFormatTag({super.key, required this.format});

  final DocumentFormat format;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      color: AppColors.surface2,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      format.label,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
        color: AppColors.textSecondary,
      ),
    ),
  );
}

/// The icon for a document of [format].
IconData documentIcon(DocumentFormat format) => format == DocumentFormat.pdf
    ? Icons.picture_as_pdf_outlined
    : Icons.article_outlined;

class _LinkText extends StatelessWidget {
  const _LinkText({
    required this.text,
    required this.color,
    required this.onTap,
    this.icon,
  });

  final String text;
  final Color color;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    child: GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    ),
  );
}

class _MutedText extends StatelessWidget {
  const _MutedText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: TextStyle(fontSize: 12, color: AppColors.textMuted));
}
