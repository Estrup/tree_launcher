import 'package:path/path.dart' as p;

import 'package:tree_launcher/features/agents/domain/agent_kind.dart';

/// What a document is written in. Each is one self-contained file.
enum DocumentFormat {
  markdown('md', 'MD'),
  html('html', 'HTML'),
  pdf('pdf', 'PDF');

  const DocumentFormat(this.extension, this.label);

  /// The stored file's extension.
  final String extension;

  /// The short tag the list shows.
  final String label;

  /// Whether the document is text (and can be given as `content`).
  bool get isText => this != DocumentFormat.pdf;

  static DocumentFormat? tryParse(String? name) {
    if (name == null) return null;
    final lower = name.trim().toLowerCase();
    for (final format in values) {
      if (format.name == lower) return format;
    }
    return null;
  }

  /// The format of a file with [path]'s extension, or null for one that
  /// isn't a document.
  static DocumentFormat? forPath(String path) =>
      switch (p.extension(path).toLowerCase()) {
        '.md' || '.markdown' => DocumentFormat.markdown,
        '.html' || '.htm' => DocumentFormat.html,
        '.pdf' => DocumentFormat.pdf,
        _ => null,
      };
}

/// A document a session saved about its work: a result, a clarification, a
/// review, a verification report. Tied to the agent run, Claude session,
/// worktree, issues and PR it is about; the file itself is in the app's
/// data directory, so it outlives the worktree.
class SessionDocument {
  const SessionDocument({
    required this.id,
    required this.repoName,
    required this.title,
    required this.format,
    required this.filePath,
    required this.sizeBytes,
    required this.createdAt,
    required this.updatedAt,
    this.name,
    this.agentId,
    this.agentKind,
    this.claudeSessionId,
    this.worktreePath,
    this.branch,
    this.issueKeys = const [],
    this.prNumber,
    this.sourcePath,
  });

  final String id;
  final String repoName;
  final String title;

  /// Stable within its agent run (`result`, `afklaring`): saving the same
  /// name in the same run replaces the document.
  final String? name;
  final DocumentFormat format;
  final String? agentId;

  /// The run's kind, copied so filtering by kind outlives the run.
  final AgentKind? agentKind;
  final String? claudeSessionId;
  final String? worktreePath;
  final String? branch;
  final List<String> issueKeys;
  final int? prNumber;

  /// Where the file was copied from, if it was a file. Never read again.
  final String? sourcePath;

  /// The stored file.
  final String filePath;
  final int sizeBytes;
  final DateTime createdAt;
  final DateTime updatedAt;

  SessionDocument copyWith({String? filePath}) => SessionDocument(
    id: id,
    repoName: repoName,
    title: title,
    format: format,
    filePath: filePath ?? this.filePath,
    sizeBytes: sizeBytes,
    createdAt: createdAt,
    updatedAt: updatedAt,
    name: name,
    agentId: agentId,
    agentKind: agentKind,
    claudeSessionId: claudeSessionId,
    worktreePath: worktreePath,
    branch: branch,
    issueKeys: issueKeys,
    prNumber: prNumber,
    sourcePath: sourcePath,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'repo': repoName,
    'title': title,
    'name': name,
    'format': format.name,
    'agentId': agentId,
    'agentKind': agentKind?.id,
    'issueKeys': issueKeys,
    'worktreePath': worktreePath,
    'branch': branch,
    'prNumber': prNumber,
    'claudeSessionId': claudeSessionId,
    'sourcePath': sourcePath,
    'filePath': filePath,
    'sizeBytes': sizeBytes,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}

/// What a document is about, as given when it is saved.
class DocumentDetails {
  const DocumentDetails({
    required this.repoName,
    required this.title,
    this.name,
    this.agentId,
    this.agentKind,
    this.claudeSessionId,
    this.worktreePath,
    this.branch,
    this.issueKeys = const [],
    this.prNumber,
    this.sourcePath,
  });

  final String repoName;
  final String title;
  final String? name;
  final String? agentId;
  final AgentKind? agentKind;
  final String? claudeSessionId;
  final String? worktreePath;
  final String? branch;
  final List<String> issueKeys;
  final int? prNumber;
  final String? sourcePath;
}
