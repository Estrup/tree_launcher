import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'package:tree_launcher/core/database/app_database.dart';
import 'package:tree_launcher/core/storage/app_data_directory.dart';
import 'package:tree_launcher/features/agents/domain/agent_kind.dart';
import 'package:tree_launcher/features/documents/domain/session_document.dart';

/// Persists documents: their details in `documents` (their issue keys in
/// `document_issues`) and each one's file in the data directory's
/// `documents/` folder, as `<id>.md`, `<id>.html` or `<id>.pdf`. Rendered
/// Markdown is cached in `documents/.view/`.
class DocumentStore {
  DocumentStore(this._db, {Future<String> Function()? directory})
    : _directory =
          directory ??
          (() async => p.join(await appDataDirectory(), 'documents'));

  final AppDatabase _db;
  final Future<String> Function() _directory;
  String? _resolved;

  /// The folder the files are in.
  Future<String> directory() async => _resolved ??= await _directory();

  /// Where document [id]'s file in [format] is kept.
  Future<String> filePathFor(String id, DocumentFormat format) async =>
      p.join(await directory(), '$id.${format.extension}');

  /// Where document [id]'s rendered Markdown is cached.
  Future<String> renderedPathFor(String id) async =>
      p.join(await directory(), '.view', '$id.html');

  /// Every saved document. Never throws; an unreadable row is skipped.
  Future<List<SessionDocument>> load() async {
    try {
      final dir = await directory();
      final rows = await _db.select(_db.documents).get();
      final issueRows = await (_db.select(
        _db.documentIssues,
      )..orderBy([(t) => OrderingTerm(expression: t.position)])).get();
      final issueKeys = <String, List<String>>{};
      for (final row in issueRows) {
        issueKeys.putIfAbsent(row.documentId, () => []).add(row.issueKey);
      }
      final documents = <SessionDocument>[];
      for (final row in rows) {
        final format = DocumentFormat.tryParse(row.format);
        if (format == null) {
          debugPrint('DocumentStore: skipping ${row.id}: format ${row.format}');
          continue;
        }
        documents.add(
          SessionDocument(
            id: row.id,
            repoName: row.repo,
            title: row.title,
            name: row.name,
            format: format,
            agentId: row.agentId,
            agentKind: AgentKind.tryParse(row.agentKind),
            claudeSessionId: row.claudeSessionId,
            worktreePath: row.worktreePath,
            branch: row.branch,
            issueKeys: issueKeys[row.id] ?? const [],
            prNumber: row.prNumber,
            sourcePath: row.sourcePath,
            filePath: p.join(dir, '${row.id}.${format.extension}'),
            sizeBytes: row.sizeBytes,
            createdAt: row.createdAt,
            updatedAt: row.updatedAt,
          ),
        );
      }
      return documents;
    } catch (e) {
      debugPrint('DocumentStore.load failed: $e');
      return [];
    }
  }

  /// Saves [document] with [bytes] as its file. When it replaces [previous]
  /// (the same id), the new file is written next to the old one and renamed
  /// over it; a file in [previous]'s other format is removed. Throws when
  /// the file or the row can't be written.
  Future<void> save(
    SessionDocument document,
    List<int> bytes, {
    SessionDocument? previous,
  }) async {
    final file = File(document.filePath);
    await file.parent.create(recursive: true);
    final staged = File('${document.filePath}.new');
    await staged.writeAsBytes(bytes, flush: true);
    await staged.rename(document.filePath);
    try {
      await _db.transaction(() async {
        await _db.into(_db.documents).insertOnConflictUpdate(_row(document));
        await (_db.delete(
          _db.documentIssues,
        )..where((t) => t.documentId.equals(document.id))).go();
        await _db.batch(
          (batch) => batch.insertAll(_db.documentIssues, [
            for (final (i, key) in document.issueKeys.indexed)
              DocumentIssuesCompanion.insert(
                documentId: document.id,
                issueKey: key,
                position: i,
              ),
          ]),
        );
      });
    } catch (_) {
      if (previous == null) await _deleteFile(document.filePath);
      rethrow;
    }
    if (previous != null && previous.filePath != document.filePath) {
      await _deleteFile(previous.filePath);
    }
    await _deleteFile(await renderedPathFor(document.id));
  }

  /// Removes [document]'s row (and so its issue keys), its file and its
  /// rendered cache. Throws when the row can't be deleted.
  Future<void> delete(SessionDocument document) async {
    await (_db.delete(
      _db.documents,
    )..where((t) => t.id.equals(document.id))).go();
    await _deleteFile(document.filePath);
    await _deleteFile(await renderedPathFor(document.id));
  }

  static DocumentsCompanion _row(SessionDocument d) =>
      DocumentsCompanion.insert(
        id: d.id,
        repo: d.repoName,
        title: d.title,
        name: Value(d.name),
        format: d.format.name,
        agentId: Value(d.agentId),
        agentKind: Value(d.agentKind?.name),
        claudeSessionId: Value(d.claudeSessionId),
        worktreePath: Value(d.worktreePath),
        branch: Value(d.branch),
        prNumber: Value(d.prNumber),
        sourcePath: Value(d.sourcePath),
        sizeBytes: d.sizeBytes,
        createdAt: d.createdAt,
        updatedAt: d.updatedAt,
      );

  static Future<void> _deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('DocumentStore: could not delete $path: $e');
    }
  }
}
