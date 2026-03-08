import '../models/comment.dart';
import '../models/issue.dart';
import '../models/issue_status.dart';
import '../models/project.dart';
import 'issue_api_service.dart';

typedef RepoMutationCallback = Future<void> Function(String repoPath);

class IssueApiRequest {
  const IssueApiRequest({
    required this.method,
    required this.pathSegments,
    required this.queryParameters,
    this.body,
  });

  final String method;
  final List<String> pathSegments;
  final Map<String, String> queryParameters;
  final Object? body;
}

class IssueApiResponse {
  const IssueApiResponse({
    required this.statusCode,
    required this.summary,
    required this.data,
    this.ok = true,
  });

  final int statusCode;
  final bool ok;
  final String summary;
  final Map<String, dynamic> data;

  Map<String, dynamic> toJson() => {'ok': ok, 'summary': summary, 'data': data};
}

class IssueApiController {
  IssueApiController({
    required IssueApiService issueService,
    RepoMutationCallback? onRepoMutated,
  }) : _issueService = issueService,
       _onRepoMutated = onRepoMutated;

  final IssueApiService _issueService;
  final RepoMutationCallback? _onRepoMutated;

  Future<IssueApiResponse> handle(IssueApiRequest request) async {
    try {
      return await _handleInternal(request);
    } on IssueApiException catch (error) {
      return IssueApiResponse(
        statusCode: error.statusCode,
        ok: false,
        summary: error.summary,
        data: error.details ?? const {},
      );
    } catch (_) {
      return const IssueApiResponse(
        statusCode: 500,
        ok: false,
        summary: 'Unexpected server error.',
        data: {},
      );
    }
  }

  Future<IssueApiResponse> _handleInternal(IssueApiRequest request) async {
    final segments = request.pathSegments;
    if (segments.length < 2 || segments[0] != 'api') {
      return const IssueApiResponse(
        statusCode: 404,
        ok: false,
        summary: 'Not found.',
        data: {},
      );
    }

    if (segments.length == 2 && segments[1] == 'projects') {
      return _handleProjects(request);
    }

    if (segments.length >= 2 && segments[1] == 'issues') {
      return _handleIssues(request);
    }

    return const IssueApiResponse(
      statusCode: 404,
      ok: false,
      summary: 'Not found.',
      data: {},
    );
  }

  Future<IssueApiResponse> _handleProjects(IssueApiRequest request) async {
    switch (request.method) {
      case 'GET':
        final repoPath = _readOptionalQuery(
          request.queryParameters,
          'repoPath',
        );
        final query = _readOptionalQuery(request.queryParameters, 'query');
        final includeArchived = _parseBool(
          request.queryParameters['includeArchived'],
          defaultValue: false,
        );
        final projects = _issueService.listProjects(
          repoPath: repoPath,
          query: query,
          includeArchived: includeArchived,
        );
        return IssueApiResponse(
          statusCode: 200,
          summary: projects.isEmpty
              ? 'No projects found.'
              : 'Loaded ${projects.length} projects.',
          data: {'projects': projects.map(_serializeProject).toList()},
        );
      case 'POST':
        final body = _requireBodyMap(request.body);
        final project = _issueService.createProject(
          _requireString(body, 'repoPath'),
          _requireString(body, 'name'),
          _requireString(body, 'key'),
        );
        await _notifyRepoMutation(project.repoPath);
        return IssueApiResponse(
          statusCode: 201,
          summary: 'Created project ${project.key}.',
          data: {'project': _serializeProject(project)},
        );
      default:
        throw const IssueApiException(405, 'Method not allowed.');
    }
  }

  Future<IssueApiResponse> _handleIssues(IssueApiRequest request) async {
    final segments = request.pathSegments;
    if (segments.length == 2) {
      return _handleIssueCollection(request);
    }

    if (segments.length == 3 && segments[2] == 'sync') {
      return _handleIssueSync(request);
    }

    if (segments.length == 3 && segments[2] == 'diagnostics') {
      return _handleIssueDiagnostics(request);
    }

    final displayId = segments[2];
    if (segments.length == 3) {
      return _handleSingleIssue(request, displayId);
    }

    if (segments.length == 4 && segments[3] == 'archive') {
      return _handleIssueArchive(request, displayId);
    }

    if (segments.length == 4 && segments[3] == 'comments') {
      return _handleIssueComments(request, displayId);
    }

    throw const IssueApiException(404, 'Not found.');
  }

