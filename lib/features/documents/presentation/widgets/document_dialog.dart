import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import 'package:tree_launcher/core/design_system/app_snackbar.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/core/errors/user_message.dart';
import 'package:tree_launcher/core/platform/open_external.dart';
import 'package:tree_launcher/features/documents/domain/session_document.dart';
import 'package:tree_launcher/features/documents/presentation/controllers/documents_controller.dart';
import 'package:tree_launcher/features/documents/presentation/widgets/document_panel.dart';
import 'package:tree_launcher/features/documents/presentation/widgets/document_view.dart';

/// Shows saved document [id] in a large dialog over the window, leaving the
/// user where they were.
Future<void> showDocumentDialog(BuildContext context, String id) =>
    showDialog<void>(
      context: context,
      builder: (_) => _DocumentDialogFrame(
        child: DocumentPanel(documentId: id, inDialog: true),
      ),
    );

/// Shows the local file at [path] (a document an agent linked to) in the
/// viewer dialog, read where it is, with a button that saves it to the
/// Documents as [details] describe.
Future<void> showFileDocumentDialog(
  BuildContext context,
  String path, {
  required DocumentDetails details,
}) => showDialog<void>(
  context: context,
  builder: (_) => _DocumentDialogFrame(
    child: _FileDocument(path: path, details: details),
  ),
);

/// Whether [path] is a local file the viewer can show.
bool isViewableDocumentPath(String path) =>
    DocumentFormat.forPath(path) != null;

class _DocumentDialogFrame extends StatelessWidget {
  const _DocumentDialogFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: size.width * 0.05,
        vertical: size.height * 0.05,
      ),
      backgroundColor: AppColors.surface0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: size.width * 0.9,
        height: size.height * 0.9,
        child: child,
      ),
    );
  }
}

class _FileDocument extends StatefulWidget {
  const _FileDocument({required this.path, required this.details});

  final String path;
  final DocumentDetails details;

  @override
  State<_FileDocument> createState() => _FileDocumentState();
}

class _FileDocumentState extends State<_FileDocument> {
  late final String _renderedPath = p.join(
    Directory.systemTemp.path,
    'tree_launcher_documents',
    '${widget.path.hashCode.toRadixString(16)}.html',
  );
  int _reloads = 0;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final format = DocumentFormat.forPath(widget.path)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              DocumentFormatTag(format: format),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.details.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.path} · not saved',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_alt_rounded, size: 16),
                label: const Text('Save to Documents'),
              ),
              IconButton(
                tooltip: 'Reload',
                onPressed: () => setState(() => _reloads++),
                icon: Icon(
                  Icons.refresh_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ),
              IconButton(
                tooltip: 'Open in default app',
                onPressed: () => openExternal(widget.path),
                icon: Icon(
                  Icons.open_in_new_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ),
              IconButton(
                tooltip: 'Close (Esc)',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: AppColors.borderSubtle),
        Expanded(
          child: DocumentView(
            filePath: widget.path,
            format: format,
            title: widget.details.title,
            renderedPath: _renderedPath,
            version: _reloads,
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final documents = context.read<DocumentsController>();
    try {
      final document = await documents.saveFile(widget.path, widget.details);
      if (!mounted) return;
      Navigator.of(context).pop();
      showAppSnackBar(
        'Saved ${document.title} to Documents',
        action: SnackBarAction(
          label: 'View',
          onPressed: () => documents.open(document.id),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      showAppSnackBar('Failed to save: ${userMessage(e)}');
    }
  }
}
