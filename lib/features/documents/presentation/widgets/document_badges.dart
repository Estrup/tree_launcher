import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/core/widgets/issue_list.dart';
import 'package:tree_launcher/features/documents/domain/session_document.dart';
import 'package:tree_launcher/features/documents/presentation/controllers/documents_controller.dart';
import 'package:tree_launcher/features/documents/presentation/widgets/document_dialog.dart';
import 'package:tree_launcher/features/documents/presentation/widgets/document_panel.dart';

/// A small count of [documents]; a click lists them, and choosing one opens
/// it in the viewer. Nothing when there are none.
class DocumentsBadge extends StatelessWidget {
  const DocumentsBadge({super.key, required this.documents});

  final List<SessionDocument> documents;

  @override
  Widget build(BuildContext context) {
    if (documents.isEmpty) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      tooltip: documents.length == 1
          ? '1 document'
          : '${documents.length} documents',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 480),
      onSelected: (id) => showDocumentDialog(context, id),
      itemBuilder: (_) => [
        for (final d in documents)
          PopupMenuItem(
            value: d.id,
            child: DocumentMenuEntry(document: d),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.accentMuted,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.article_outlined, size: 11, color: AppColors.accent),
            const SizedBox(width: 3),
            Text(
              '${documents.length}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// [DocumentsBadge] for the documents about a worktree (or its issue), on
/// its row. Nothing when there are none, or no documents in the app (some
/// widget tests).
class WorktreeDocumentsBadge extends StatelessWidget {
  const WorktreeDocumentsBadge({
    super.key,
    required this.worktreePath,
    this.issueKey,
  });

  final String worktreePath;
  final String? issueKey;

  @override
  Widget build(BuildContext context) {
    final documents = Provider.of<DocumentsController?>(
      context,
    )?.documentsForWorktree(worktreePath, issueKey: issueKey);
    if (documents == null || documents.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: DocumentsBadge(documents: documents),
    );
  }
}

/// [DocumentsBadge] for the documents about Jira issue [issueKey], across
/// repos, on its row in an issue list.
class IssueDocumentsBadge extends StatelessWidget {
  const IssueDocumentsBadge({super.key, required this.issueKey});

  final String issueKey;

  @override
  Widget build(BuildContext context) {
    final documents = Provider.of<DocumentsController?>(
      context,
    )?.documentsFor(issueKey: issueKey);
    if (documents == null || documents.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: DocumentsBadge(documents: documents),
    );
  }
}

/// [DocumentsBadge] for the documents about a pull request (or its Jira
/// issue), on its row in the PRs list.
class PullRequestDocumentsBadge extends StatelessWidget {
  const PullRequestDocumentsBadge({
    super.key,
    required this.repoName,
    required this.number,
    this.issueKey,
  });

  final String repoName;
  final int number;
  final String? issueKey;

  @override
  Widget build(BuildContext context) {
    final documents = Provider.of<DocumentsController?>(
      context,
    )?.documentsForPullRequest(repoName, number, issueKey: issueKey);
    if (documents == null || documents.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: DocumentsBadge(documents: documents),
    );
  }
}

/// A document as a line in a menu or list: icon, title, format and age.
class DocumentMenuEntry extends StatelessWidget {
  const DocumentMenuEntry({super.key, required this.document});

  final SessionDocument document;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        documentIcon(document.format),
        size: 14,
        color: AppColors.textSecondary,
      ),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          document.title,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
        ),
      ),
      const SizedBox(width: 8),
      DocumentFormatTag(format: document.format),
      const SizedBox(width: 8),
      Text(
        formatRelativeTime(document.updatedAt),
        style: TextStyle(fontSize: 11, color: AppColors.textMuted),
      ),
    ],
  );
}

/// The documents about issue [issueKey], across repos, for the issue
/// dialog: a heading and one line each; a click opens the document.
class IssueDocumentsSection extends StatelessWidget {
  const IssueDocumentsSection({
    super.key,
    required this.issueKey,
    this.bottomSpacing = 0,
  });

  final String issueKey;

  /// Space below the section, when it shows.
  final double bottomSpacing;

  @override
  Widget build(BuildContext context) {
    final documents = Provider.of<DocumentsController?>(
      context,
    )?.documentsFor(issueKey: issueKey);
    if (documents == null || documents.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IssueSectionLabel('DOCUMENTS', count: documents.length),
        const SizedBox(height: 10),
        for (final d in documents)
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => showDocumentDialog(context, d.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
              child: DocumentMenuEntry(document: d),
            ),
          ),
        SizedBox(height: bottomSpacing),
      ],
    );
  }
}
