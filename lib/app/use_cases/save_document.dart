import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'package:tree_launcher/app/use_cases/agent_launcher.dart';
import 'package:tree_launcher/core/design_system/app_snackbar.dart';
import 'package:tree_launcher/features/agents/domain/agent_registry.dart';
import 'package:tree_launcher/features/agents/domain/agent_run.dart';
import 'package:tree_launcher/features/documents/domain/document_library.dart';
import 'package:tree_launcher/features/documents/domain/document_references.dart';
import 'package:tree_launcher/features/documents/domain/session_document.dart';
import 'package:tree_launcher/features/documents/presentation/controllers/documents_controller.dart';
import 'package:tree_launcher/features/workspace/domain/repo_catalog.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_creator.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_metadata.dart';

/// Saves a document a session sends through the agent API
/// (`POST /v1/documents`): fills in what it is about from its agent run or
/// its worktree, checks and reads the file, saves it in
/// [DocumentsController], notes it on the run's timeline, and shows it or
/// offers to.
class SaveDocument implements DocumentSaver {
  SaveDocument({
    required RepoCatalog repos,
    required AgentRegistry agents,
    required WorktreeMetadata? Function(String worktreePath) metadataFor,
    required DocumentsController documents,
    void Function(String message, {SnackBarAction? action})? notify,
  }) : _repos = repos,
       _agents = agents,
       _metadataFor = metadataFor,
       _documents = documents,
       _notify = notify ?? showAppSnackBar;

  final RepoCatalog _repos;
  final AgentRegistry _agents;
  final WorktreeMetadata? Function(String worktreePath) _metadataFor;
  final DocumentsController _documents;
  final void Function(String message, {SnackBarAction? action}) _notify;

  @override
  Future<SavedDocument> save(DocumentRequest request) async {
    AgentRun? run;
    final agentId = request.agentId;
    if (agentId != null) {
      run = _agents.runById(agentId);
      if (run == null) throw AgentNotFoundException(agentId);
    }
    final repoName = request.repoName ?? run?.repoName;
    if (repoName == null) {
      throw const DocumentInputException('repo is required without agentId');
    }
    if (run != null && repoName != run.repoName) {
      throw DocumentInputException(
        'agent ${run.id} is in repo ${run.repoName}, not $repoName',
      );
    }
    final repos = await _repos.loadedRepos();
    if (!repos.any((r) => r.name == repoName)) {
      throw RepoNotFoundException(repoName);
    }

    final (:format, :bytes) = await _read(request);
    final warnings = format.isText
        ? documentReferenceWarnings(utf8.decode(bytes), format)
        : const <String>[];

    final requestedWorktree = request.worktreePath;
    final worktreePath = requestedWorktree != null
        ? p.normalize(requestedWorktree)
        : run?.worktreePath;
    final issueKeys =
        request.issueKeys ??
        (run != null && run.issueKeys.isNotEmpty
            ? run.issueKeys
            : [?_worktreeIssue(worktreePath)]);

    final saved = await _documents.save(
      DocumentDetails(
        repoName: repoName,
        title: request.title,
        name: request.name,
        agentId: run?.id,
        agentKind: run?.kind,
        claudeSessionId: request.claudeSessionId ?? run?.claudeSessionId,
        worktreePath: worktreePath,
        branch: run?.branch,
        issueKeys: issueKeys,
        prNumber: request.prNumber ?? run?.prNumber,
        sourcePath: request.path,
      ),
      format,
      bytes,
    );
    final document = saved.document;

    if (run != null) {
      await _agents.note(
        run.id,
        '${saved.replaced ? 'Document updated' : 'Document saved'}: '
        '${document.title}',
      );
    }
    if (request.show) {
      _documents.open(document.id);
    } else {
      final from = run != null
          ? AgentLauncher.titleFor(run)
          : p.basename(worktreePath ?? repoName);
      _notify(
        'Document from $from: ${document.title}',
        action: SnackBarAction(
          label: 'View',
          onPressed: () => _documents.open(document.id),
        ),
      );
    }
    return SavedDocument(
      document: document,
      replaced: saved.replaced,
      warnings: warnings,
    );
  }

  String? _worktreeIssue(String? worktreePath) =>
      worktreePath == null ? null : _metadataFor(worktreePath)?.jiraIssue;

  /// The document's format and bytes: [DocumentRequest.content] as given, or
  /// the file at [DocumentRequest.path], checked.
  static Future<({DocumentFormat format, List<int> bytes})> _read(
    DocumentRequest request,
  ) async {
    final content = request.content;
    if (content != null) {
      final bytes = utf8.encode(content);
      if (bytes.length > maxDocumentContentBytes) {
        throw const DocumentTooLargeException(maxDocumentContentBytes);
      }
      return (format: request.format!, bytes: bytes);
    }

    final path = request.path!;
    final format = DocumentFormat.forPath(path);
    if (format == null) {
      throw DocumentInputException(
        'path must be a .md, .markdown, .html, .htm or .pdf file: $path',
      );
    }
    if (request.format != null && request.format != format) {
      throw DocumentInputException(
        'format ${request.format!.name} does not match $path',
      );
    }
    final file = File(path);
    final List<int> bytes;
    try {
      if (await file.length() > maxDocumentFileBytes) {
        throw const DocumentTooLargeException(maxDocumentFileBytes);
      }
      bytes = await file.readAsBytes();
    } on FileSystemException catch (e) {
      throw DocumentInputException(
        'cannot read $path: ${e.osError?.message ?? e.message}',
      );
    }
    if (format == DocumentFormat.pdf) {
      if (!_isPdf(bytes)) {
        throw DocumentInputException('$path is not a PDF');
      }
    } else {
      try {
        utf8.decode(bytes);
      } on FormatException {
        throw DocumentInputException('$path is not UTF-8 text');
      }
    }
    return (format: format, bytes: bytes);
  }

  static bool _isPdf(List<int> bytes) =>
      bytes.length >= 5 &&
      ascii.decode(bytes.sublist(0, 5), allowInvalid: true) == '%PDF-';
}