  Future<IssueApiResponse> _handleIssueCollection(
    IssueApiRequest request,
  ) async {
    switch (request.method) {
      case 'GET':
        final repoPath = _requireQuery(request.queryParameters, 'repoPath');
        final project = _requireQuery(request.queryParameters, 'project');
        final includeArchived = _parseBool(
          request.queryParameters['includeArchived'],
          defaultValue: false,
        );
        final result = _issueService.listIssues(
          repoPath,
          project,
          includeArchived: includeArchived,
        );
        return IssueApiResponse(
          statusCode: 200,
          summary: result.issues.isEmpty
              ? 'No issues found.'
              : 'Loaded ${result.issues.length} issues.',
          data: {
            'project': _serializeProject(result.project),
            'issues': result.issues
                .map((issue) => _serializeIssue(result.project, issue))
                .toList(),
          },
        );
      case 'POST':
        final body = _requireBodyMap(request.body);
        final repoPath = _requireString(body, 'repoPath');
        final project = _requireString(body, 'project');
        final title = _requireString(body, 'title');
        final description = _readNullableString(body, 'description');
        final result = _issueService.createIssue(
          repoPath,
          project,
          title,
          description: description,
          tags: body.containsKey('tags') ? _parseTags(body['tags']) : null,
          status: body.containsKey('status')
              ? _parseStatus(body['status'])
              : IssueStatus.todo,
        );
        await _notifyRepoMutation(result.project.repoPath);
        return IssueApiResponse(
          statusCode: 201,
          summary: 'Created issue ${result.issue.displayId}.',
          data: _serializeResolvedIssueData(result),
        );
      default:
        throw const IssueApiException(405, 'Method not allowed.');
    }
  }

  Future<IssueApiResponse> _handleSingleIssue(
    IssueApiRequest request,
    String displayId,
  ) async {
    final repoPath = _readOptionalQuery(request.queryParameters, 'repoPath');
    final project = _readOptionalQuery(request.queryParameters, 'project');

    switch (request.method) {
      case 'GET':
        final result = _issueService.getIssue(
          displayId,
          repoPath: repoPath,
          projectKeyOrName: project,
        );
        return IssueApiResponse(
          statusCode: 200,
          summary: 'Loaded issue ${result.issue.displayId}.',
          data: _serializeResolvedIssueData(result),
        );
      case 'PATCH':
        final body = _requireBodyMap(request.body);
        final hasTitle = body.containsKey('title');
        final hasDescription = body.containsKey('description');
        final hasTags = body.containsKey('tags');
        final hasStatus = body.containsKey('status');
        if (!hasTitle && !hasDescription && !hasTags && !hasStatus) {
          throw const IssueApiException(
            400,
            'At least one of title, description, tags, or status is required.',
          );
        }

        final result = _issueService.updateIssue(
          displayId,
          repoPath: repoPath,
          projectKeyOrName: project,
          title: hasTitle ? _requireString(body, 'title') : null,
          description: hasDescription
              ? _readNullableString(body, 'description')
              : descriptionNotProvided,
          tags: hasTags ? _parseTags(body['tags']) : null,
          status: hasStatus ? _parseStatus(body['status']) : null,
        );
        await _notifyRepoMutation(result.project.repoPath);
        return IssueApiResponse(
          statusCode: 200,
          summary: 'Updated issue ${result.issue.displayId}.',
          data: _serializeResolvedIssueData(result),
        );
      default:
        throw const IssueApiException(405, 'Method not allowed.');
    }
  }

  Future<IssueApiResponse> _handleIssueArchive(
    IssueApiRequest request,
    String displayId,
  ) async {
    if (request.method != 'POST') {
      throw const IssueApiException(405, 'Method not allowed.');
    }

    final result = _issueService.archiveIssue(
      displayId,
      repoPath: _readOptionalQuery(request.queryParameters, 'repoPath'),
      projectKeyOrName: _readOptionalQuery(request.queryParameters, 'project'),
    );
    await _notifyRepoMutation(result.project.repoPath);
    return IssueApiResponse(
      statusCode: 200,
      summary: 'Archived issue ${result.issue.displayId}.',
      data: _serializeResolvedIssueData(result),
    );
  }

