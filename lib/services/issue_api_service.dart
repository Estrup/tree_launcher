import '../models/comment.dart';
import '../models/issue.dart';
import '../models/issue_status.dart';
import '../models/project.dart';
import 'comment_repository.dart';
import 'issue_repository.dart';
import 'project_repository.dart';

const descriptionNotProvided = Object();

class IssueApiException implements Exception {
  const IssueApiException(this.statusCode, this.summary, {this.details});

  final int statusCode;
  final String summary;
  final Map<String, dynamic>? details;

  @override
  String toString() => 'IssueApiException($statusCode): $summary';
}

class ResolvedIssueRecord {
  const ResolvedIssueRecord({
    required this.project,
    required this.issue,
    this.diagnostics = const {},
  });

  final Project project;
  final Issue issue;
  final Map<String, dynamic> diagnostics;
}

class IssueListResult {
  const IssueListResult({required this.project, required this.issues});

  final Project project;
  final List<Issue> issues;
}

class IssueCommentListResult {
  const IssueCommentListResult({
    required this.issueRecord,
    required this.comments,
  });

  final ResolvedIssueRecord issueRecord;
  final List<Comment> comments;
}

class CreatedCommentResult {
  const CreatedCommentResult({
    required this.issueRecord,
    required this.comment,
  });

  final ResolvedIssueRecord issueRecord;
  final Comment comment;
}

class IssueSyncInput {
  const IssueSyncInput({
    required this.title,
    this.description,
    this.status = IssueStatus.todo,
    this.tags = const [],
    this.archive = false,
  });

  final String title;
  final String? description;
  final IssueStatus status;
  final List<String> tags;
  final bool archive;
}

class IssueSyncOperation {
  const IssueSyncOperation({required this.action, required this.issueRecord});

  final String action;
  final ResolvedIssueRecord issueRecord;
}

class IssueSyncResult {
  const IssueSyncResult({required this.project, required this.operations});

  final Project project;
  final List<IssueSyncOperation> operations;
}

class IssueApiService {
  IssueApiService({
    ProjectRepository? projectRepository,
    IssueRepository? issueRepository,
    CommentRepository? commentRepository,
  }) : _projectRepository = projectRepository ?? ProjectRepository(),
       _issueRepository = issueRepository ?? IssueRepository(),
       _commentRepository = commentRepository ?? CommentRepository();

  static final RegExp _displayIdPattern = RegExp(r'^([A-Za-z0-9]+)-(\d+)$');

  final ProjectRepository _projectRepository;
  final IssueRepository _issueRepository;
  final CommentRepository _commentRepository;

  List<Project> listProjects({
    String? repoPath,
    String? query,
    bool includeArchived = false,
  }) {
    final projects = _loadProjects(
      repoPath: repoPath,
      includeArchived: includeArchived,
    );
    final normalizedQuery = query?.trim();
    if (normalizedQuery == null || normalizedQuery.isEmpty) {
      return projects;
    }

    return _filterProjectsByQuery(projects, normalizedQuery);
  }

  Project createProject(String repoPath, String name, String key) {
    final normalizedRepoPath = repoPath.trim();
    final normalizedName = name.trim();
    final normalizedKey = key.trim().toUpperCase();
    if (normalizedRepoPath.isEmpty) {
      throw const IssueApiException(400, 'repoPath is required.');
    }
    if (normalizedName.isEmpty) {
      throw const IssueApiException(400, 'name is required.');
    }
    if (normalizedKey.isEmpty) {
      throw const IssueApiException(400, 'key is required.');
    }

    final existingProjects = _projectRepository.getAllProjectsForRepo(
      normalizedRepoPath,
    );
    if (existingProjects.any((project) => project.key == normalizedKey)) {
      throw IssueApiException(
        409,
        'Project key "$normalizedKey" already exists in repository "$normalizedRepoPath".',
      );
    }
    if (existingProjects.any(
      (project) => project.name.toLowerCase() == normalizedName.toLowerCase(),
    )) {
      throw IssueApiException(
        409,
        'Project name "$normalizedName" already exists in repository "$normalizedRepoPath".',
      );
    }

    return _projectRepository.createProject(
      normalizedRepoPath,
      normalizedName,
      normalizedKey,
    );
  }

