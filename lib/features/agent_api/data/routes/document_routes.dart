import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'package:tree_launcher/features/agent_api/data/api_http.dart';
import 'package:tree_launcher/features/agents/domain/agent_kind.dart';
import 'package:tree_launcher/features/agents/domain/agent_registry.dart';
import 'package:tree_launcher/features/documents/domain/document_library.dart';
import 'package:tree_launcher/features/documents/domain/session_document.dart';
import 'package:tree_launcher/features/settings/domain/app_settings_source.dart';
import 'package:tree_launcher/features/workspace/domain/repo_catalog.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_creator.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_naming.dart';

/// `/v1/documents...`: sessions save the documents they write about their
/// work (Markdown, HTML or PDF), which the app keeps and shows in its
/// viewer.
class DocumentRoutes {
  DocumentRoutes({
    required RepoCatalog repos,
    required DocumentLibrary library,
    required DocumentSaver saver,
    required AppSettingsSource settings,
  }) : _repos = repos,
       _library = library,
       _saver = saver,
       _settings = settings;

  final RepoCatalog _repos;
  final DocumentLibrary _library;
  final DocumentSaver _saver;
  final AppSettingsSource _settings;

  void mount(Router router) => router
    ..get('/v1/documents', _list)
    ..post('/v1/documents', _save)
    ..get('/v1/documents/<id>', _get);

  /// `GET /v1/documents?repo=&agentId=&issueKey=&worktree=&kind=&format=`
  ///
  /// The documents matching every given filter, newest update first, without
  /// their content.
  Future<Response> _list(Request request) async {
    final query = request.url.queryParameters;
    String? param(String name) {
      final value = query[name]?.trim();
      return value == null || value.isEmpty ? null : value;
    }

    final repo = param('repo');
    if (repo != null) {
      final repos = await _repos.loadedRepos();
      if (!repos.any((r) => r.name == repo)) {
        return jsonResponse({'error': 'unknown repo: $repo'}, status: 400);
      }
    }
    final kindName = param('kind');
    final kind = AgentKind.tryParse(kindName);
    final types = _settings.settings.agentTypes;
    if (kindName != null && !types.any((t) => t.kind == kind)) {
      return jsonResponse({
        'error':
            'unknown kind "$kindName" — expected one of: '
            '${types.map((t) => t.kind.id).join(', ')}',
      }, status: 400);
    }
    final formatName = param('format');
    final format = DocumentFormat.tryParse(formatName);
    if (formatName != null && format == null) return _unknownFormat(formatName);

    final documents = _library.documentsFor(
      repoName: repo,
      agentId: param('agentId'),
      issueKey: param('issueKey')?.toUpperCase(),
      worktree: param('worktree'),
      kind: kind,
      format: format,
    );
    return jsonResponse({
      'count': documents.length,
      'documents': [for (final d in documents) d.toJson()],
    });
  }

  /// `GET /v1/documents/<id>`: the document, with `content` for Markdown
  /// and HTML.
  Future<Response> _get(Request request, String id) async {
    final document = _library.documentById(id);
    if (document == null) {
      return jsonResponse({'error': 'document not found: $id'}, status: 404);
    }
    final content = await _library.readText(id);
    return jsonResponse({...document.toJson(), 'content': ?content});
  }

  static const _saveFields = {
    'agentId',
    'repo',
    'title',
    'name',
    'content',
    'path',
    'format',
    'worktreePath',
    'issueKeys',
    'prNumber',
    'claudeSessionId',
    'show',
  };

  /// `POST /v1/documents`: saves a document (see `docs/agent-api.md`).
  /// 201 when it is new; 200 with `replaced` when `name` replaced the run's
  /// document of that name.
  Future<Response> _save(Request request) async {
    final parsed = await readJsonObject(request);
    if (parsed.error != null) return parsed.error!;
    final body = parsed.body!;

    final unknown = body.keys.where((k) => !_saveFields.contains(k));
    if (unknown.isNotEmpty) return unsupportedFields(unknown, _saveFields);

    String? field(String key) => stringField(body, key);

    final agentId = field('agentId');
    final repo = field('repo');
    final title = field('title');
    final missing = [
      if (title == null) 'title',
      if (agentId == null && repo == null) 'repo',
    ];
    if (missing.isNotEmpty) return missingFields(missing);

    final name = field('name');
    if (name != null && agentId == null) {
      return _badRequest('name needs agentId: a name is unique within a run');
    }

    final rawContent = body['content'];
    if (rawContent != null && rawContent is! String) {
      return _badRequest('content must be a string');
    }
    final content = rawContent as String?;
    final path = field('path');
    if ((content == null) == (path == null)) {
      return _badRequest('give exactly one of content and path');
    }
    if (path != null && !path.startsWith('/')) {
      return _badRequest('path must be absolute: $path');
    }

    final formatName = field('format');
    final format = DocumentFormat.tryParse(formatName);
    if (formatName != null && format == null) return _unknownFormat(formatName);
    if (content != null) {
      if (format == null) return _badRequest('format is required with content');
      if (!format.isText) {
        return _badRequest('a pdf can only be given as a path');
      }
      if (utf8.encode(content).length > maxDocumentContentBytes) {
        return jsonResponse({
          'error': const DocumentTooLargeException(
            maxDocumentContentBytes,
          ).toString(),
        }, status: 413);
      }
    }

    final List<String>? issueKeys;
    try {
      issueKeys = nameList(
        body['issueKeys'],
        'issueKeys',
      )?.map((k) => k.toUpperCase()).toSet().toList();
    } on FormatException catch (e) {
      return _badRequest(e.message);
    }
    for (final key in issueKeys ?? const <String>[]) {
      final error = validateJiraKey(key);
      if (error != null) return _badRequest('issue key $key: $error');
    }

    final pr = intField(body, 'prNumber');
    if (pr.error != null) return pr.error!;

    final show = body['show'];
    if (show != null && show is! bool) {
      return _badRequest('show must be true or false');
    }

    try {
      final saved = await _saver.save(
        DocumentRequest(
          title: title!,
          agentId: agentId,
          repoName: repo,
          name: name,
          content: content,
          path: path,
          format: format,
          worktreePath: field('worktreePath'),
          issueKeys: issueKeys,
          prNumber: pr.value,
          claudeSessionId: field('claudeSessionId'),
          show: show == true,
        ),
      );
      return jsonResponse({
        ...saved.document.toJson(),
        'warnings': saved.warnings,
        'replaced': saved.replaced,
      }, status: saved.replaced ? 200 : 201);
    } on AgentNotFoundException catch (e) {
      return jsonResponse({'error': e.toString()}, status: 404);
    } on RepoNotFoundException catch (e) {
      return jsonResponse({'error': e.toString()}, status: 404);
    } on DocumentInputException catch (e) {
      return _badRequest(e.message);
    } on DocumentTooLargeException catch (e) {
      return jsonResponse({'error': e.toString()}, status: 413);
    } catch (e) {
      return serverError('save document', e);
    }
  }

  static Response _badRequest(String message) =>
      jsonResponse({'error': message}, status: 400);

  static Response _unknownFormat(String format) => jsonResponse({
    'error':
        'unknown format "$format" — expected one of: '
        '${DocumentFormat.values.map((f) => f.name).join(', ')}',
  }, status: 400);
}