  Future<IssueApiResponse> _handleIssueComments(
    IssueApiRequest request,
    String displayId,
  ) async {
    final repoPath = _readOptionalQuery(request.queryParameters, 'repoPath');
    final project = _readOptionalQuery(request.queryParameters, 'project');

    switch (request.method) {
      case 'GET':
        final result = _issueService.listComments(
          displayId,
          repoPath: repoPath,
          projectKeyOrName: project,
        );
        return IssueApiResponse(
          statusCode: 200,
          summary: result.comments.isEmpty
              ? 'No comments found.'
              : 'Loaded ${result.comments.length} comments.',
          data: {
            ..._serializeResolvedIssueData(result.issueRecord),
            'comments': result.comments.map(_serializeComment).toList(),
          },
        );
      case 'POST':
        final body = _requireBodyMap(request.body);
        final content = _requireString(body, 'content');
        final authorName = _requireString(body, 'authorName');
        final authorType = body.containsKey('authorType')
            ? _parseAuthorType(body['authorType'])
            : CommentAuthorType.agent;
        final result = _issueService.addComment(
          displayId,
          repoPath: repoPath,
          projectKeyOrName: project,
          content: content,
          authorName: authorName,
          authorType: authorType,
        );
        await _notifyRepoMutation(result.issueRecord.project.repoPath);
        return IssueApiResponse(
          statusCode: 201,
          summary:
              'Added comment to issue ${result.issueRecord.issue.displayId}.',
          data: {
            ..._serializeResolvedIssueData(result.issueRecord),
            'comment': _serializeComment(result.comment),
          },
        );
      default:
        throw const IssueApiException(405, 'Method not allowed.');
    }
  }

  Future<IssueApiResponse> _handleIssueSync(IssueApiRequest request) async {
    if (request.method != 'POST') {
      throw const IssueApiException(405, 'Method not allowed.');
    }

    final body = _requireBodyMap(request.body);
    final result = _issueService.syncIssues(
      _requireString(body, 'repoPath'),
      _requireString(body, 'project'),
      _parseSyncInputs(body['issues']),
    );
    await _notifyRepoMutation(result.project.repoPath);
    return IssueApiResponse(
      statusCode: 200,
      summary: result.operations.isEmpty
          ? 'No issues were synced.'
          : 'Synced ${result.operations.length} issues.',
      data: {
        'project': _serializeProject(result.project),
        'operations': result.operations.map((operation) {
          return {
            'action': operation.action,
            ..._serializeResolvedIssueData(operation.issueRecord),
          };
        }).toList(),
      },
    );
  }

  Future<IssueApiResponse> _handleIssueDiagnostics(
    IssueApiRequest request,
  ) async {
    if (request.method != 'GET') {
      throw const IssueApiException(405, 'Method not allowed.');
    }

    final diagnostics = _issueService.getDiagnostics(
      displayId: _readOptionalQuery(request.queryParameters, 'displayId'),
    );
    final orphanedCount = (diagnostics['orphanedIssues'] as List).length;
    final duplicateCount = (diagnostics['duplicateDisplayIds'] as List).length;
    final summary = orphanedCount == 0 && duplicateCount == 0
        ? 'No issue diagnostics found.'
        : 'Loaded $orphanedCount orphaned issue(s) and $duplicateCount duplicate display id(s).';
    return IssueApiResponse(
      statusCode: 200,
      summary: summary,
      data: diagnostics,
    );
  }

  Future<void> _notifyRepoMutation(String repoPath) async {
    if (_onRepoMutated == null) return;
    await _onRepoMutated(repoPath);
  }

  String _requireQuery(Map<String, String> query, String key) {
    final value = query[key]?.trim();
    if (value == null || value.isEmpty) {
      throw IssueApiException(400, '$key is required.');
    }
    return value;
  }

  String? _readOptionalQuery(Map<String, String> query, String key) {
    if (!query.containsKey(key)) return null;
    final value = query[key]?.trim();
    if (value == null || value.isEmpty) {
      throw IssueApiException(400, '$key is required.');
    }
    return value;
  }

  Map<String, dynamic> _requireBodyMap(Object? body) {
    if (body is Map<String, dynamic>) return body;
    throw const IssueApiException(400, 'Request body must be a JSON object.');
  }

  String _requireString(Map<String, dynamic> body, String key) {
    final value = _readNullableString(body, key);
    if (value == null || value.isEmpty) {
      throw IssueApiException(400, '$key is required.');
    }
    return value;
  }