  IssueListResult listIssues(
    String repoPath,
    String projectKeyOrName, {
    bool includeArchived = false,
  }) {
    final project = _resolveProject(repoPath, projectKeyOrName);
    final issues = _issueRepository.getIssuesForProjectIncludingArchived(
      project.id,
      includeArchived: includeArchived,
    );
    return IssueListResult(project: project, issues: issues);
  }

  ResolvedIssueRecord getIssue(
    String displayId, {
    String? repoPath,
    String? projectKeyOrName,
  }) {
    return _resolveIssue(
      displayId,
      repoPath: repoPath,
      projectKeyOrName: projectKeyOrName,
    );
  }

  ResolvedIssueRecord createIssue(
    String repoPath,
    String projectKeyOrName,
    String title, {
    String? description,
    List<String>? tags,
    IssueStatus status = IssueStatus.todo,
  }) {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw const IssueApiException(400, 'title is required.');
    }

    final project = _resolveProject(repoPath, projectKeyOrName);
    final issue = _issueRepository.createIssue(
      project.id,
      project.key,
      normalizedTitle,
      description: _normalizeOptionalText(description),
      status: status,
      tags: _normalizeTags(tags),
    );
    return ResolvedIssueRecord(project: project, issue: issue);
  }

  ResolvedIssueRecord updateIssue(
    String displayId, {
    String? repoPath,
    String? projectKeyOrName,
    String? title,
    Object? description = descriptionNotProvided,
    List<String>? tags,
    IssueStatus? status,
  }) {
    final resolved = _resolveIssue(
      displayId,
      repoPath: repoPath,
      projectKeyOrName: projectKeyOrName,
    );
    final normalizedTitle = title?.trim();
    if (title != null && (normalizedTitle == null || normalizedTitle.isEmpty)) {
      throw const IssueApiException(400, 'title cannot be empty.');
    }

    final updated = resolved.issue.copyWith(
      title: normalizedTitle,
      description: identical(description, descriptionNotProvided)
          ? descriptionNotProvided
          : _normalizeOptionalText(description as String?),
      status: status,
      tags: tags == null ? null : _normalizeTags(tags),
    );

    _issueRepository.updateIssue(updated);
    final refreshed = _issueRepository.getIssueById(updated.id);
    if (refreshed == null) {
      throw const IssueApiException(
        500,
        'Updated issue could not be reloaded.',
      );
    }

    return ResolvedIssueRecord(
      project: resolved.project,
      issue: refreshed,
      diagnostics: resolved.diagnostics,
    );
  }

  ResolvedIssueRecord archiveIssue(
    String displayId, {
    String? repoPath,
    String? projectKeyOrName,
  }) {
    final resolved = _resolveIssue(
      displayId,
      repoPath: repoPath,
      projectKeyOrName: projectKeyOrName,
    );
    _issueRepository.archiveIssue(resolved.issue.id);
    final refreshed = _issueRepository.getIssueById(resolved.issue.id);
    if (refreshed == null) {
      throw const IssueApiException(
        500,
        'Archived issue could not be reloaded.',
      );
    }

    return ResolvedIssueRecord(
      project: resolved.project,
      issue: refreshed,
      diagnostics: resolved.diagnostics,
    );
  }

  IssueCommentListResult listComments(
    String displayId, {
    String? repoPath,
    String? projectKeyOrName,
  }) {
    final resolved = _resolveIssue(
      displayId,
      repoPath: repoPath,
      projectKeyOrName: projectKeyOrName,
    );
    final comments = _commentRepository.getCommentsForIssue(resolved.issue.id);
    return IssueCommentListResult(issueRecord: resolved, comments: comments);
  }

  CreatedCommentResult addComment(
    String displayId, {
    String? repoPath,
    String? projectKeyOrName,
    required String content,
    required String authorName,
    CommentAuthorType authorType = CommentAuthorType.agent,
  }) {
    final normalizedContent = content.trim();
    if (normalizedContent.isEmpty) {
      throw const IssueApiException(400, 'content is required.');
    }

    final normalizedAuthorName = authorName.trim();
    if (normalizedAuthorName.isEmpty) {
      throw const IssueApiException(400, 'authorName is required.');
    }

    final resolved = _resolveIssue(
      displayId,
      repoPath: repoPath,
      projectKeyOrName: projectKeyOrName,
    );
    final comment = _commentRepository.createComment(
      issueId: resolved.issue.id,
      content: normalizedContent,
      authorType: authorType,
      authorName: normalizedAuthorName,
    );
    return CreatedCommentResult(issueRecord: resolved, comment: comment);
  }

  IssueSyncResult syncIssues(
    String repoPath,
    String projectKeyOrName,
    List<IssueSyncInput> inputs,
  ) {
    if (inputs.isEmpty) {
      throw const IssueApiException(
        400,
        'issues must contain at least one item.',
      );
    }

    final project = _resolveProject(repoPath, projectKeyOrName);
    final existingIssues = {
      for (final issue in _issueRepository.getIssuesForProject(project.id))
        issue.title: issue,
    };
    final operations = <IssueSyncOperation>[];

    for (final input in inputs) {
      final normalizedTitle = input.title.trim();
      if (normalizedTitle.isEmpty) {
        throw const IssueApiException(400, 'Each issue title is required.');
      }

      final normalizedDescription = _normalizeOptionalText(input.description);
      final normalizedTags = _normalizeTags(input.tags);
      final existing = existingIssues[normalizedTitle];

      if (existing == null) {
        if (input.archive) {
          throw IssueApiException(
            404,
            'Cannot archive missing issue titled "$normalizedTitle".',
          );
        }

        final created = createIssue(
          project.repoPath,
          project.key,
          normalizedTitle,
          description: normalizedDescription,
          tags: normalizedTags,
          status: input.status,
        );
        existingIssues[normalizedTitle] = created.issue;
        operations.add(
          IssueSyncOperation(action: 'created', issueRecord: created),
        );
        continue;
      }

      final updated = existing.copyWith(
        description: normalizedDescription,
        status: input.status,
        tags: normalizedTags,
        isArchived: input.archive,
      );
      _issueRepository.updateIssue(updated);
      final refreshed = _issueRepository.getIssueById(updated.id);
      if (refreshed == null) {
        throw const IssueApiException(
          500,
          'Synced issue could not be reloaded.',
        );
      }

      existingIssues[normalizedTitle] = refreshed;
      operations.add(
        IssueSyncOperation(
          action: input.archive ? 'archived' : 'updated',
          issueRecord: ResolvedIssueRecord(project: project, issue: refreshed),
        ),
      );
    }

    return IssueSyncResult(project: project, operations: operations);
  }

  Map<String, dynamic> getDiagnostics({String? displayId}) {
    final issues = _loadIssuesForDiagnostics(displayId);
    final orphanedIssues = <Map<String, dynamic>>[];
    final validMatches = <String, List<ResolvedIssueRecord>>{};

    for (final issue in issues) {
      final project = _projectRepository.getProjectById(issue.projectId);
      if (project == null) {
        orphanedIssues.add(_serializeOrphanedIssue(issue));
        continue;
      }

      validMatches
          .putIfAbsent(issue.displayId, () => [])
          .add(ResolvedIssueRecord(project: project, issue: issue));
    }

    final duplicateDisplayIds = validMatches.entries
        .where((entry) => entry.value.length > 1)
        .map((entry) {
          return {
            'displayId': entry.key,
            'matches': entry.value.map(_serializeResolvedIssueSummary).toList(),
          };
        })
        .toList();

    return {
      'orphanedIssues': orphanedIssues,
      'duplicateDisplayIds': duplicateDisplayIds,
    };
  }

  Project _resolveProject(String repoPath, String projectKeyOrName) {
    final normalizedRepoPath = repoPath.trim();
    if (normalizedRepoPath.isEmpty) {
      throw const IssueApiException(400, 'repoPath is required.');
    }

    final normalizedQuery = projectKeyOrName.trim();
    if (normalizedQuery.isEmpty) {
      throw const IssueApiException(400, 'project is required.');
    }

    final projects = _projectRepository.getProjectsForRepo(normalizedRepoPath);
    final keyMatches = projects
        .where((project) => project.key == normalizedQuery.toUpperCase())
        .toList();
    if (keyMatches.length == 1) return keyMatches.single;
    if (keyMatches.length > 1) {
      throw IssueApiException(
        409,
        'Project key "$normalizedQuery" is ambiguous in this repository.',
      );
    }

    final nameMatches = projects
        .where(
          (project) =>
              project.name.toLowerCase() == normalizedQuery.toLowerCase(),
        )
        .toList();
    if (nameMatches.length == 1) return nameMatches.single;
    if (nameMatches.length > 1) {
      throw IssueApiException(
        409,
        'Project name "$normalizedQuery" is ambiguous in this repository.',
      );
    }

    throw IssueApiException(
      404,
      'Project "$normalizedQuery" was not found in repository "$normalizedRepoPath".',
    );
  }

  ResolvedIssueRecord _resolveIssue(
    String displayId, {
    String? repoPath,
    String? projectKeyOrName,
  }) {
    final normalizedDisplayId = displayId.trim();
    final match = _displayIdPattern.firstMatch(normalizedDisplayId);
    if (match == null) {
      throw const IssueApiException(
        400,
        'Issue id must use the format PROJECT-123.',
      );
    }

    final normalizedRepoPath = _normalizeOptionalScopeValue(
      repoPath,
      fieldName: 'repoPath',
    );
    final normalizedProjectQuery = _normalizeOptionalScopeValue(
      projectKeyOrName,
      fieldName: 'project',
    );

    final projectKey = match.group(1)!.toUpperCase();
    final issueNumber = int.parse(match.group(2)!);
    final issues = _issueRepository.findIssuesByDisplayId(
      projectKey: projectKey,
      issueNumber: issueNumber,
    );

    if (issues.isEmpty) {
      throw IssueApiException(
        404,
        'Issue "$normalizedDisplayId" was not found.',
      );
    }

    final orphanedMatches = <Issue>[];
    final validMatches = <ResolvedIssueRecord>[];
    for (final issue in issues) {
      final project = _projectRepository.getProjectById(issue.projectId);
      if (project == null) {
        orphanedMatches.add(issue);
        continue;
      }
      validMatches.add(ResolvedIssueRecord(project: project, issue: issue));
    }

    final scopedMatches = validMatches.where((record) {
      if (normalizedRepoPath != null &&
          record.project.repoPath != normalizedRepoPath) {
        return false;
      }
      if (normalizedProjectQuery != null &&
          !_projectMatches(record.project, normalizedProjectQuery)) {
        return false;
      }
      return true;
    }).toList();

    final diagnostics = _buildResolutionDiagnostics(orphanedMatches);
    if (scopedMatches.isEmpty) {
      if (validMatches.isEmpty && orphanedMatches.isNotEmpty) {
        throw IssueApiException(
          409,
          'Issue "$normalizedDisplayId" only matched orphaned issue records.',
          details: diagnostics,
        );
      }

      final details = <String, dynamic>{
        if (validMatches.isNotEmpty)
          'matches': validMatches.map(_serializeResolvedIssueSummary).toList(),
        ...diagnostics,
      };
      throw IssueApiException(
        404,
        _buildScopedNotFoundSummary(
          normalizedDisplayId,
          repoPath: normalizedRepoPath,
          projectKeyOrName: normalizedProjectQuery,
        ),
        details: details.isEmpty ? null : details,
      );
    }

    if (scopedMatches.length > 1) {
      throw IssueApiException(
        409,
        'Issue "$normalizedDisplayId" is ambiguous across repositories.',
        details: {
          'matches': scopedMatches.map(_serializeResolvedIssueSummary).toList(),
          ...diagnostics,
        },
      );
    }

    final resolved = scopedMatches.single;
    if (diagnostics.isEmpty) {
      return resolved;
    }
    return ResolvedIssueRecord(
      project: resolved.project,
      issue: resolved.issue,
      diagnostics: diagnostics,
    );
  }

  List<Project> _loadProjects({
    String? repoPath,
    required bool includeArchived,
  }) {
    final normalizedRepoPath = repoPath?.trim();
    if (repoPath != null &&
        (normalizedRepoPath == null || normalizedRepoPath.isEmpty)) {
      throw const IssueApiException(400, 'repoPath is required.');
    }

    if (normalizedRepoPath != null) {
      return includeArchived
          ? _projectRepository.getAllProjectsForRepo(normalizedRepoPath)
          : _projectRepository.getProjectsForRepo(normalizedRepoPath);
    }

    return includeArchived
        ? _projectRepository.getAllProjectsIncludingArchived()
        : _projectRepository.getAllProjects();
  }

  List<Project> _filterProjectsByQuery(List<Project> projects, String query) {
    final uppercaseQuery = query.toUpperCase();
    final lowercaseQuery = query.toLowerCase();

    final exactKeyMatches = projects
        .where((project) => project.key == uppercaseQuery)
        .toList();
    if (exactKeyMatches.isNotEmpty) {
      return exactKeyMatches;
    }

    final exactNameMatches = projects
        .where((project) => project.name.toLowerCase() == lowercaseQuery)
        .toList();
    if (exactNameMatches.isNotEmpty) {
      return exactNameMatches;
    }

    return projects.where((project) {
      return project.key.contains(uppercaseQuery) ||
          project.name.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  bool _projectMatches(Project project, String query) {
    return project.key == query.toUpperCase() ||
        project.name.toLowerCase() == query.toLowerCase();
  }

  String? _normalizeOptionalScopeValue(
    String? value, {
    required String fieldName,
  }) {
    if (value == null) return null;
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw IssueApiException(400, '$fieldName is required.');
    }
    return normalized;
  }

  List<String> _normalizeTags(List<String>? tags) {
    return tags
            ?.map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toList() ??
        const [];
  }

  String? _normalizeOptionalText(String? value) {
    if (value == null) return null;
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  List<Issue> _loadIssuesForDiagnostics(String? displayId) {
    if (displayId == null) {
      return _issueRepository.getAllIssues();
    }

    final normalizedDisplayId = displayId.trim();
    final match = _displayIdPattern.firstMatch(normalizedDisplayId);
    if (match == null) {
      throw const IssueApiException(
        400,
        'Issue id must use the format PROJECT-123.',
      );
    }

    return _issueRepository.findIssuesByDisplayId(
      projectKey: match.group(1)!.toUpperCase(),
      issueNumber: int.parse(match.group(2)!),
    );
  }

  String _buildScopedNotFoundSummary(
    String displayId, {
    String? repoPath,
    String? projectKeyOrName,
  }) {
    if (repoPath != null && projectKeyOrName != null) {
      return 'Issue "$displayId" was not found in project "$projectKeyOrName" for repository "$repoPath".';
    }
    if (repoPath != null) {
      return 'Issue "$displayId" was not found in repository "$repoPath".';
    }
    if (projectKeyOrName != null) {
      return 'Issue "$displayId" was not found in project "$projectKeyOrName".';
    }
    return 'Issue "$displayId" was not found.';
  }

  Map<String, dynamic> _buildResolutionDiagnostics(
    List<Issue> orphanedMatches,
  ) {
    if (orphanedMatches.isEmpty) {
      return const {};
    }
    return {
      'orphanedMatches': orphanedMatches.map(_serializeOrphanedIssue).toList(),
    };
  }

  Map<String, dynamic> _serializeResolvedIssueSummary(
    ResolvedIssueRecord record,
  ) {
    return {
      'id': record.issue.id,
      'displayId': record.issue.displayId,
      'projectId': record.project.id,
      'projectName': record.project.name,
      'projectKey': record.project.key,
      'repoPath': record.project.repoPath,
      'title': record.issue.title,
      'status': record.issue.status.name,
      'isArchived': record.issue.isArchived,
    };
  }

  Map<String, dynamic> _serializeOrphanedIssue(Issue issue) {
    return {
      'id': issue.id,
      'displayId': issue.displayId,
      'projectId': issue.projectId,
      'title': issue.title,
      'status': issue.status.name,
      'isArchived': issue.isArchived,
    };
  }
}
