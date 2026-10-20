import 'package:tree_launcher/features/agents/domain/agent_kind.dart';
import 'package:tree_launcher/features/documents/domain/session_document.dart';

/// The saved documents in the running app, for the agent HTTP API.
///
/// Implemented by the live `DocumentsController`, so the API and the
/// Documents page always agree.
abstract interface class DocumentLibrary {
  /// The documents matching every given filter, newest update first.
  /// [worktree] is a worktree's path or folder name.
  List<SessionDocument> documentsFor({
    String? repoName,
    String? agentId,
    String? issueKey,
    String? worktree,
    AgentKind? kind,
    DocumentFormat? format,
  });

  SessionDocument? documentById(String id);

  /// A text document's content; null for a PDF, or when the file is gone.
  Future<String?> readText(String id);
}

/// A request to save a document, as the agent API takes it.
class DocumentRequest {
  const DocumentRequest({
    required this.title,
    this.agentId,
    this.repoName,
    this.name,
    this.content,
    this.path,
    this.format,
    this.worktreePath,
    this.issueKeys,
    this.prNumber,
    this.claudeSessionId,
    this.show = false,
  });

  final String title;

  /// The agent run it came from; its repo, worktree, branch, issues, PR and
  /// Claude session are used for what isn't given here.
  final String? agentId;
  final String? repoName;
  final String? name;

  /// The document as text, or [path] to a file to copy: one of the two.
  final String? content;
  final String? path;

  /// Required with [content]; with [path], from its extension.
  final DocumentFormat? format;
  final String? worktreePath;

  /// Null: the run's issues, else the worktree's recorded issue.
  final List<String>? issueKeys;
  final int? prNumber;
  final String? claudeSessionId;

  /// Open it in the app's viewer at once, rather than offering to.
  final bool show;
}

/// What saving a document did.
class SavedDocument {
  const SavedDocument({
    required this.document,
    required this.replaced,
    this.warnings = const [],
  });

  final SessionDocument document;

  /// Whether it replaced the run's document of the same name.
  final bool replaced;

  /// What won't show as it should (see `documentReferenceWarnings`).
  final List<String> warnings;
}

/// Saves documents in the running app, for the agent HTTP API. Implemented
/// by the `SaveDocument` use case.
abstract interface class DocumentSaver {
  /// Saves [request]. Throws `AgentNotFoundException` or
  /// `RepoNotFoundException` (404), [DocumentInputException] (400) and
  /// [DocumentTooLargeException] (413).
  Future<SavedDocument> save(DocumentRequest request);
}

/// The document can't be saved as given: a missing or unreadable file, a
/// file that isn't what its extension says, a repo that doesn't match.
class DocumentInputException implements Exception {
  const DocumentInputException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The document is over [limitBytes].
class DocumentTooLargeException implements Exception {
  const DocumentTooLargeException(this.limitBytes);

  final int limitBytes;

  @override
  String toString() =>
      'document is over the ${limitBytes ~/ (1024 * 1024)} MB limit';
}

/// The most text a request's `content` may hold.
const maxDocumentContentBytes = 5 * 1024 * 1024;

/// The largest file `path` may name.
const maxDocumentFileBytes = 50 * 1024 * 1024;
