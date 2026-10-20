import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'package:tree_launcher/features/agents/domain/agent_kind.dart';
import 'package:tree_launcher/features/documents/data/document_store.dart';
import 'package:tree_launcher/features/documents/domain/document_library.dart';
import 'package:tree_launcher/features/documents/domain/session_document.dart';

/// The documents sessions have saved, for all repos: the one in-memory copy
/// of their details (not their content), which the Documents page, the
/// agent cards, the worktree rows, the issue dialog and the agent API read.
class DocumentsController extends ChangeNotifier implements DocumentLibrary {
  DocumentsController({
    required DocumentStore store,
    DateTime Function()? clock,
  }) : _store = store,
       _clock = clock ?? DateTime.now;

  final DocumentStore _store;
  final DateTime Function() _clock;
  final Map<String, SessionDocument> _documents = {};
  final _openRequests = StreamController<String>.broadcast();
  final Map<String, String> _selected = {};
  Future<void>? _loading;
  bool _disposed = false;

  /// Loads the saved documents. Safe to call more than once.
  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    for (final document in await _store.load()) {
      _documents[document.id] = document;
    }
    _notify();
  }

  /// Every document, newest update first.
  List<SessionDocument> get documents =>
      _documents.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  @override
  SessionDocument? documentById(String id) => _documents[id];

  @override
  List<SessionDocument> documentsFor({
    String? repoName,
    String? agentId,
    String? issueKey,
    String? worktree,
    AgentKind? kind,
    DocumentFormat? format,
  }) => [
    for (final d in documents)
      if ((repoName == null || d.repoName == repoName) &&
          (agentId == null || d.agentId == agentId) &&
          (issueKey == null || d.issueKeys.contains(issueKey)) &&
          (worktree == null || _inWorktree(d, worktree)) &&
          (kind == null || d.agentKind == kind) &&
          (format == null || d.format == format))
        d,
  ];

  /// The documents about [worktreePath] or about its issue [issueKey].
  List<SessionDocument> documentsForWorktree(
    String worktreePath, {
    String? issueKey,
  }) => [
    for (final d in documents)
      if (_inWorktree(d, worktreePath) ||
          (issueKey != null && d.issueKeys.contains(issueKey)))
        d,
  ];

  /// The documents about pull request [number] in the repo named
  /// [repoName], or about its issue [issueKey].
  List<SessionDocument> documentsForPullRequest(
    String repoName,
    int number, {
    String? issueKey,
  }) => [
    for (final d in documents)
      if ((d.repoName == repoName && d.prNumber == number) ||
          (issueKey != null && d.issueKeys.contains(issueKey)))
        d,
  ];

  static bool _inWorktree(SessionDocument d, String worktree) {
    final path = d.worktreePath;
    if (path == null) return false;
    return p.isAbsolute(worktree)
        ? p.equals(path, worktree)
        : p.basename(path) == worktree;
  }

  /// Whether the repo named [repoName] has any document.
  bool hasDocumentsFor(String repoName) =>
      _documents.values.any((d) => d.repoName == repoName);

  @override
  Future<String?> readText(String id) async {
    final document = _documents[id];
    if (document == null || !document.format.isText) return null;
    try {
      return await File(document.filePath).readAsString();
    } catch (e) {
      debugPrint('DocumentsController: could not read ${document.id}: $e');
      return null;
    }
  }

  /// Where [id]'s rendered Markdown is cached.
  Future<String> renderedPathFor(String id) => _store.renderedPathFor(id);

  /// Saves a document with [bytes] as its file. With [DocumentDetails.agentId]
  /// and [DocumentDetails.name], the run's document of that name is
  /// replaced (keeping its id and creation time) rather than another added.
  Future<({SessionDocument document, bool replaced})> save(
    DocumentDetails details,
    DocumentFormat format,
    List<int> bytes,
  ) async {
    await load();
    final now = _clock();
    final previous = _replaced(details);
    final id = previous?.id ?? _newId();
    final document = SessionDocument(
      id: id,
      repoName: details.repoName,
      title: details.title,
      name: details.name,
      format: format,
      agentId: details.agentId,
      agentKind: details.agentKind,
      claudeSessionId: details.claudeSessionId,
      worktreePath: details.worktreePath,
      branch: details.branch,
      issueKeys: details.issueKeys,
      prNumber: details.prNumber,
      sourcePath: details.sourcePath,
      filePath: await _store.filePathFor(id, format),
      sizeBytes: bytes.length,
      createdAt: previous?.createdAt ?? now,
      updatedAt: now,
    );
    await _store.save(document, bytes, previous: previous);
    _documents[id] = document;
    _notify();
    return (document: document, replaced: previous != null);
  }

  SessionDocument? _replaced(DocumentDetails details) {
    final agentId = details.agentId;
    final name = details.name;
    if (agentId == null || name == null) return null;
    for (final d in _documents.values) {
      if (d.agentId == agentId && d.name == name) return d;
    }
    return null;
  }

  /// Saves the local file at [path] (a document an agent linked to) as a
  /// document of the repo named [repoName].
  Future<SessionDocument> saveFile(String path, DocumentDetails details) async {
    final format = DocumentFormat.forPath(path);
    if (format == null) {
      throw DocumentInputException('not a document: $path');
    }
    final bytes = await File(path).readAsBytes();
    return (await save(details, format, bytes)).document;
  }

  /// Removes the document and its file.
  Future<void> delete(String id) async {
    final document = _documents[id];
    if (document == null) return;
    await _store.delete(document);
    _documents.remove(id);
    _selected.removeWhere((_, selected) => selected == id);
    _notify();
  }

  /// Requests to show a document, which the window answers by opening it in
  /// the viewer dialog.
  Stream<String> get openRequests => _openRequests.stream;

  /// Asks the window to show document [id].
  void open(String id) {
    if (_documents.containsKey(id)) _openRequests.add(id);
  }

  /// The document selected on the repo's Documents page.
  String? selectedFor(String repoName) {
    final id = _selected[repoName];
    return id != null && _documents.containsKey(id) ? id : null;
  }

  void select(String repoName, String? id) {
    if (_selected[repoName] == id) return;
    if (id == null) {
      _selected.remove(repoName);
    } else {
      _selected[repoName] = id;
    }
    _notify();
  }

  static final _random = Random.secure();
  static const _idChars = 'abcdefghijklmnopqrstuvwxyz0123456789';

  String _newId() {
    String id;
    do {
      id =
          'doc_${List.generate(8, (_) => _idChars[_random.nextInt(_idChars.length)]).join()}';
    } while (_documents.containsKey(id));
    return id;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _openRequests.close();
    super.dispose();
  }
}
