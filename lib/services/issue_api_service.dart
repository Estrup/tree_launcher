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
  const ResolvedIssueRecord({required this.project, required this.issue});

  final Project project;
  final Issue issue;
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

  List<Project> listProjects(String repoPath) {
    final normalizedRepoPath = repoPath.trim();
    if (normalizedRepoPath.isEmpty) {
      throw const IssueApiException(400, 'repoPath is required.');
    }

    return _projectRepository.getProjectsForRepo(normalizedRepoPath);
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

  ResolvedIssueRecord getIssue(String displayId) {
    return _resolveIssue(displayId);
  }

  ResolvedIssueRecord createIssue(
    String repoPath,
    String projectKeyOrName,
    String title, {
    String? description,
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
    );
    return ResolvedIssueRecord(project: project, issue: issue);
  }

  ResolvedIssueRecord updateIssue(
    String displayId, {
    String? title,
    Object? description = descriptionNotProvided,
    List<String>? tags,
    IssueStatus? status,
  }) {
    final resolved = _resolveIssue(displayId);
    final normalizedTitle = title?.trim();
    if (title != null && (normalizedTitle == null || normalizedTitle.isEmpty)) {
      throw const IssueApiException(400, 'title cannot be empty.');
    }

    final normalizedTags = tags?.map((tag) => tag.trim()).where((tag) {
      return tag.isNotEmpty;
    }).toList();

    final updated = Issue(
      id: resolved.issue.id,
      projectId: resolved.issue.projectId,
      issueNumber: resolved.issue.issueNumber,
      projectKey: resolved.issue.projectKey,
      title: normalizedTitle ?? resolved.issue.title,
      description: identical(description, descriptionNotProvided)
          ? resolved.issue.description
          : _normalizeOptionalText(description as String?),
      status: status ?? resolved.issue.status,
      tags: normalizedTags ?? resolved.issue.tags,
      isArchived: resolved.issue.isArchived,
      sortOrder: resolved.issue.sortOrder,
      createdAt: resolved.issue.createdAt,
      updatedAt: resolved.issue.updatedAt,
    );

    _issueRepository.updateIssue(updated);
    final refreshed = _issueRepository.getIssueById(updated.id);
    if (refreshed == null) {
      throw const IssueApiException(
        500,
        'Updated issue could not be reloaded.',
      );
    }

    return ResolvedIssueRecord(project: resolved.project, issue: refreshed);
  }

  ResolvedIssueRecord archiveIssue(String displayId) {
    final resolved = _resolveIssue(displayId);
    _issueRepository.archiveIssue(resolved.issue.id);
    final refreshed = _issueRepository.getIssueById(resolved.issue.id);
    if (refreshed == null) {
      throw const IssueApiException(
        500,
        'Archived issue could not be reloaded.',
      );
    }

    return ResolvedIssueRecord(project: resolved.project, issue: refreshed);
  }

  IssueCommentListResult listComments(String displayId) {
    final resolved = _resolveIssue(displayId);
    final comments = _commentRepository.getCommentsForIssue(resolved.issue.id);
    return IssueCommentListResult(issueRecord: resolved, comments: comments);
  }

  CreatedCommentResult addComment(
    String displayId, {
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

    final resolved = _resolveIssue(displayId);
    final comment = _commentRepository.createComment(
      issueId: resolved.issue.id,
      content: normalizedContent,
      authorType: authorType,
      authorName: normalizedAuthorName,
    );
    return CreatedCommentResult(issueRecord: resolved, comment: comment);
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
        .where((project) => project.name == normalizedQuery)
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

  ResolvedIssueRecord _resolveIssue(String displayId) {
    final normalizedDisplayId = displayId.trim();
    final match = _displayIdPattern.firstMatch(normalizedDisplayId);
    if (match == null) {
      throw const IssueApiException(
        400,
        'Issue id must use the format PROJECT-123.',
      );
    }

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

    final resolved = issues.map((issue) {
      final project = _projectRepository.getProjectById(issue.projectId);
      if (project == null) {
        throw const IssueApiException(
          500,
          'Issue references a missing project record.',
        );
      }
      return ResolvedIssueRecord(project: project, issue: issue);
    }).toList();

    if (resolved.length > 1) {
      throw IssueApiException(
        409,
        'Issue "$normalizedDisplayId" is ambiguous across repositories.',
        details: {
          'matches': resolved.map((record) {
            return {
              'projectId': record.project.id,
              'projectName': record.project.name,
              'projectKey': record.project.key,
              'repoPath': record.project.repoPath,
            };
          }).toList(),
        },
      );
    }

    return resolved.single;
  }

  String? _normalizeOptionalText(String? value) {
    if (value == null) return null;
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
}