  String? _readNullableString(Map<String, dynamic> body, String key) {
    if (!body.containsKey(key) || body[key] == null) return null;
    final value = body[key];
    if (value is! String) {
      throw IssueApiException(400, '$key must be a string or null.');
    }
    return value;
  }

  bool _parseBool(String? rawValue, {required bool defaultValue}) {
    if (rawValue == null || rawValue.isEmpty) return defaultValue;
    switch (rawValue.toLowerCase()) {
      case 'true':
      case '1':
        return true;
      case 'false':
      case '0':
        return false;
      default:
        throw const IssueApiException(
          400,
          'includeArchived must be true or false.',
        );
    }
  }

  List<String> _parseTags(Object? value) {
    if (value == null) return [];
    if (value is String) {
      return value
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();
    }
    if (value is List) {
      return value
          .map((item) {
            if (item is! String) {
              throw const IssueApiException(
                400,
                'tags must contain only strings.',
              );
            }
            return item.trim();
          })
          .where((tag) => tag.isNotEmpty)
          .toList();
    }

    throw const IssueApiException(400, 'tags must be a string list or string.');
  }

  IssueStatus _parseStatus(Object? value) {
    if (value is! String) {
      throw const IssueApiException(400, 'status must be a string.');
    }
    return IssueStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => throw const IssueApiException(
        400,
        'status must be one of todo, inProgress, inReview, done.',
      ),
    );
  }

  List<IssueSyncInput> _parseSyncInputs(Object? value) {
    if (value is! List || value.isEmpty) {
      throw const IssueApiException(
        400,
        'issues must be a non-empty list of sync payloads.',
      );
    }

    return value.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const IssueApiException(
          400,
          'Each sync issue must be a JSON object.',
        );
      }
      return IssueSyncInput(
        title: _requireString(item, 'title'),
        description: _readNullableString(item, 'description'),
        status: item.containsKey('status')
            ? _parseStatus(item['status'])
            : IssueStatus.todo,
        tags: item.containsKey('tags') ? _parseTags(item['tags']) : const [],
        archive: item.containsKey('archive')
            ? _parseJsonBool(item['archive'], fieldName: 'archive')
            : false,
      );
    }).toList();
  }

  bool _parseJsonBool(Object? value, {required String fieldName}) {
    if (value is bool) {
      return value;
    }
    throw IssueApiException(400, '$fieldName must be a boolean.');
  }

  CommentAuthorType _parseAuthorType(Object? value) {
    if (value is! String) {
      throw const IssueApiException(400, 'authorType must be a string.');
    }
    return CommentAuthorType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => throw const IssueApiException(
        400,
        'authorType must be one of user or agent.',
      ),
    );
  }

  Map<String, dynamic> _serializeResolvedIssueData(ResolvedIssueRecord result) {
    return {
      'issue': _serializeIssue(result.project, result.issue),
      if (result.diagnostics.isNotEmpty) 'diagnostics': result.diagnostics,
    };
  }

  Map<String, dynamic> _serializeProject(Project project) => {
    'id': project.id,
    'repoPath': project.repoPath,
    'name': project.name,
    'key': project.key,
    'isArchived': project.isArchived,
    'createdAt': project.createdAt.toIso8601String(),
  };

  Map<String, dynamic> _serializeIssue(Project project, Issue issue) => {
    'id': issue.id,
    'displayId': issue.displayId,
    'projectId': issue.projectId,
    'projectKey': issue.projectKey,
    'projectName': project.name,
    'repoPath': project.repoPath,
    'issueNumber': issue.issueNumber,
    'title': issue.title,
    'description': issue.description,
    'status': issue.status.name,
    'tags': issue.tags,
    'isArchived': issue.isArchived,
    'sortOrder': issue.sortOrder,
    'createdAt': issue.createdAt.toIso8601String(),
    'updatedAt': issue.updatedAt.toIso8601String(),
  };

  Map<String, dynamic> _serializeComment(Comment comment) => {
    'id': comment.id,
    'issueId': comment.issueId,
    'content': comment.content,
    'authorType': comment.authorType.name,
    'authorName': comment.authorName,
    'createdAt': comment.createdAt.toIso8601String(),
    'updatedAt': comment.updatedAt.toIso8601String(),
  };
}
